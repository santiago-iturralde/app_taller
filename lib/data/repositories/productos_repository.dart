import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/utils/busqueda.dart';
import '../db.dart';
import '../models/comunes.dart';
import '../models/producto.dart';

class ProductosRepository {
  ProductosRepository(this._db, {required this.usuarioUid, this.usuarioEmail = ''});
  final Db _db;

  /// Quién hace los movimientos de stock (queda registrado en el historial).
  final String usuarioUid;
  final String usuarioEmail;

  List<Producto> _mapear(QuerySnapshot<Json> s) => s.docs.map((d) => Producto.fromMap(d.id, d.data())).toList();

  Stream<List<Producto>> listar({int limite = 100}) =>
      _db.productos.orderBy('nombreOrden').limit(limite).snapshots().map(_mapear);

  /// Todo el catálogo (para reportes de inventario).
  Future<List<Producto>> todos() async => _mapear(await _db.productos.get());

  Stream<List<Producto>> conStockBajo() =>
      _db.productos.where('stockBajo', isEqualTo: true).snapshots().map(_mapear);

  Stream<Producto?> observar(String id) =>
      _db.productos.doc(id).snapshots().map((d) => d.exists ? Producto.fromMap(d.id, d.data()!) : null);

  Stream<List<MovimientoStock>> movimientos(String productoId, {int limite = 30}) => _db.movimientosStock
      .where('productoId', isEqualTo: productoId)
      .orderBy('fecha', descending: true)
      .limit(limite)
      .snapshots()
      .map((s) => s.docs.map((d) => MovimientoStock.fromMap(d.id, d.data())).toList());

  Future<List<Producto>> buscar(String consulta, {int limite = 30}) async {
    final termino = Busqueda.terminoPrincipal(consulta);
    if (termino == null) return const [];
    final snap = await _db.productos.where('keywords', arrayContains: termino).limit(limite).get();
    return snap.docs
        .where((d) => Busqueda.coincide(List<String>.from(d.data()['keywords'] ?? const []), consulta))
        .map((d) => Producto.fromMap(d.id, d.data()))
        .toList()
      ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
  }

  Future<Producto> crear(Producto p, {double stockInicial = 0}) async {
    final ref = _db.productos.doc();
    final nuevo = Producto.fromMap(ref.id, {...p.toMap(), 'stock': p.controlaStock ? stockInicial : 0});
    final batch = _db.fs.batch();
    batch.set(ref, {...nuevo.toMap(), 'stock': nuevo.stock, 'creado': FieldValue.serverTimestamp()});
    if (nuevo.controlaStock && stockInicial != 0) {
      batch.set(_db.movimientosStock.doc(), _movimiento(nuevo.id, stockInicial, MotivoStock.ingreso, stockInicial, 'Stock inicial'));
    }
    await batch.commit();
    return nuevo;
  }

  /// Actualiza los datos del producto. El stock no se toca: se recalcula
  /// sólo el indicador de stock bajo con el stock actual del servidor.
  Future<void> actualizar(Producto p) => _db.fs.runTransaction((tx) async {
        final ref = _db.productos.doc(p.id);
        final snap = await tx.get(ref);
        if (!snap.exists) throw const ErrorDeNegocio('El producto ya no existe.');
        final stock = leerDouble(snap.data()!['stock']);
        tx.update(ref, p.copyWith(stock: stock).toMap());
      });

  Future<void> eliminar(String id) => _db.productos.doc(id).delete();

  /// Suma (o resta, si es negativo) [cantidad] al stock y deja registro.
  Future<void> moverStock(String id, double cantidad, MotivoStock motivo, {String referencia = ''}) {
    if (cantidad == 0) return Future.value();
    return _db.fs.runTransaction((tx) async {
      final productos = await leerParaStock(tx, [id]);
      if (productos.isEmpty) throw const ErrorDeNegocio('El producto ya no existe.');
      aplicarStock(tx, {id: cantidad}, productos, motivo: motivo, referencia: referencia);
    });
  }

  // ------------------------------------------- Uso dentro de transacciones
  //
  // Firestore exige hacer todas las lecturas antes que las escrituras:
  // primero `leerParaStock`, después el resto de las escrituras y
  // `aplicarStock`.

  Future<Map<String, Producto>> leerParaStock(Transaction tx, Iterable<String> ids) async {
    final resultado = <String, Producto>{};
    for (final id in ids.toSet()) {
      final snap = await tx.get(_db.productos.doc(id));
      if (snap.exists) resultado[id] = Producto.fromMap(snap.id, snap.data()!);
    }
    return resultado;
  }

  /// Aplica [deltas] (positivo = entra, negativo = sale). Ignora servicios y
  /// productos eliminados. Se permite stock negativo: el negocio puede
  /// vender antes de cargar la mercadería, y se ve como alerta.
  void aplicarStock(
    Transaction tx,
    Map<String, double> deltas,
    Map<String, Producto> productos, {
    required MotivoStock motivo,
    String referencia = '',
  }) {
    for (final e in deltas.entries) {
      final p = productos[e.key];
      if (p == null || !p.controlaStock || e.value == 0) continue;
      final nuevo = redondear(p.stock + e.value);
      tx.update(_db.productos.doc(p.id), {'stock': nuevo, 'stockBajo': nuevo <= p.stockMinimo});
      final m = e.value > 0 && (motivo == MotivoStock.trabajo || motivo == MotivoStock.venta) ? MotivoStock.devolucion : motivo;
      tx.set(_db.movimientosStock.doc(), _movimiento(p.id, e.value, m, nuevo, referencia));
    }
  }

  Json _movimiento(String productoId, double cantidad, MotivoStock motivo, double resultante, String referencia) => {
        'productoId': productoId,
        'cantidad': cantidad,
        'motivo': motivo.valor,
        'stockResultante': resultante,
        'referencia': referencia,
        'fecha': FieldValue.serverTimestamp(),
        'usuarioUid': usuarioUid,
        'usuarioEmail': usuarioEmail,
      };
}
