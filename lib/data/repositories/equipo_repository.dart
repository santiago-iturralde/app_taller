import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../db.dart';
import '../models/equipo.dart';
import '../models/negocio.dart';

/// Miembros e invitaciones del negocio actual.
class EquipoRepository {
  EquipoRepository(this._db);
  final Db _db;

  CollectionReference<Json> get _invitaciones => _db.fs.collection('invitaciones');

  Stream<List<Miembro>> miembros() => _db.miembros.snapshots().map((s) {
        final lista = s.docs.map((d) => Miembro.fromMap(d.id, d.data())).toList();
        lista.sort((a, b) => a.rol.index != b.rol.index ? a.rol.index.compareTo(b.rol.index) : a.email.compareTo(b.email));
        return lista;
      });

  /// Invitaciones del negocio (pendientes y vencidas, para poder limpiarlas).
  Stream<List<Invitacion>> invitaciones() => _invitaciones
      .where('negocioId', isEqualTo: _db.negocioId)
      .snapshots()
      .map((s) => s.docs.map((d) => Invitacion.fromMap(d.data())).toList()..sort((a, b) => a.email.compareTo(b.email)));

  /// Crea una invitación válida por [Invitacion.diasDeValidez] días.
  ///
  /// [pendientes] y [miembros] son los datos que ya muestra la pantalla:
  /// se usan para evitar invitar dos veces o invitar a alguien que ya está.
  Future<Invitacion> invitar({
    required String email,
    required RolMiembro rol,
    required Negocio negocio,
    required String invitadoPor,
    required List<Invitacion> pendientes,
    required List<Miembro> miembros,
  }) async {
    final normalizado = Invitacion.normalizarEmail(email);
    if (!Invitacion.emailValido(normalizado)) throw const ErrorDeNegocio('El email no es válido.');
    if (rol == RolMiembro.duenio) throw const ErrorDeNegocio('No se puede invitar a otro dueño.');
    if (miembros.any((m) => m.email.toLowerCase() == normalizado)) {
      throw const ErrorDeNegocio('Esa persona ya forma parte del equipo.');
    }

    final existente = pendientes.where((i) => i.email == normalizado).firstOrNull;
    if (existente != null) {
      if (!existente.vencida && existente.rol == rol) return existente;
      // Vencida o con otro rol: se reemplaza.
      await _invitaciones.doc(existente.id).delete();
    }

    final invitacion = Invitacion(
      negocioId: negocio.id,
      negocioNombre: negocio.nombre,
      email: normalizado,
      rol: rol,
      creadoPor: invitadoPor,
      vence: DateTime.now().add(const Duration(days: Invitacion.diasDeValidez)),
    );
    await _invitaciones.doc(invitacion.id).set({...invitacion.toMap(), 'creadoEn': FieldValue.serverTimestamp()});
    return invitacion;
  }

  Future<void> cancelarInvitacion(Invitacion i) => _invitaciones.doc(i.id).delete();

  Future<void> cambiarRol(String uid, RolMiembro rol) {
    if (rol == RolMiembro.duenio) throw const ErrorDeNegocio('No se puede asignar el rol de dueño.');
    return _db.miembros.doc(uid).update({'rol': rol.valor});
  }

  Future<void> quitar(String uid) => _db.miembros.doc(uid).delete();

  /// El usuario actual deja el negocio (no disponible para el dueño).
  Future<void> salir(String uid) async {
    final batch = _db.fs.batch();
    batch.delete(_db.miembros.doc(uid));
    batch.set(_db.fs.collection('users').doc(uid), {'negocioId': FieldValue.delete()}, SetOptions(merge: true));
    await batch.commit();
  }
}

/// Invitaciones vistas desde el lado de quien fue invitado.
class MisInvitaciones {
  MisInvitaciones({FirebaseFirestore? firestore}) : _fs = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _fs;

  /// Requiere email verificado (las reglas lo exigen).
  Future<List<Invitacion>> pendientes(User usuario) async {
    final email = usuario.email;
    if (email == null || !usuario.emailVerified) return const [];
    final s = await _fs.collection('invitaciones').where('email', isEqualTo: Invitacion.normalizarEmail(email)).get();
    return s.docs.map((d) => Invitacion.fromMap(d.data())).where((i) => !i.vencida).toList();
  }

  /// Se suma al negocio, consume la invitación y lo deja como negocio
  /// activo, todo en una sola operación atómica.
  Future<void> aceptar(Invitacion invitacion, User usuario) async {
    if (invitacion.vencida) throw const ErrorDeNegocio('La invitación venció. Pedí que te inviten de nuevo.');
    // Renueva el token para que incluya la verificación del email.
    await usuario.getIdToken(true);
    final db = Db(invitacion.negocioId, firestore: _fs);
    final batch = _fs.batch();
    batch.set(db.miembros.doc(usuario.uid), {
      'rol': invitacion.rol.valor,
      'email': Invitacion.normalizarEmail(usuario.email ?? ''),
      'desde': FieldValue.serverTimestamp(),
    });
    batch.delete(_fs.collection('invitaciones').doc(invitacion.id));
    batch.set(_fs.collection('users').doc(usuario.uid), {'negocioId': invitacion.negocioId, 'email': usuario.email}, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> rechazar(Invitacion invitacion) => _fs.collection('invitaciones').doc(invitacion.id).delete();

  /// Desvincula al usuario de su negocio actual (por ejemplo, si lo
  /// quitaron del equipo) para que pueda aceptar otra invitación o crear
  /// su propio negocio.
  Future<void> olvidarNegocio(String uid) =>
      _fs.collection('users').doc(uid).set({'negocioId': FieldValue.delete()}, SetOptions(merge: true));
}
