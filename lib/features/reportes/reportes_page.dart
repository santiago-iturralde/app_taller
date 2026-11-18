import 'package:flutter/material.dart';

import '../../app/sesion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/campos.dart';
import '../../core/widgets/componentes.dart';
import '../../data/db.dart';
import '../../data/models/negocio.dart';
import '../../data/resumen_mes.dart';
import '../planes/pro.dart';
import 'exportar_excel.dart';

class ReportesPage extends StatefulWidget {
  const ReportesPage({super.key});

  @override
  State<ReportesPage> createState() => _ReportesPageState();
}

/// Todo lo que muestra la pantalla de un mes.
typedef _Datos = ({ResumenMes mes, ResumenProductos productos, ValorInventario inventario});

class _ReportesPageState extends State<ReportesPage> {
  DateTime _mes = DateTime(DateTime.now().year, DateTime.now().month);
  Future<_Datos>? _datos;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sin plan PRO no se consulta nada (evita lecturas innecesarias).
    final sesion = Sesion.of(context);
    if (sesion.puede(Permiso.verReportes) && sesion.negocio.permite(FuncionPro.reportes)) _datos ??= _cargar();
  }

  Future<_Datos> _cargar() async {
    final s = Sesion.of(context);
    final r = rangoDelMes(_mes);
    final anterior = rangoDelMes(DateTime(_mes.year, _mes.month - 1));
    final (pagos, pagosAnteriores, gastos, entregadas, productos) = await (
      s.caja.pagosEntre(r.desde, r.hasta),
      s.caja.pagosEntre(anterior.desde, anterior.hasta),
      s.caja.gastosEntre(r.desde, r.hasta),
      s.ordenes.entregadasEntre(r.desde, r.hasta),
      s.productos.todos(),
    ).wait;
    return (
      mes: ResumenMes(pagos: pagos, pagosMesAnterior: pagosAnteriores, gastos: gastos, entregadas: entregadas),
      productos: ResumenProductos(entregadas: entregadas, pagos: pagos),
      inventario: ValorInventario(productos),
    );
  }

  void _cambiarMes(DateTime m) => setState(() {
        _mes = m;
        _datos = _cargar();
      });

  @override
  Widget build(BuildContext context) {
    final sesion = Sesion.of(context);
    if (!sesion.puede(Permiso.verReportes)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reportes')),
        body: const EstadoVacio(icono: Icons.lock_outline_rounded, titulo: 'Sólo para administradores'),
      );
    }
    if (!sesion.negocio.permite(FuncionPro.reportes)) return const _Bloqueado();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes'),
        actions: [
          IconButton(
            tooltip: 'Exportar todo a Excel',
            icon: const Icon(Icons.file_download_outlined),
            onPressed: () => exportarExcel(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _cambiarMes(_mes);
          await _datos;
        },
        child: ListView(
          padding: const EdgeInsets.all(Espacio.l),
          children: [
            ContenidoCentrado(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: SelectorMes(mes: _mes, onCambio: _cambiarMes)),
                  const SizedBox(height: Espacio.l),
                  FutureBuilder<_Datos>(
                    future: _datos,
                    builder: (context, s) {
                      if (s.hasError) return EstadoError(error: s.error, onReintentar: () => _cambiarMes(_mes));
                      if (!s.hasData) return const SizedBox(height: 300, child: Cargando());
                      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        _Contenido(r: s.data!.mes),
                        _SeccionProductos(productos: s.data!.productos, inventario: s.data!.inventario),
                      ]);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.r});
  final ResumenMes r;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final variacion = r.variacionCobrado;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GrillaAdaptable(anchoMinimo: 250, children: [
          Indicador(
            etiqueta: 'Cobrado',
            valor: Formato.moneda(r.cobrado),
            icono: Icons.south_west_rounded,
            color: c.exito,
            detalle: variacion == null
                ? 'Sin datos del mes anterior'
                : '${variacion >= 0 ? '▲' : '▼'} ${variacion.abs().toStringAsFixed(0)}% vs. mes anterior',
          ),
          Indicador(etiqueta: 'Gastos', valor: Formato.moneda(r.gastado), icono: Icons.north_east_rounded, color: c.peligro),
          Indicador(
            etiqueta: 'Resultado',
            valor: Formato.moneda(r.resultado),
            icono: r.resultado >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            color: r.resultado >= 0 ? c.info : c.alerta,
            detalle: r.resultado >= 0 ? 'Ganancia del mes' : 'Pérdida del mes',
          ),
          Indicador(
            etiqueta: 'Trabajos entregados',
            valor: '${r.trabajosEntregados}',
            icono: Icons.task_alt_rounded,
            detalle: r.trabajosEntregados == 0 ? null : 'Ticket promedio ${Formato.moneda(r.ticketPromedio)}',
          ),
        ]),
        const SizedBox(height: Espacio.l),
        GrillaAdaptable(anchoMinimo: 380, children: [
          _Desglose(
            titulo: 'Cobros por forma de pago',
            vacio: 'Sin cobros en el mes',
            filas: [for (final e in r.porMedio.entries) (e.key.etiqueta, e.value)],
            total: r.cobrado,
          ),
          _Desglose(
            titulo: 'Gastos por categoría',
            vacio: 'Sin gastos en el mes',
            filas: [for (final e in r.gastosPorCategoria.entries) (e.key, e.value)],
            total: r.gastado,
          ),
        ]),
      ],
    );
  }
}

