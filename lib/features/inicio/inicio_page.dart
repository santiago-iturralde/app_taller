import 'package:flutter/material.dart';

import '../../app/sesion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/feedback.dart';
import '../../data/models/caja.dart';
import '../../data/models/negocio.dart';
import '../../data/models/orden.dart';
import '../caja/caja_page.dart';
import '../caja/venta_form.dart';
import '../productos/productos_page.dart';
import '../productos/producto_detalle_page.dart';
import '../productos/widgets_producto.dart';
import '../../data/models/producto.dart';
import 'recordatorios.dart';
import '../caja/gasto_form.dart';
import '../clientes/cliente_detalle_page.dart';
import '../clientes/cliente_form.dart';
import '../presupuestos/presupuestos_page.dart';
import '../trabajos/orden_detalle_page.dart';
import '../trabajos/trabajos_page.dart';
import '../trabajos/widgets_orden.dart';
import '../../data/models/cliente.dart';

/// Pantalla de inicio: qué hay que hacer hoy y cómo viene el mes.
class InicioPage extends StatelessWidget {
  const InicioPage({super.key, required this.irATrabajos});

  /// Cambia a la sección Trabajos (opcionalmente filtrada).
  final void Function(EstadoOrden? filtro) irATrabajos;

  String _saludo() {
    final h = DateTime.now().hour;
    if (h < 13) return 'Buen día';
    if (h < 20) return 'Buenas tardes';
    return 'Buenas noches';
  }

