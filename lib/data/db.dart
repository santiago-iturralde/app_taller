import 'package:cloud_firestore/cloud_firestore.dart';

typedef Json = Map<String, dynamic>;

/// Rutas de Firestore de un negocio. Todo lo del negocio vive bajo
/// `negocios/{negocioId}`; las reglas de seguridad verifican que quien
/// accede sea miembro de ese negocio.
class Db {
  Db(this.negocioId, {FirebaseFirestore? firestore}) : fs = firestore ?? FirebaseFirestore.instance;

  final String negocioId;
  final FirebaseFirestore fs;

  DocumentReference<Json> get negocio => fs.collection('negocios').doc(negocioId);
  CollectionReference<Json> get miembros => negocio.collection('miembros');
  CollectionReference<Json> get clientes => negocio.collection('clientes');
  CollectionReference<Json> get ordenes => negocio.collection('ordenes');
  CollectionReference<Json> get presupuestos => negocio.collection('presupuestos');
  CollectionReference<Json> get pagos => negocio.collection('pagos');
  CollectionReference<Json> get gastos => negocio.collection('gastos');
  DocumentReference<Json> get contadores => negocio.collection('meta').doc('contadores');
  DocumentReference<Json> get branding => negocio.collection('meta').doc('branding');

  /// Reserva el siguiente número correlativo de [clave] dentro de una
  /// transacción. Debe llamarse antes de cualquier escritura de la misma.
  Future<int> siguienteNumero(Transaction tx, String clave) async {
    final snap = await tx.get(contadores);
    final actual = (snap.data()?[clave] as num?)?.toInt() ?? 0;
    return actual + 1;
  }

  void guardarNumero(Transaction tx, String clave, int numero) {
    tx.set(contadores, {clave: numero}, SetOptions(merge: true));
  }
}

/// Error de negocio con un mensaje apto para mostrar al usuario.
class ErrorDeNegocio implements Exception {
  const ErrorDeNegocio(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Rango [desde, hasta) de un mes calendario.
({DateTime desde, DateTime hasta}) rangoDelMes(DateTime mes) => (
      desde: DateTime(mes.year, mes.month),
      hasta: DateTime(mes.year, mes.month + 1),
    );
