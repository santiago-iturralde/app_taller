import 'package:cloud_firestore/cloud_firestore.dart';

import 'db.dart';
import 'models/caja.dart';
import 'models/cliente.dart';
import 'models/comunes.dart';
import 'models/orden.dart';
import 'models/presupuesto.dart';

/// Documento leído del esquema viejo (`users/{uid}/...`).
typedef DocLegacy = ({String id, Json data});

/// Escritura a realizar en el esquema nuevo.
typedef Escritura = ({String coleccion, String id, Json data});

/// Resultado de traducir los datos viejos al modelo nuevo. Es una función
/// pura (sin Firestore) para poder testearla.
class PlanMigracion {
  PlanMigracion({required this.escrituras, required this.contadores});

  final List<Escritura> escrituras;
  final Map<String, int> contadores;

  int cantidad(String coleccion) => escrituras.where((e) => e.coleccion == coleccion).length;

  /// Traduce los datos viejos. Los IDs son deterministas para que la
  /// migración se pueda reintentar sin duplicar nada.
  factory PlanMigracion.desde({
    required List<DocLegacy> clientes,
    required List<DocLegacy> reparaciones,
    required List<DocLegacy> presupuestos,
    required List<DocLegacy> egresos,
    required List<DocLegacy> recibos,
  }) {
    final escrituras = <Escritura>[];
    final clientesPorId = <String, Cliente>{};

    for (final c in clientes) {
      final leido = Cliente.fromMap(c.id, c.data);
      final nombre = leido.nombre.trim().isEmpty ? 'Cliente sin nombre' : leido.nombre.trim();
      final cliente = Cliente(
        id: leido.id,
        nombre: nombre.length > 150 ? nombre.substring(0, 150) : nombre,
        telefono: leido.telefono,
        fechaAlta: leido.fechaAlta,
      );
      clientesPorId[c.id] = cliente;
      escrituras.add((
        coleccion: 'clientes',
        id: c.id,
        data: {...cliente.toMap(), 'fechaAlta': cliente.fechaAlta ?? DateTime.now()},
      ));
    }

    DateTime fechaDe(Json d, String campo) => leerFecha(d[campo]) ?? DateTime(2024);
    int porFecha(DocLegacy a, DocLegacy b, String campo) => fechaDe(a.data, campo).compareTo(fechaDe(b.data, campo));

    // --- Reparaciones → trabajos (numerados por fecha de ingreso)
    final reps = [...reparaciones]..sort((a, b) => porFecha(a, b, 'fechaIngreso'));
    final cobros = <({String id, DateTime fecha, Json data})>[];
    var numeroOrden = 0;

    for (final r in reps) {
      numeroOrden++;
      final d = r.data;
      final cliente = clientesPorId[leerTexto(d['clienteId'])];
      final precio = leerDouble(d['precio']);
      final completada = d['estado'] == 'completada';
      final pagada = d['estadoPago'] == 'pagado';
      final ingreso = fechaDe(d, 'fechaIngreso');

      final estado = !completada
          ? EstadoOrden.enProceso
          : (pagada ? EstadoOrden.entregado : EstadoOrden.listo);

      final orden = Orden(
        id: r.id,
        numero: numeroOrden,
        clienteId: leerTexto(d['clienteId']),
        clienteNombre: cliente?.nombre ?? 'Cliente sin registrar',
        clienteTelefono: cliente?.telefono ?? '',
        equipo: Equipo(descripcion: leerTexto(d['maquina'])),
        problema: leerTexto(d['problema']),
        estado: estado,
        items: precio > 0 ? [ItemLinea(descripcion: 'Reparación', precioUnitario: precio)] : const [],
        pagado: pagada ? precio : 0,
        fechaIngreso: ingreso,
        fechaListo: completada ? ingreso : null,
        fechaEntrega: estado == EstadoOrden.entregado ? ingreso : null,
      );
      escrituras.add((coleccion: 'ordenes', id: r.id, data: orden.toMap()));

      if (pagada && precio > 0) {
        cobros.add((
          id: 'mig_rep_${r.id}',
          fecha: ingreso,
          data: Pago(
            id: '',
            numero: 0,
            monto: precio,
            fecha: ingreso,
            medio: MedioPago.otro,
            concepto: 'Trabajo N° $numeroOrden - ${orden.equipo.descripcion}',
            clienteId: orden.clienteId,
            clienteNombre: orden.clienteNombre,
            ordenId: r.id,
            ordenNumero: numeroOrden,
          ).toMap(),
        ));
      }
    }

    // --- Recibos viejos: se conservan como comprobantes, pero no suman a
    // la caja porque el sistema anterior no los contaba como ingreso.
    for (final r in recibos) {
      final d = r.data;
      final fecha = fechaDe(d, 'fecha');
      final clienteId = leerTextoONull(d['clienteId']);
      cobros.add((
        id: 'mig_rec_${r.id}',
        fecha: fecha,
        data: {
          ...Pago(
            id: '',
            numero: 0,
            monto: leerDouble(d['monto']),
            fecha: fecha,
            medio: MedioPago.otro,
            concepto: leerTexto(d['concepto']),
            clienteId: clienteId,
            clienteNombre: leerTexto(d['clienteNombre']).isNotEmpty
                ? leerTexto(d['clienteNombre'])
                : (clientesPorId[clienteId]?.nombre ?? ''),
            excluirDeCaja: true,
          ).toMap(),
          'numeroAnterior': leerTexto(d['nroRecibo']),
        },
      ));
    }

    cobros.sort((a, b) => a.fecha.compareTo(b.fecha));
    for (var i = 0; i < cobros.length; i++) {
      escrituras.add((coleccion: 'pagos', id: cobros[i].id, data: {...cobros[i].data, 'numero': i + 1}));
    }

    // --- Presupuestos
    final pres = [...presupuestos]..sort((a, b) => porFecha(a, b, 'fecha'));
    for (var i = 0; i < pres.length; i++) {
      final d = pres[i].data;
      final cliente = clientesPorId[leerTexto(d['clienteId'])];
      final p = Presupuesto(
        id: pres[i].id,
        numero: i + 1,
        clienteId: leerTexto(d['clienteId']),
        clienteNombre: cliente?.nombre ?? 'Cliente sin registrar',
        clienteTelefono: cliente?.telefono ?? '',
        items: ItemLinea.listaDesde(d['items']),
        fecha: fechaDe(d, 'fecha'),
      );
      escrituras.add((coleccion: 'presupuestos', id: pres[i].id, data: p.toMap()));
    }

    // --- Egresos → gastos
    for (final e in egresos) {
      final g = Gasto.fromMap(e.id, e.data);
      if (g.monto <= 0) continue; // Registros inválidos del sistema anterior.
      final descripcion = g.descripcion.isEmpty ? 'Gasto' : g.descripcion;
      escrituras.add((
        coleccion: 'gastos',
        id: e.id,
        data: {...g.toMap(), 'descripcion': descripcion.length > 300 ? descripcion.substring(0, 300) : descripcion},
      ));
    }

    return PlanMigracion(
      escrituras: escrituras,
      contadores: {
        'ordenes': numeroOrden,
        'presupuestos': pres.length,
        'pagos': cobros.length,
      },
    );
  }
}

