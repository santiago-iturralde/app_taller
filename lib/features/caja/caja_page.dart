import 'package:flutter/material.dart';

import '../../app/sesion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/campos.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/feedback.dart';
import '../../data/models/caja.dart';
import '../../data/models/negocio.dart';
import 'venta_form.dart';
import 'gasto_form.dart';
import 'widgets_caja.dart';

/// Caja del mes: cobros (ingresos) y gastos, con totales.
class CajaPage extends StatefulWidget {
  const CajaPage({super.key, this.pestanaInicial = 0});
  final int pestanaInicial;

  @override
  State<CajaPage> createState() => _CajaPageState();
}

class _CajaPageState extends State<CajaPage> with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 2, vsync: this, initialIndex: widget.pestanaInicial)..addListener(() => setState(() {}));
  DateTime _mes = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sesion = Sesion.of(context);
    final caja = sesion.caja;
    // Los empleados registran cobros pero no ven gastos ni totales.
    final verGastos = sesion.puede(Permiso.verGastos);
    final verTotales = sesion.puede(Permiso.verTotalesCaja);
    final esCobros = !verGastos || _tabs.index == 0;

    final cobros = StreamBuilder<List<Pago>>(
      stream: caja.pagosDelMes(_mes),
      builder: (context, s) {
        if (s.hasError) return EstadoError(error: s.error);
        if (!s.hasData) return const Cargando();
        final pagos = s.data!;
        final validos = pagos.where((p) => p.cuentaEnCaja);
        return _Lista(
          resumen: verTotales
              ? _Resumen(
                  etiqueta: 'Cobrado en ${Formato.mes(_mes).toLowerCase()}',
                  total: validos.fold(0.0, (a, p) => a + p.monto),
                  cantidad: validos.length,
                  color: context.colores.exito,
                )
              : null,
          vacio: const EstadoVacio(
            icono: Icons.payments_outlined,
            titulo: 'Sin cobros este mes',
            mensaje: 'Los cobros de trabajos y las ventas sueltas aparecen acá con su número de recibo.',
          ),
          children: [for (final p in pagos) FilaPago(pago: p)],
        );
      },
    );

    final gastos = StreamBuilder<List<Gasto>>(
      stream: verGastos ? caja.gastosDelMes(_mes) : const Stream.empty(),
      builder: (context, s) {
        if (s.hasError) return EstadoError(error: s.error);
        if (!s.hasData) return const Cargando();
        final gastos = s.data!;
        return _Lista(
          resumen: _Resumen(
            etiqueta: 'Gastado en ${Formato.mes(_mes).toLowerCase()}',
            total: gastos.fold(0.0, (a, g) => a + g.monto),
            cantidad: gastos.length,
            color: context.colores.peligro,
          ),
          vacio: const EstadoVacio(
            icono: Icons.receipt_outlined,
            titulo: 'Sin gastos este mes',
            mensaje: 'Registrá compras de repuestos, alquiler, servicios… para conocer tu ganancia real.',
          ),
          children: [for (final g in gastos) _FilaGasto(gasto: g)],
        );
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(verGastos ? 'Caja' : 'Cobros'),
        bottom: verGastos
            ? TabBar(
                controller: _tabs,
                tabs: const [
                  Tab(text: 'Cobros', icon: Icon(Icons.south_west_rounded, size: 20), iconMargin: EdgeInsets.only(bottom: 2)),
                  Tab(text: 'Gastos', icon: Icon(Icons.north_east_rounded, size: 20), iconMargin: EdgeInsets.only(bottom: 2)),
                ],
              )
            : null,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-caja',
        onPressed: () => esCobros ? nuevoIngreso(context) : abrirFormulario(context, const GastoForm()),
        icon: Icon(esCobros ? Icons.add_card_rounded : Icons.remove_circle_outline_rounded),
        label: Text(esCobros ? 'Nuevo ingreso' : 'Nuevo gasto'),
      ),
      body: ContenidoCentrado(
        anchoMaximo: 860,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(Espacio.l),
              child: Center(child: SelectorMes(mes: _mes, onCambio: (m) => setState(() => _mes = m))),
            ),
            Expanded(
              child: verGastos ? TabBarView(controller: _tabs, children: [cobros, gastos]) : cobros,
            ),
          ],
        ),
      ),
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.etiqueta, required this.total, required this.cantidad, required this.color});
  final String etiqueta;
  final double total;
  final int cantidad;
  final Color color;

  @override
  Widget build(BuildContext context) => AppCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(etiqueta, style: context.textos.bodyMedium?.copyWith(color: context.esquema.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text(Formato.moneda(total), style: context.textos.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            Etiqueta(
              texto: '$cantidad movimiento${cantidad == 1 ? '' : 's'}',
              color: color,
              fondo: color.withValues(alpha: 0.12),
            ),
          ],
        ),
      );
}

class _Lista extends StatelessWidget {
  const _Lista({required this.resumen, required this.vacio, required this.children});
  final Widget? resumen;
  final Widget vacio;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(Espacio.l, 0, Espacio.l, 96),
      children: [
        if (resumen != null) ...[resumen!, const SizedBox(height: Espacio.m)],
        if (children.isEmpty)
          SizedBox(height: 320, child: vacio)
        else
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: Espacio.s),
            child: Column(children: children),
          ),
      ],
    );
  }
}

class _FilaGasto extends StatelessWidget {
  const _FilaGasto({required this.gasto});
  final Gasto gasto;

  @override
  Widget build(BuildContext context) {
    final g = gasto;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: Espacio.l),
      leading: IconoTile(Icons.receipt_outlined, tamanio: 38, color: context.colores.peligro, fondo: context.colores.peligroSuave),
      title: Text(g.descripcion, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${g.categoria} · ${g.medio.etiqueta} · ${Formato.fecha(g.fecha)}', maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () => abrirFormulario(context, GastoForm(gasto: g)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(Formato.moneda(g.monto), style: context.textos.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'editar') {
                abrirFormulario(context, GastoForm(gasto: g));
              } else if (v == 'eliminar') {
                final ok = await confirmar(context, titulo: 'Eliminar gasto', mensaje: '¿Eliminar "${g.descripcion}"?', confirmar: 'Eliminar', peligroso: true);
                if (ok && context.mounted) {
                  await ejecutar(context, () => Sesion.of(context).caja.eliminarGasto(g.id), exito: 'Gasto eliminado');
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'editar', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Editar'))),
              PopupMenuItem(value: 'eliminar', child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Eliminar'))),
            ],
          ),
        ],
      ),
    );
  }
}
