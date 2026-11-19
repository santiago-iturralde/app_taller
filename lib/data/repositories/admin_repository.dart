import 'package:cloud_firestore/cloud_firestore.dart';

import '../db.dart';
import '../funciones.dart';
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
/// Las reglas sólo le permiten leer negocios, miembros y auditoría; los
/// cambios de plan pasan por la función adminCambiarPlan.
class AdminRepository {
  AdminRepository({FirebaseFirestore? firestore}) : _fs = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _fs;

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
      Funciones.llamar('adminCambiarPlan', {
        'negocioId': negocioId,
        'accion': 'activar',
        'plan': plan.valor,
        'meses': meses,
        'monto': monto,
        'nota': nota,
      });

  Future<void> darPrueba(String negocioId, int dias, {String nota = ''}) =>
      Funciones.llamar('adminCambiarPlan', {'negocioId': negocioId, 'accion': 'prueba', 'dias': dias, 'nota': nota});

  Future<void> pasarAGratis(String negocioId, {String nota = ''}) =>
      Funciones.llamar('adminCambiarPlan', {'negocioId': negocioId, 'accion': 'gratis', 'nota': nota});
}
