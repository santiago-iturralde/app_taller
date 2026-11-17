import 'package:cloud_firestore/cloud_firestore.dart';

import '../db.dart';
import '../models/caja.dart';
import '../models/comunes.dart';
import '../models/orden.dart';

class CajaRepository {
  CajaRepository(this._db);
  final Db _db;

  static const claveContador = 'pagos';

  List<Pago> _pagos(QuerySnapshot<Json> s) => s.docs.map((d) => Pago.fromMap(d.id, d.data())).toList();
  List<Gasto> _gastos(QuerySnapshot<Json> s) => s.docs.map((d) => Gasto.fromMap(d.id, d.data())).toList();

  // ---------------------------------------------------------------- Cobros

  Stream<List<Pago>> pagosDelMes(DateTime mes) {
    final r = rangoDelMes(mes);
    return _db.pagos
        .where('fecha', isGreaterThanOrEqualTo: r.desde)
        .where('fecha', isLessThan: r.hasta)
        .orderBy('fecha', descending: true)
        .snapshots()
        .map(_pagos);
  }

  Stream<List<Pago>> pagosDeOrden(String ordenId) => _db.pagos
      .where('ordenId', isEqualTo: ordenId)
      .snapshots()
      .map((s) => _pagos(s)..sort((a, b) => a.fecha.compareTo(b.fecha)));

  Future<List<Pago>> pagosEntre(DateTime desde, DateTime hasta) async => _pagos(await _db.pagos
      .where('fecha', isGreaterThanOrEqualTo: desde)
      .where('fecha', isLessThan: hasta)
      .get());

  /// Registra un cobro con número de recibo correlativo. Si está asociado a
  /// un trabajo, actualiza lo cobrado y el saldo del trabajo en la misma
  /// transacción.
  Future<Pago> registrarPago({
    required double monto,
    required MedioPago medio,
    required DateTime fecha,
    String concepto = '',
    String? clienteId,
    String clienteNombre = '',
    String? ordenId,
  }) {
    if (monto <= 0) throw const ErrorDeNegocio('El monto tiene que ser mayor a cero.');
    return _db.fs.runTransaction((tx) async {
      final numero = await _db.siguienteNumero(tx, claveContador);

      Orden? orden;
      DocumentReference<Json>? ordenRef;
      if (ordenId != null) {
        ordenRef = _db.ordenes.doc(ordenId);
        final snap = await tx.get(ordenRef);
        if (!snap.exists) throw const ErrorDeNegocio('El trabajo ya no existe.');
        orden = Orden.fromMap(snap.id, snap.data()!);
      }

      final ref = _db.pagos.doc();
      final pago = Pago(
        id: ref.id,
        numero: numero,
        monto: redondear(monto),
        fecha: fecha,
        medio: medio,
        concepto: concepto.isNotEmpty
            ? concepto
            : (orden != null ? 'Trabajo N° ${orden.numero} - ${orden.equipo.descripcion}' : ''),
        clienteId: clienteId ?? orden?.clienteId,
        clienteNombre: clienteNombre.isNotEmpty ? clienteNombre : (orden?.clienteNombre ?? ''),
        ordenId: ordenId,
        ordenNumero: orden?.numero,
      );
      tx.set(ref, pago.toMap());
      if (orden != null && ordenRef != null) {
        tx.set(ordenRef, orden.copyWith(pagado: redondear(orden.pagado + pago.monto)).toMap());
      }
      _db.guardarNumero(tx, claveContador, numero);
      return pago;
    });
  }

  /// Anula un cobro (no se borra, para mantener la numeración) y descuenta
  /// el importe del trabajo asociado.
  Future<void> anularPago(Pago pago) {
    return _db.fs.runTransaction((tx) async {
      final ref = _db.pagos.doc(pago.id);
      final snap = await tx.get(ref);
      final actual = Pago.fromMap(snap.id, snap.data() ?? const {});
      if (actual.anulado) return;

      if (actual.ordenId != null) {
        final ordenRef = _db.ordenes.doc(actual.ordenId);
        final ordenSnap = await tx.get(ordenRef);
        if (ordenSnap.exists) {
          final orden = Orden.fromMap(ordenSnap.id, ordenSnap.data()!);
          final pagado = redondear((orden.pagado - actual.monto).clamp(0, double.infinity).toDouble());
          tx.set(ordenRef, orden.copyWith(pagado: pagado).toMap());
        }
      }
      tx.update(ref, {'anulado': true, 'anuladoEn': FieldValue.serverTimestamp()});
    });
  }

  // ---------------------------------------------------------------- Gastos

  Stream<List<Gasto>> gastosDelMes(DateTime mes) {
    final r = rangoDelMes(mes);
    return _db.gastos
        .where('fecha', isGreaterThanOrEqualTo: r.desde)
        .where('fecha', isLessThan: r.hasta)
        .orderBy('fecha', descending: true)
        .snapshots()
        .map(_gastos);
  }

  Future<List<Gasto>> gastosEntre(DateTime desde, DateTime hasta) async => _gastos(await _db.gastos
      .where('fecha', isGreaterThanOrEqualTo: desde)
      .where('fecha', isLessThan: hasta)
      .get());

  Future<void> guardarGasto(Gasto gasto) {
    if (gasto.monto <= 0) throw const ErrorDeNegocio('El monto tiene que ser mayor a cero.');
    final ref = gasto.id.isEmpty ? _db.gastos.doc() : _db.gastos.doc(gasto.id);
    return ref.set(gasto.toMap());
  }

  Future<void> eliminarGasto(String id) => _db.gastos.doc(id).delete();
}
