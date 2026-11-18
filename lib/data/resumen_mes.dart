import '../core/utils/busqueda.dart';
import 'models/caja.dart';
import 'models/comunes.dart';
import 'models/orden.dart';
import 'models/producto.dart';

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

/// Lo vendido de un producto o servicio en el período.
class VentaProducto {
  VentaProducto(this.descripcion);

  final String descripcion;
  double cantidad = 0;
  double facturado = 0;

  /// Facturado y costo sólo de las líneas que tienen costo cargado.
  double facturadoConCosto = 0;
  double costo = 0;

  bool get tieneCosto => facturadoConCosto > 0;
  double get ganancia => redondear(facturadoConCosto - costo);
  double? get margen => tieneCosto ? ganancia / facturadoConCosto * 100 : null;
}

/// Análisis de productos y servicios vendidos. Cálculo puro para testear.
///
/// Considera las líneas de los trabajos entregados y de las ventas de
/// mostrador válidas. Agrupa por producto del catálogo; los ítems libres se
/// agrupan por descripción ("Mano de obra", etc.).
class ResumenProductos {
  factory ResumenProductos({required List<Orden> entregadas, required List<Pago> pagos}) {
    final grupos = <String, VentaProducto>{};
    final lineas = [
      for (final o in entregadas.where((o) => o.estado == EstadoOrden.entregado)) ...o.items,
      for (final p in pagos.where((p) => p.cuentaEnCaja && p.esVenta)) ...p.items,
    ];
    for (final i in lineas) {
      if (i.descripcion.trim().isEmpty || i.subtotal <= 0) continue;
      final clave = i.delCatalogo ? 'p:${i.productoId}' : 'd:${Busqueda.normalizar(i.descripcion.trim())}';
      final g = grupos.putIfAbsent(clave, () => VentaProducto(i.descripcion.trim()));
      g.cantidad = redondear(g.cantidad + i.cantidad);
      g.facturado = redondear(g.facturado + i.subtotal);
      final costoUnit = i.costoUnitario;
      if (costoUnit != null && costoUnit > 0) {
        g.facturadoConCosto = redondear(g.facturadoConCosto + i.subtotal);
        g.costo = redondear(g.costo + costoUnit * i.cantidad);
      }
    }
    final ranking = grupos.values.toList()..sort((a, b) => b.facturado.compareTo(a.facturado));
    return ResumenProductos._(ranking);
  }

  ResumenProductos._(this.ranking);

  /// De mayor a menor facturación.
  final List<VentaProducto> ranking;

  double get facturado => redondear(ranking.fold(0.0, (s, v) => s + v.facturado));
  double get facturadoConCosto => redondear(ranking.fold(0.0, (s, v) => s + v.facturadoConCosto));
  double get gananciaBruta => redondear(ranking.fold(0.0, (s, v) => s + v.ganancia));
  double? get margen => facturadoConCosto <= 0 ? null : gananciaBruta / facturadoConCosto * 100;

  /// Parte de lo facturado sin costo cargado (la ganancia no la incluye).
  double get facturadoSinCosto => redondear(facturado - facturadoConCosto);
}

/// Valor del stock actual.
class ValorInventario {
  factory ValorInventario(Iterable<Producto> productos) {
    var unidades = 0.0, costo = 0.0, venta = 0.0;
    var bajo = 0, sinCosto = 0;
    for (final p in productos.where((p) => p.controlaStock)) {
      if (p.stockBajo) bajo++;
      if (p.stock <= 0) continue;
      unidades += p.stock;
      venta += p.stock * p.precio;
      if (p.costo > 0) {
        costo += p.stock * p.costo;
      } else {
        sinCosto++;
      }
    }
    return ValorInventario._(redondear(unidades), redondear(costo), redondear(venta), bajo, sinCosto);
  }

  ValorInventario._(this.unidades, this.alCosto, this.aPrecioDeVenta, this.conStockBajo, this.productosSinCosto);

  final double unidades;
  final double alCosto;
  final double aPrecioDeVenta;
  final int conStockBajo;

  /// Productos con stock pero sin costo cargado (no suman a [alCosto]).
  final int productosSinCosto;
}
