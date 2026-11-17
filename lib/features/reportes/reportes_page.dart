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

class _ReportesPageState extends State<ReportesPage> {
  DateTime _mes = DateTime(DateTime.now().year, DateTime.now().month);
  Future<ResumenMes>? _datos;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sin plan PRO no se consulta nada (evita lecturas innecesarias).
    if (Sesion.of(context).negocio.permite(FuncionPro.reportes)) _datos ??= _cargar();
  }

  Future<ResumenMes> _cargar() async {
    final s = Sesion.of(context);
    final r = rangoDelMes(_mes);
    final anterior = rangoDelMes(DateTime(_mes.year, _mes.month - 1));
    final (pagos, pagosAnteriores, gastos, entregadas) = await (
      s.caja.pagosEntre(r.desde, r.hasta),
      s.caja.pagosEntre(anterior.desde, anterior.hasta),
      s.caja.gastosEntre(r.desde, r.hasta),
      s.ordenes.entregadasEntre(r.desde, r.hasta),
    ).wait;
    return ResumenMes(pagos: pagos, pagosMesAnterior: pagosAnteriores, gastos: gastos, entregadas: entregadas);
  }

  void _cambiarMes(DateTime m) => setState(() {
        _mes = m;
        _datos = _cargar();
      });

  @override
  Widget build(BuildContext context) {
    final negocio = Sesion.of(context).negocio;
    if (!negocio.permite(FuncionPro.reportes)) return const _Bloqueado();

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
                  FutureBuilder<ResumenMes>(
                    future: _datos,
                    builder: (context, s) {
                      if (s.hasError) return EstadoError(error: s.error, onReintentar: () => _cambiarMes(_mes));
                      if (!s.hasData) return const SizedBox(height: 300, child: Cargando());
                      return _Contenido(r: s.data!);
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
