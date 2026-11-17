import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/utils/busqueda.dart';
import '../../core/utils/formato.dart';
import '../db.dart';
import '../models/orden.dart';
import '../models/presupuesto.dart';
import '../models/producto.dart';
import 'ordenes_repository.dart';
import 'productos_repository.dart';

class PresupuestosRepository {
  PresupuestosRepository(this._db, this._productos);
  final Db _db;
  final ProductosRepository _productos;

  static const claveContador = 'presupuestos';

  List<Presupuesto> _mapear(QuerySnapshot<Json> s) =>
      s.docs.map((d) => Presupuesto.fromMap(d.id, d.data())).toList();

  Stream<List<Presupuesto>> recientes({int limite = 60}) =>
      _db.presupuestos.orderBy('fecha', descending: true).limit(limite).snapshots().map(_mapear);

  Stream<List<Presupuesto>> deCliente(String clienteId) => _db.presupuestos
      .where('clienteId', isEqualTo: clienteId)
      .snapshots()
      .map((s) => _mapear(s)..sort((a, b) => b.fecha.compareTo(a.fecha)));

  Stream<Presupuesto?> observar(String id) => _db.presupuestos
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? Presupuesto.fromMap(d.id, d.data()!) : null);

  Future<List<Presupuesto>> buscar(String consulta, {int limite = 30}) async {
    final termino = Busqueda.terminoPrincipal(consulta);
    if (termino == null) return const [];
    final snap = await _db.presupuestos.where('keywords', arrayContains: termino).limit(limite).get();
    return snap.docs
        .where((d) => Busqueda.coincide(List<String>.from(d.data()['keywords'] ?? const []), consulta))
        .map((d) => Presupuesto.fromMap(d.id, d.data()))
        .toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
  }

  Future<Presupuesto> crear(Presupuesto p) {
    return _db.fs.runTransaction((tx) async {
      final numero = await _db.siguienteNumero(tx, claveContador);
      final ref = _db.presupuestos.doc();
      final nuevo = Presupuesto.fromMap(ref.id, p.copyWith(numero: numero).toMap());
      tx.set(ref, nuevo.toMap());
      _db.guardarNumero(tx, claveContador, numero);
      return nuevo;
    });
  }

  Future<void> actualizar(Presupuesto p) => _db.presupuestos.doc(p.id).set(p.toMap());

  Future<void> cambiarEstado(String id, EstadoPresupuesto estado) =>
      _db.presupuestos.doc(id).update({'estado': estado.valor});

  Future<void> eliminar(Presupuesto p) async {
    if (p.ordenId != null) {
      throw const ErrorDeNegocio('Este presupuesto ya generó un trabajo y no se puede eliminar.');
    }
    await _db.presupuestos.doc(p.id).delete();
  }

  /// Aprueba el presupuesto y crea el trabajo con sus ítems, en una sola
  /// operación atómica.
  Future<Orden> convertirEnOrden(Presupuesto p) {
    return _db.fs.runTransaction((tx) async {
      final presRef = _db.presupuestos.doc(p.id);
      final presSnap = await tx.get(presRef);
      final actual = Presupuesto.fromMap(presSnap.id, presSnap.data() ?? const {});
      if (actual.ordenId != null) {
        throw const ErrorDeNegocio('Este presupuesto ya fue convertido en trabajo.');
      }
      final numero = await _db.siguienteNumero(tx, OrdenesRepository.claveContador);
      final deltas = CalculoStock.diferencia(const [], actual.items);
      final productos = await _productos.leerParaStock(tx, deltas.keys);
      final ordenRef = _db.ordenes.doc();
      final orden = Orden(
        id: ordenRef.id,
        numero: numero,
        clienteId: actual.clienteId,
        clienteNombre: actual.clienteNombre,
        clienteTelefono: actual.clienteTelefono,
        equipo: Equipo(descripcion: actual.equipo),
        problema: 'Según presupuesto N° ${actual.numero}',
        items: actual.items,
        fechaIngreso: DateTime.now(),
      );
      tx.set(ordenRef, orden.toMap());
      tx.update(presRef, {'estado': EstadoPresupuesto.aprobado.valor, 'ordenId': ordenRef.id});
      _db.guardarNumero(tx, OrdenesRepository.claveContador, numero);
      _productos.aplicarStock(tx, deltas, productos,
          motivo: MotivoStock.trabajo, referencia: 'Trabajo N° ${Formato.numeroComprobante(numero)}');
      return orden;
    });
  }
}
