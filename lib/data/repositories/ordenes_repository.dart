import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/utils/busqueda.dart';
import '../db.dart';
import '../models/orden.dart';

class OrdenesRepository {
  OrdenesRepository(this._db);
  final Db _db;

  static const claveContador = 'ordenes';

  List<Orden> _mapear(QuerySnapshot<Json> s) => s.docs.map((d) => Orden.fromMap(d.id, d.data())).toList();

  /// Trabajos en curso (no entregados ni cancelados).
  Stream<List<Orden>> activas() => _db.ordenes
      .where('activa', isEqualTo: true)
      .orderBy('fechaIngreso', descending: true)
      .snapshots()
      .map(_mapear);

  /// Trabajos cerrados, del más reciente al más antiguo.
  Stream<List<Orden>> cerradas({int limite = 40}) => _db.ordenes
      .where('activa', isEqualTo: false)
      .orderBy('fechaIngreso', descending: true)
      .limit(limite)
      .snapshots()
      .map(_mapear);

  Stream<List<Orden>> deCliente(String clienteId) => _db.ordenes
      .where('clienteId', isEqualTo: clienteId)
      .orderBy('fechaIngreso', descending: true)
      .snapshots()
      .map(_mapear);

  /// Trabajos con saldo pendiente de cobro.
  Stream<List<Orden>> conSaldo() =>
      _db.ordenes.where('saldo', isGreaterThan: 0).snapshots().map(_mapear);

  Stream<Orden?> observar(String id) =>
      _db.ordenes.doc(id).snapshots().map((d) => d.exists ? Orden.fromMap(d.id, d.data()!) : null);

  Future<List<Orden>> buscar(String consulta, {int limite = 30}) async {
    final termino = Busqueda.terminoPrincipal(consulta);
    if (termino == null) return const [];
    final snap = await _db.ordenes.where('keywords', arrayContains: termino).limit(limite).get();
    return snap.docs
        .where((d) => Busqueda.coincide(List<String>.from(d.data()['keywords'] ?? const []), consulta))
        .map((d) => Orden.fromMap(d.id, d.data()))
        .toList()
      ..sort((a, b) => b.fechaIngreso.compareTo(a.fechaIngreso));
  }

  Future<List<Orden>> entregadasEntre(DateTime desde, DateTime hasta) async {
    final snap = await _db.ordenes
        .where('fechaEntrega', isGreaterThanOrEqualTo: desde)
        .where('fechaEntrega', isLessThan: hasta)
        .get();
    return _mapear(snap);
  }

  /// Crea el trabajo asignándole el próximo número correlativo.
  Future<Orden> crear(Orden orden) {
    return _db.fs.runTransaction((tx) async {
      final numero = await _db.siguienteNumero(tx, claveContador);
      final ref = _db.ordenes.doc();
      final nueva = Orden.fromMap(ref.id, orden.copyWith(numero: numero).toMap());
      tx.set(ref, nueva.toMap());
      _db.guardarNumero(tx, claveContador, numero);
      return nueva;
    });
  }

  /// Guarda los cambios del formulario respetando lo cobrado en el
  /// servidor (puede haber cambiado desde que se abrió el formulario).
  Future<void> actualizar(Orden orden) => _modificar(orden.id, (actual) => orden.copyWith(pagado: actual.pagado));

  Future<void> cambiarEstado(String id, EstadoOrden estado) => _modificar(id, (actual) {
        final ahora = DateTime.now();
        return actual.copyWith(
          estado: estado,
          fechaListo: estado == EstadoOrden.listo ? ahora : null,
          fechaEntrega: estado == EstadoOrden.entregado ? ahora : null,
        );
      });

  Future<void> eliminar(Orden orden) async {
    if (orden.pagado > 0) {
      throw const ErrorDeNegocio(
        'Este trabajo tiene cobros registrados. Anulá los cobros desde Caja '
        'antes de eliminarlo, o marcalo como cancelado.',
      );
    }
    await _db.ordenes.doc(orden.id).delete();
  }

  Future<void> _modificar(String id, Orden Function(Orden actual) cambio) {
    return _db.fs.runTransaction((tx) async {
      final ref = _db.ordenes.doc(id);
      final snap = await tx.get(ref);
      if (!snap.exists) throw const ErrorDeNegocio('El trabajo ya no existe.');
      final actual = Orden.fromMap(snap.id, snap.data()!);
      tx.set(ref, cambio(actual).toMap());
    });
  }
}