/// Barras horizontales de un solo tono, con el valor y el porcentaje
/// escritos (la información nunca depende sólo del largo de la barra).
class _Desglose extends StatelessWidget {
  const _Desglose({required this.titulo, required this.filas, required this.total, required this.vacio});
  final String titulo;
  final List<(String, double)> filas;
  final double total;
  final String vacio;

  @override
  Widget build(BuildContext context) {
    final maximo = filas.isEmpty ? 1.0 : filas.map((f) => f.$2).reduce((a, b) => a > b ? a : b);
    return AppCard(
      padding: const EdgeInsets.all(Espacio.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(titulo, style: context.textos.titleSmall),
          const SizedBox(height: Espacio.l),
          if (filas.isEmpty)
            Text(vacio, style: TextStyle(color: context.esquema.onSurfaceVariant))
          else
            for (final f in filas)
              Padding(
                padding: const EdgeInsets.only(bottom: Espacio.m),
                child: Tooltip(
                  message: '${f.$1}: ${Formato.moneda(f.$2)}',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        Expanded(child: Text(f.$1, style: context.textos.bodyMedium)),
                        Text(Formato.moneda(f.$2), style: context.textos.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                        SizedBox(
                          width: 48,
                          child: Text(
                            total == 0 ? '' : '${(f.$2 / total * 100).round()}%',
                            textAlign: TextAlign.right,
                            style: context.textos.bodySmall?.copyWith(color: context.esquema.onSurfaceVariant),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      LayoutBuilder(
                        builder: (context, c) => Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            height: 8,
                            width: (c.maxWidth * (f.$2 / maximo)).clamp(4, c.maxWidth),
                            decoration: BoxDecoration(
                              color: context.esquema.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _Bloqueado extends StatelessWidget {
  const _Bloqueado();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reportes')),
      body: EstadoVacio(
        icono: Icons.insights_rounded,
        titulo: 'Reportes y estadísticas',
        mensaje: 'Conocé cuánto cobraste, cuánto gastaste y tu ganancia real de cada mes, '
            'con desglose por forma de pago y categoría. Disponible en el plan PRO.',
        accion: FilledButton.icon(
          onPressed: () => exigirPro(context, FuncionPro.reportes),
          icon: const Icon(Icons.workspace_premium_rounded),
          label: const Text('Conocer el plan PRO'),
        ),
      ),
    );
  }
}

/// Ganancia por productos/servicios, inventario y ranking de lo más vendido.
class _SeccionProductos extends StatelessWidget {
  const _SeccionProductos({required this.productos, required this.inventario});
  final ResumenProductos productos;
  final ValorInventario inventario;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final margen = productos.margen;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Seccion('Productos y servicios'),
      GrillaAdaptable(anchoMinimo: 250, children: [
        Indicador(
          etiqueta: 'Ganancia bruta',
          valor: Formato.moneda(productos.gananciaBruta),
          icono: Icons.savings_outlined,
          color: c.exito,
          detalle: margen == null
              ? 'Cargá el costo de tus productos para verla'
              : 'Margen ${margen.toStringAsFixed(0)}% sobre ${Formato.moneda(productos.facturadoConCosto)}',
        ),
        Indicador(
          etiqueta: 'Inventario (al costo)',
          valor: Formato.moneda(inventario.alCosto),
          icono: Icons.inventory_2_outlined,
          color: c.info,
          detalle: 'A precio de venta: ${Formato.moneda(inventario.aPrecioDeVenta)}',
        ),
        Indicador(
          etiqueta: 'Productos con stock bajo',
          valor: '${inventario.conStockBajo}',
          icono: Icons.warning_amber_rounded,
          color: inventario.conStockBajo > 0 ? c.alerta : c.exito,
          detalle: inventario.productosSinCosto > 0
              ? '${inventario.productosSinCosto} con stock sin costo cargado'
              : '${Formato.cantidad(inventario.unidades)} unidades en stock',
        ),
      ]),
      const SizedBox(height: Espacio.l),
      _Ranking(productos: productos),
    ]);
  }
}

class _Ranking extends StatelessWidget {
  const _Ranking({required this.productos});
  final ResumenProductos productos;

  static const _maximo = 12;

  @override
  Widget build(BuildContext context) {
    final filas = productos.ranking.take(_maximo).toList();
    final secundario = context.textos.bodySmall?.copyWith(color: context.esquema.onSurfaceVariant);
    return AppCard(
      padding: const EdgeInsets.all(Espacio.xl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Lo más vendido del mes', style: context.textos.titleSmall),
        Text('Trabajos entregados y ventas de mostrador', style: secundario),
        const SizedBox(height: Espacio.l),
        if (filas.isEmpty)
          Text('Sin ventas en el mes', style: TextStyle(color: context.esquema.onSurfaceVariant))
        else ...[
          Row(children: [
            Expanded(child: Text('Producto / servicio', style: secundario)),
            SizedBox(width: 64, child: Text('Cant.', style: secundario, textAlign: TextAlign.right)),
            SizedBox(width: 110, child: Text('Facturado', style: secundario, textAlign: TextAlign.right)),
            SizedBox(width: 72, child: Text('Margen', style: secundario, textAlign: TextAlign.right)),
          ]),
          const Divider(height: Espacio.l),
          for (final v in filas)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Tooltip(
                message: v.tieneCosto
                    ? 'Ganancia: ${Formato.moneda(v.ganancia)}'
                    : 'Sin costo cargado: no se puede calcular la ganancia',
                child: Row(children: [
                  Expanded(child: Text(v.descripcion, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  SizedBox(width: 64, child: Text(Formato.cantidad(v.cantidad), textAlign: TextAlign.right)),
                  SizedBox(
                    width: 110,
                    child: Text(
                      Formato.moneda(v.facturado),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  SizedBox(
                    width: 72,
                    child: Text(
                      v.margen == null ? '—' : '${v.margen!.toStringAsFixed(0)}%',
                      textAlign: TextAlign.right,
                      style: secundario,
                    ),
                  ),
                ]),
              ),
            ),
          if (productos.ranking.length > _maximo)
            Padding(
              padding: const EdgeInsets.only(top: Espacio.s),
              child: Text('Y ${productos.ranking.length - _maximo} más. El detalle completo está en la exportación a Excel.', style: secundario),
            ),
        ],
      ]),
    );
  }
}
