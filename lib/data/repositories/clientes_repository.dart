import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/utils/busqueda.dart';
import '../db.dart';
import '../models/cliente.dart';
import '../models/orden.dart';
import '../models/presupuesto.dart';

class ClientesRepository {
  ClientesRepository(this._db);
  final Db _db;

  Stream<List<Cliente>> listar({int limite = 60}) => _db.clientes
      .orderBy('nombreOrden')
      .limit(limite)
      .snapshots()
      .map((s) => s.docs.map((d) => Cliente.fromMap(d.id, d.data())).toList());

  Stream<Cliente?> observar(String id) => _db.clientes
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? Cliente.fromMap(d.id, d.data()!) : null);

  Future<Cliente?> obtener(String id) async {
    final d = await _db.clientes.doc(id).get();
    return d.exists ? Cliente.fromMap(d.id, d.data()!) : null;
  }

  Future<List<Cliente>> buscar(String consulta, {int limite = 25}) async {
    final termino = Busqueda.terminoPrincipal(consulta);
    if (termino == null) return const [];
    final snap = await _db.clientes.where('keywords', arrayContains: termino).limit(limite).get();
    final resultado = snap.docs
        .where((d) => Busqueda.coincide(List<String>.from(d.data()['keywords'] ?? const []), consulta))
        .map((d) => Cliente.fromMap(d.id, d.data()))
        .toList()
      ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    return resultado;
  }

  Future<Cliente> crear(Cliente cliente) async {
    final ref = _db.clientes.doc();
    await ref.set({...cliente.toMap(), 'fechaAlta': FieldValue.serverTimestamp()});
    return Cliente.fromMap(ref.id, {...cliente.toMap(), 'fechaAlta': DateTime.now()});
  }

  /// Guarda el cliente y actualiza su nombre/teléfono en los trabajos y
  /// presupuestos donde aparece (están copiados para listar sin lecturas
  /// extra).
  Future<void> actualizar(Cliente cliente) async {
    final batch = _db.fs.batch();
    batch.update(_db.clientes.doc(cliente.id), cliente.toMap());

    final ordenes = await _db.ordenes.where('clienteId', isEqualTo: cliente.id).limit(200).get();
    for (final d in ordenes.docs) {
      final o = Orden.fromMap(d.id, d.data()).copyWith(
        clienteNombre: cliente.nombre,
        clienteTelefono: cliente.telefono,
      );
      batch.update(d.reference, {
        'clienteNombre': o.clienteNombre,
        'clienteTelefono': o.clienteTelefono,
        'keywords': o.toMap()['keywords'],
      });
    }

    final presupuestos = await _db.presupuestos.where('clienteId', isEqualTo: cliente.id).limit(200).get();
    for (final d in presupuestos.docs) {
      final p = Presupuesto.fromMap(d.id, d.data()).copyWith(
        clienteNombre: cliente.nombre,
        clienteTelefono: cliente.telefono,
      );
      batch.update(d.reference, {
        'clienteNombre': p.clienteNombre,
        'clienteTelefono': p.clienteTelefono,
        'keywords': p.toMap()['keywords'],
      });
    }
    await batch.commit();
  }

  /// Elimina un cliente sólo si no tiene trabajos ni presupuestos, para no
  /// dejar historial huérfano.
  Future<void> eliminar(String id) async {
    final ordenes = await _db.ordenes.where('clienteId', isEqualTo: id).limit(1).get();
    final presupuestos = await _db.presupuestos.where('clienteId', isEqualTo: id).limit(1).get();
    if (ordenes.docs.isNotEmpty || presupuestos.docs.isNotEmpty) {
      throw const ErrorDeNegocio(
        'Este cliente tiene trabajos o presupuestos registrados. '
        'Para conservar el historial no se puede eliminar.',
      );
    }
    await _db.clientes.doc(id).delete();
  }

  Future<int> contar() async {
    final r = await _db.clientes.count().get();
    return r.count ?? 0;
  }
}
