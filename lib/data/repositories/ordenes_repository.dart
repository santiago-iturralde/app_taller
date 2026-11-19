import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/utils/busqueda.dart';
import '../../core/utils/formato.dart';
import '../db.dart';
import '../models/orden.dart';
import '../models/producto.dart';
import 'productos_repository.dart';

class OrdenesRepository {
  OrdenesRepository(this._db, this._productos);
  final Db _db;
  final ProductosRepository _productos;

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

  /// Trabajos con próximo service hasta [hasta] cuyo recordatorio todavía
  /// no se envió.
  Stream<List<Orden>> recordatoriosPendientes(DateTime hasta) => _db.ordenes
      .where('recordatorioEnviado', isEqualTo: false)
      .where('proximoServiceFecha', isLessThanOrEqualTo: hasta)
      .orderBy('proximoServiceFecha')
      .snapshots()
      .map(_mapear);

  Future<void> marcarRecordatorio(String id, {bool enviado = true}) =>
      _db.ordenes.doc(id).update({'recordatorioEnviado': enviado});

  /// Crea el trabajo con el próximo número correlativo y descuenta del
  /// stock los productos del catálogo que use.
  Future<Orden> crear(Orden orden) {
    return _db.fs.runTransaction((tx) async {
      final numero = await _db.siguienteNumero(tx, claveContador);
      final deltas = CalculoStock.diferencia(const [], orden.itemsQueConsumenStock);
      final productos = await _productos.leerParaStock(tx, deltas.keys);

      final ref = _db.ordenes.doc();
      final nueva = Orden.fromMap(ref.id, orden.copyWith(numero: numero).toMap());
      tx.set(ref, nueva.toMap());
      _db.guardarNumero(tx, claveContador, numero);
      _productos.aplicarStock(tx, deltas, productos,
          motivo: MotivoStock.trabajo, referencia: 'Trabajo N° ${Formato.numeroComprobante(numero)}');
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

  /// Elimina el trabajo y devuelve al stock lo que había consumido.
  Future<void> eliminar(Orden orden) {
    if (orden.pagado > 0) {
      throw const ErrorDeNegocio(
        'Este trabajo tiene cobros registrados. Anulá los cobros desde Caja '
        'antes de eliminarlo, o marcalo como cancelado.',
      );
    }
    return _db.fs.runTransaction((tx) async {
      final ref = _db.ordenes.doc(orden.id);
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final actual = Orden.fromMap(snap.id, snap.data()!);
      final deltas = CalculoStock.diferencia(actual.itemsQueConsumenStock, const []);
      final productos = await _productos.leerParaStock(tx, deltas.keys);
      tx.delete(ref);
      _productos.aplicarStock(tx, deltas, productos,
          motivo: MotivoStock.devolucion,
          referencia: 'Trabajo N° ${Formato.numeroComprobante(actual.numero)} eliminado');
    });
  }

  /// Aplica un cambio al trabajo dentro de una transacción y ajusta el
  /// stock según la diferencia de ítems (incluye cancelar / reabrir).
  Future<void> _modificar(String id, Orden Function(Orden actual) cambio) {
    return _db.fs.runTransaction((tx) async {
      final ref = _db.ordenes.doc(id);
      final snap = await tx.get(ref);
      if (!snap.exists) throw const ErrorDeNegocio('El trabajo ya no existe.');
      final actual = Orden.fromMap(snap.id, snap.data()!);
      // La factura la asigna sólo el servidor: se conserva la que tiene ahora.
      final nueva = Orden.fromMap(id, {...cambio(actual).toMap(), 'facturaId': actual.facturaId});
      final deltas = CalculoStock.diferencia(actual.itemsQueConsumenStock, nueva.itemsQueConsumenStock);
      final productos = await _productos.leerParaStock(tx, deltas.keys);
      tx.set(ref, nueva.toMap());
      _productos.aplicarStock(tx, deltas, productos,
          motivo: MotivoStock.trabajo, referencia: 'Trabajo N° ${Formato.numeroComprobante(actual.numero)}');
    });
  }
}