  @override
  Widget build(BuildContext context) {
    final sesion = Sesion.of(context);
    final ahora = DateTime.now();
    return Scaffold(
      appBar: context.esEscritorio ? null : AppBar(title: Text(sesion.negocio.nombre)),
      body: StreamBuilder<List<Orden>>(
        stream: sesion.ordenes.activas(),
        builder: (context, sa) {
          if (sa.hasError) return EstadoError(error: sa.error);
          final activas = sa.data;
          return ListView(
            padding: const EdgeInsets.all(Espacio.l),
            children: [
              ContenidoCentrado(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (context.esEscritorio) const SizedBox(height: Espacio.l),
                    Text('${_saludo()} 👋', style: context.textos.headlineSmall),
                    Text(
                      Formato.fechaLarga(ahora),
                      style: context.textos.bodyMedium?.copyWith(color: context.esquema.onSurfaceVariant),
                    ),
                    const SizedBox(height: Espacio.xl),
                    const _AccionesRapidas(),
                    const SizedBox(height: Espacio.xl),
                    if (activas == null)
                      const SizedBox(height: 200, child: Cargando())
                    else ...[
                      _Indicadores(activas: activas, irATrabajos: irATrabajos),
                      const SeccionRecordatorios(),
                      const _StockBajo(),
                      _ListaSeccion(
                        titulo: 'Listos para retirar',
                        ordenes: activas.where((o) => o.estado == EstadoOrden.listo).toList(),
                        vacio: 'No hay trabajos esperando retiro.',
                        verTodos: () => irATrabajos(EstadoOrden.listo),
                        avisar: true,
                      ),
                      _ListaSeccion(
                        titulo: 'Atrasados',
                        ordenes: activas.where((o) => o.atrasada).toList(),
                        ocultarSiVacio: true,
                        verTodos: () => irATrabajos(null),
                      ),
                      _ListaSeccion(
                        titulo: 'Últimos ingresados',
                        ordenes: activas.take(5).toList(),
                        vacio: 'Cuando registres trabajos van a aparecer acá.',
                        verTodos: () => irATrabajos(null),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AccionesRapidas extends StatelessWidget {
  const _AccionesRapidas();

  @override
  Widget build(BuildContext context) {
    final acciones = <(IconData, String, VoidCallback)>[
      (Icons.add_task_rounded, 'Nuevo trabajo', () => nuevoTrabajo(context)),
      (
        Icons.person_add_alt_1_rounded,
        'Nuevo cliente',
        () async {
          final c = await abrirFormulario<Cliente>(context, const ClienteForm());
          if (c != null && context.mounted) abrirPagina(context, ClienteDetallePage(clienteId: c.id));
        },
      ),
      (Icons.request_quote_outlined, 'Presupuesto', () => nuevoPresupuesto(context)),
      (Icons.shopping_bag_outlined, 'Venta / cobro', () => nuevoIngreso(context)),
      if (Sesion.of(context).puede(Permiso.verGastos))
        (Icons.remove_circle_outline_rounded, 'Gasto', () => abrirFormulario(context, const GastoForm())),
    ];
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: acciones.length,
        separatorBuilder: (_, __) => const SizedBox(width: Espacio.s),
        itemBuilder: (context, i) {
          final a = acciones[i];
          return SizedBox(
            width: 116,
            child: AppCard(
              padding: const EdgeInsets.all(Espacio.m),
              onTap: a.$3,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconoTile(a.$1, tamanio: 36),
                  const SizedBox(height: Espacio.s),
                  Text(
                    a.$2,
                    style: context.textos.labelMedium,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Indicadores extends StatelessWidget {
  const _Indicadores({required this.activas, required this.irATrabajos});
  final List<Orden> activas;
  final void Function(EstadoOrden?) irATrabajos;

  @override
  Widget build(BuildContext context) {
    final sesion = Sesion.of(context);
    final c = context.colores;
    final listos = activas.where((o) => o.estado == EstadoOrden.listo).length;
    final mes = DateTime(DateTime.now().year, DateTime.now().month);

    return StreamBuilder<List<Orden>>(
      stream: sesion.ordenes.conSaldo(),
      builder: (context, sd) {
        final deudores = (sd.data ?? const <Orden>[])
            .where((o) => !o.estado.activo || o.estado == EstadoOrden.listo)
            .toList();
        final porCobrar = deudores.fold(0.0, (s, o) => s + o.saldo);
        return StreamBuilder<List<Pago>>(
          stream: sesion.caja.pagosDelMes(mes),
          builder: (context, sp) {
            final cobrado = (sp.data ?? const <Pago>[]).where((p) => p.cuentaEnCaja).fold(0.0, (s, p) => s + p.monto);
            return GrillaAdaptable(
              anchoMinimo: 230,
              children: [
                Indicador(
                  etiqueta: 'Trabajos en curso',
                  valor: '${activas.length}',
                  icono: Icons.build_outlined,
                  color: c.info,
                  onTap: () => irATrabajos(null),
                ),
                Indicador(
                  etiqueta: 'Listos para retirar',
                  valor: '$listos',
                  icono: Icons.check_circle_outline_rounded,
                  color: c.exito,
                  onTap: () => irATrabajos(EstadoOrden.listo),
                ),
                Indicador(
                  etiqueta: 'Por cobrar',
                  valor: Formato.moneda(porCobrar),
                  icono: Icons.account_balance_wallet_outlined,
                  color: c.peligro,
                  detalle: deudores.isEmpty
                      ? 'Nada pendiente'
                      : '${deudores.length} trabajo${deudores.length == 1 ? '' : 's'} terminado${deudores.length == 1 ? '' : 's'}',
                  onTap: deudores.isEmpty ? null : () => _verDeudores(context, deudores),
                ),
                if (sesion.puede(Permiso.verTotalesCaja))
                  Indicador(
                    etiqueta: 'Cobrado en ${Formato.mes(mes).toLowerCase()}',
                    valor: Formato.moneda(cobrado),
                    icono: Icons.south_west_rounded,
                    color: c.exito,
                    onTap: () => abrirPagina(context, const CajaPage()),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  void _verDeudores(BuildContext context, List<Orden> deudores) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(Espacio.l),
          children: [
            Text('Trabajos terminados con saldo', style: context.textos.titleMedium),
            const SizedBox(height: Espacio.m),
            for (final o in deudores) ...[
              TarjetaOrden(
                orden: o,
                onTap: () {
                  Navigator.pop(context);
                  abrirPagina(context, OrdenDetallePage(ordenId: o.id));
                },
              ),
              const SizedBox(height: Espacio.s),
            ],
          ],
        ),
      ),
    );
  }
}

class _ListaSeccion extends StatelessWidget {
  const _ListaSeccion({
    required this.titulo,
    required this.ordenes,
    required this.verTodos,
    this.vacio,
    this.ocultarSiVacio = false,
    this.avisar = false,
  });

  final String titulo;
  final List<Orden> ordenes;
  final VoidCallback verTodos;
  final String? vacio;
  final bool ocultarSiVacio;
  final bool avisar;

  @override
  Widget build(BuildContext context) {
    if (ordenes.isEmpty && ocultarSiVacio) return const SizedBox.shrink();
    final visibles = ordenes.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Seccion(
          ordenes.isEmpty ? titulo : '$titulo (${ordenes.length})',
          accion: ordenes.length > visibles.length
              ? TextButton(onPressed: verTodos, child: const Text('Ver todos'))
              : null,
        ),
        if (ordenes.isEmpty)
          AppCard(
            child: Text(vacio ?? '', style: TextStyle(color: context.esquema.onSurfaceVariant)),
          )
        else
          GrillaAdaptable(
            anchoMinimo: 420,
            espacio: Espacio.s,
            children: [
              for (final o in visibles)
                TarjetaOrden(
                  orden: o,
                  onTap: () => abrirPagina(context, OrdenDetallePage(ordenId: o.id)),
                  accion: (avisar && o.clienteTelefono.isNotEmpty)
                      ? IconButton.filledTonal(
                          tooltip: 'Avisar por WhatsApp',
                          icon: const Icon(Icons.chat_outlined, size: 20),
                          onPressed: () => avisarPorWhatsApp(context, o, PlantillasMensaje.listo),
                        )
                      : null,
                ),
            ],
          ),
      ],
    );
  }
}

/// Aviso de productos con stock bajo (sólo aparece si hay alguno).
class _StockBajo extends StatelessWidget {
  const _StockBajo();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Producto>>(
      stream: Sesion.of(context).productos.conStockBajo(),
      builder: (context, s) {
        final lista = s.data ?? const <Producto>[];
        if (lista.isEmpty) return const SizedBox.shrink();
        lista.sort((a, b) => a.stock.compareTo(b.stock));
        final visibles = lista.take(6).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Seccion(
              'Stock bajo (${lista.length})',
              accion: lista.length > visibles.length
                  ? TextButton(
                      onPressed: () => abrirPagina(context, const ProductosPage()),
                      child: const Text('Ver todos'),
                    )
                  : null,
            ),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: Espacio.s),
              child: Column(
                children: [
                  for (final p in visibles)
                    ListTile(
                      leading: Icon(Icons.warning_amber_rounded, color: context.colores.alerta),
                      title: Text(p.nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: p.stockMinimo > 0 ? Text('Mínimo: ${Formato.cantidad(p.stockMinimo)}') : null,
                      trailing: EtiquetaStock(p),
                      onTap: () => abrirPagina(context, ProductoDetallePage(productoId: p.id)),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
