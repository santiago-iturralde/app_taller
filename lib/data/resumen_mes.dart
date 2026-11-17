import 'models/caja.dart';
import 'models/comunes.dart';
import 'models/orden.dart';

/// Indicadores de un mes. Cálculo puro (sin Firestore) para poder testearlo.
class ResumenMes {
  ResumenMes({
    required List<Pago> pagos,
    required List<Pago> pagosMesAnterior,
    required List<Gasto> gastos,
    required List<Orden> entregadas,
  })  : cobrado = _sumar(pagos.where((p) => p.cuentaEnCaja).map((p) => p.monto)),
        cobradoMesAnterior = _sumar(pagosMesAnterior.where((p) => p.cuentaEnCaja).map((p) => p.monto)),
        gastado = _sumar(gastos.map((g) => g.monto)),
        trabajosEntregados = entregadas.where((o) => o.estado == EstadoOrden.entregado).length,
        facturadoEntregados = _sumar(entregadas.where((o) => o.estado == EstadoOrden.entregado).map((o) => o.total)),
        porMedio = _agrupar(pagos.where((p) => p.cuentaEnCaja), (p) => p.medio, (p) => p.monto),
        gastosPorCategoria = _agrupar(gastos, (g) => g.categoria, (g) => g.monto);

  final double cobrado;
  final double cobradoMesAnterior;
  final double gastado;
  final int trabajosEntregados;
  final double facturadoEntregados;
  final Map<MedioPago, double> porMedio;
  final Map<String, double> gastosPorCategoria;

  double get resultado => redondear(cobrado - gastado);

  double get ticketPromedio => trabajosEntregados == 0 ? 0 : redondear(facturadoEntregados / trabajosEntregados);

  /// Variación porcentual contra el mes anterior, o `null` si no hay base.
  double? get variacionCobrado =>
      cobradoMesAnterior <= 0 ? null : (cobrado - cobradoMesAnterior) / cobradoMesAnterior * 100;

  static double _sumar(Iterable<double> v) => redondear(v.fold(0.0, (a, b) => a + b));

  /// Agrupa y ordena de mayor a menor.
  static Map<K, double> _agrupar<T, K>(Iterable<T> items, K Function(T) clave, double Function(T) valor) {
    final m = <K, double>{};
    for (final i in items) {
      m.update(clave(i), (v) => v + valor(i), ifAbsent: () => valor(i));
    }
    final entradas = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return {for (final e in entradas) e.key: redondear(e.value)};
  }
}