/// Copia los datos del esquema viejo (`users/{uid}/...`) a un negocio
/// nuevo (`negocios/{uid}/...`). No borra nada del esquema viejo.
class MigracionLegacy {
  MigracionLegacy({FirebaseFirestore? firestore}) : _fs = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _fs;

  static const _colecciones = ['clientes', 'reparaciones', 'presupuestos', 'egresos', 'recibos'];

  DocumentReference<Json> _usuario(String uid) => _fs.collection('users').doc(uid);

  /// `true` si el usuario tiene datos del sistema anterior.
  Future<bool> hayDatos(String uid) async {
    final perfil = (await _usuario(uid).get()).data() ?? const {};
    if (leerTexto(perfil['nombreTaller']).isNotEmpty) return true;
    for (final c in ['clientes', 'reparaciones']) {
      final s = await _usuario(uid).collection(c).limit(1).get();
      if (s.docs.isNotEmpty) return true;
    }
    return false;
  }

  /// Ejecuta la migración e informa el avance (0 a 1).
  Future<void> migrar({required String uid, required String email, void Function(double)? progreso}) async {
    final perfil = (await _usuario(uid).get()).data() ?? const <String, dynamic>{};

    final datos = <String, List<DocLegacy>>{};
    for (final c in _colecciones) {
      final s = await _usuario(uid).collection(c).get();
      datos[c] = s.docs.map((d) => (id: d.id, data: d.data())).toList();
    }
    progreso?.call(0.15);

    final plan = PlanMigracion.desde(
      clientes: datos['clientes']!,
      reparaciones: datos['reparaciones']!,
      presupuestos: datos['presupuestos']!,
      egresos: datos['egresos']!,
      recibos: datos['recibos']!,
    );

    final db = Db(uid, firestore: _fs);
    // Logos muy pesados del sistema anterior no se migran (se puede volver
    // a subir uno optimizado desde Ajustes).
    final logoViejo = leerTextoONull(perfil['logoBase64']);
    final logo = (logoViejo != null && logoViejo.length < 690000) ? logoViejo : null;
    await crearNegocio(
      db: db,
      uid: uid,
      email: email,
      nombre: leerTexto(perfil['nombreTaller']).isEmpty ? 'Mi negocio' : leerTexto(perfil['nombreTaller']),
      rubro: 'herramientas',
      telefono: leerTexto(perfil['telefono']),
      direccion: leerTexto(perfil['direccion']),
      emailNegocio: leerTexto(perfil['email']),
      tieneLogo: logo != null,
      extra: {'migradoDelSistemaAnterior': true},
    );
    if (logo != null) await db.branding.set({'logoBase64': logo});
    progreso?.call(0.25);

    // Firestore admite hasta 500 operaciones por lote.
    const tamanioLote = 400;
    final total = plan.escrituras.length;
    for (var i = 0; i < total; i += tamanioLote) {
      final batch = _fs.batch();
      for (final e in plan.escrituras.skip(i).take(tamanioLote)) {
        batch.set(db.negocio.collection(e.coleccion).doc(e.id), e.data);
      }
      await batch.commit();
      progreso?.call(0.25 + 0.7 * ((i + tamanioLote).clamp(0, total) / (total == 0 ? 1 : total)));
    }

    await db.contadores.set(plan.contadores);
    await _usuario(uid).set({'negocioId': uid, 'migradoEn': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    progreso?.call(1);
  }
}

/// Crea el negocio y registra al usuario como dueño. El ID del primer
/// negocio de cada usuario es su propio UID, así un reintento no duplica.
Future<void> crearNegocio({
  required Db db,
  required String uid,
  required String email,
  required String nombre,
  required String rubro,
  String telefono = '',
  String direccion = '',
  String emailNegocio = '',
  bool tieneLogo = false,
  Json extra = const {},
}) async {
  final existente = await db.negocio.get();
  final batch = db.fs.batch();
  if (!existente.exists) {
    batch.set(db.negocio, {
      'nombre': nombre,
      'rubro': rubro,
      'ownerUid': uid,
      'telefono': telefono,
      'direccion': direccion,
      'email': emailNegocio.isEmpty ? email : emailNegocio,
      'cuit': '',
      'plan': 'free',
      'tieneLogo': tieneLogo,
      'plantillas': <String, String>{},
      'creado': FieldValue.serverTimestamp(),
      ...extra,
    });
  }
  batch.set(db.miembros.doc(uid), {
    'rol': 'owner',
    'email': email,
    'desde': FieldValue.serverTimestamp(),
  });
  await batch.commit();
}
