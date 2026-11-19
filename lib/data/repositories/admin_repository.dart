import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart';

import '../db.dart';
import '../models/cambio_plan.dart';
import '../models/comunes.dart';
import '../models/negocio.dart';

/// Registro de un cambio de plan (auditoría).
class RegistroPlan {
  const RegistroPlan({
    required this.id,
    required this.negocioId,
    required this.negocioNombre,
    required this.accion,
    required this.planAnterior,
    required this.planNuevo,
    this.venceNuevo,
    this.monto,
    this.nota = '',
    this.porEmail = '',
    this.fecha,
  });

  final String id;
  final String negocioId;
  final String negocioNombre;
  final String accion;
  final Plan planAnterior;
  final Plan planNuevo;
  final DateTime? venceNuevo;
  final double? monto;
  final String nota;
  final String porEmail;
  final DateTime? fecha;

  factory RegistroPlan.fromMap(String id, Map<String, dynamic> m) => RegistroPlan(
        id: id,
        negocioId: leerTexto(m['negocioId']),
        negocioNombre: leerTexto(m['negocioNombre']),
        accion: leerTexto(m['accion']),
        planAnterior: Plan.desde(m['planAnterior'] as String?),
        planNuevo: Plan.desde(m['planNuevo'] as String?),
        venceNuevo: leerFecha(m['venceNuevo']),
        monto: m['monto'] == null ? null : leerDouble(m['monto']),
        nota: leerTexto(m['nota']),
        porEmail: leerTexto(m['porEmail']),
        fecha: leerFecha(m['fecha']),
      );
}

/// Datos de la plataforma para el administrador (custom claim superadmin).
/// Las reglas le permiten leer negocios, miembros y auditoría (nunca los
/// datos internos de cada negocio) y cambiar el plan sólo si en la misma
/// transacción deja el registro de auditoría.
class AdminRepository {
  AdminRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _fs = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;
  final FirebaseFirestore _fs;
  final FirebaseAuth _auth;

  Stream<List<(Negocio, DateTime?)>> negocios({int limite = 100}) => _fs
      .collection('negocios')
      .orderBy('creado', descending: true)
      .limit(limite)
      .snapshots()
      .map((s) => s.docs.map((d) => (Negocio.fromMap(d.id, d.data()), leerFecha(d.data()['creado']))).toList());

  Stream<Negocio?> negocio(String id) =>
      _fs.collection('negocios').doc(id).snapshots().map((d) => d.exists ? Negocio.fromMap(d.id, d.data()!) : null);

  Future<String> emailDuenio(String negocioId) async {
    final s = await _fs.collection('negocios').doc(negocioId).collection('miembros').where('rol', isEqualTo: 'owner').limit(1).get();
    return s.docs.isEmpty ? '' : leerTexto(s.docs.first.data()['email']);
  }

  Future<int> cantidadMiembros(String negocioId) async {
    final r = await _fs.collection('negocios').doc(negocioId).collection('miembros').count().get();
    return r.count ?? 0;
  }

  Stream<List<RegistroPlan>> historial({String? negocioId, int limite = 50}) {
    Query<Json> q = _fs.collection('auditoriaPlanes');
    if (negocioId != null) q = q.where('negocioId', isEqualTo: negocioId);
    return q
        .orderBy('fecha', descending: true)
        .limit(limite)
        .snapshots()
        .map((s) => s.docs.map((d) => RegistroPlan.fromMap(d.id, d.data())).toList());
  }

  /// Activa un plan pago por [meses] (si ya lo tenía vigente, se suma).
  Future<void> activarPlan(String negocioId, Plan plan, int meses, {double? monto, String nota = ''}) =>
      _cambiarPlan(negocioId, (n) => CambioPlan.activar(n, plan, meses), monto: monto, nota: nota);

  Future<void> darPrueba(String negocioId, int dias, {String nota = ''}) =>
      _cambiarPlan(negocioId, (_) => CambioPlan.prueba(dias), nota: nota);

  Future<void> pasarAGratis(String negocioId, {String nota = ''}) =>
      _cambiarPlan(negocioId, (_) => const CambioPlan.gratis(), nota: nota);

  /// Cambia el plan y registra la auditoría en una sola transacción. Las
  /// reglas rechazan el cambio si falta el registro (campo planAuditoria).
  Future<void> _cambiarPlan(
    String negocioId,
    CambioPlan Function(Negocio actual) calcular, {
    double? monto,
    String nota = '',
  }) async {
    if (monto != null && (!monto.isFinite || monto < 0)) throw const ErrorDeNegocio('Monto inválido.');
    final usuario = _auth.currentUser;
    if (usuario == null) throw const ErrorDeNegocio('Tu sesión venció. Volvé a ingresar.');

    final ref = _fs.collection('negocios').doc(negocioId);
    final registro = _fs.collection('auditoriaPlanes').doc();
    await _fs.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw const ErrorDeNegocio('El negocio no existe.');
      final actual = Negocio.fromMap(snap.id, snap.data()!);
      final CambioPlan cambio;
      try {
        cambio = calcular(actual);
      } on ArgumentError catch (e) {
        throw ErrorDeNegocio('${e.message}');
      }
      final vence = cambio.vence == null ? null : Timestamp.fromDate(cambio.vence!);

      tx.update(ref, {
        'plan': cambio.plan.valor,
        'planVence': vence ?? FieldValue.delete(),
        'prueba': cambio.prueba,
        'planActualizado': FieldValue.serverTimestamp(),
        'planAuditoria': registro.id,
      });
      tx.set(registro, {
        'negocioId': negocioId,
        'negocioNombre': actual.nombre,
        'accion': cambio.accion,
        'planAnterior': actual.plan.valor,
        'venceAnterior': actual.planVence == null ? null : Timestamp.fromDate(actual.planVence!),
        'planNuevo': cambio.plan.valor,
        'venceNuevo': vence,
        'monto': monto,
        'nota': nota.trim().length > 500 ? nota.trim().substring(0, 500) : nota.trim(),
        'porUid': usuario.uid,
        'porEmail': usuario.email ?? '',
        'fecha': FieldValue.serverTimestamp(),
      });
    });
  }
}
