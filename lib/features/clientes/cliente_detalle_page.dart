import 'package:flutter/material.dart';

import '../../app/sesion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formato.dart';
import '../../core/utils/whatsapp.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/feedback.dart';
import '../../data/models/cliente.dart';
import '../../data/models/orden.dart';
import '../../data/models/presupuesto.dart';
import '../presupuestos/presupuesto_detalle_page.dart';
import '../presupuestos/presupuesto_form.dart';
import '../presupuestos/widgets_presupuesto.dart';
import '../trabajos/orden_detalle_page.dart';
import '../trabajos/orden_form.dart';
import '../trabajos/widgets_orden.dart';
import 'cliente_form.dart';

class ClienteDetallePage extends StatelessWidget {
  const ClienteDetallePage({super.key, required this.clienteId});
  final String clienteId;

  @override
  Widget build(BuildContext context) {
    final sesion = Sesion.of(context);
    return StreamBuilder<Cliente?>(
      stream: sesion.clientes.observar(clienteId),
      builder: (context, s) {
        if (s.hasError) return Scaffold(appBar: AppBar(), body: EstadoError(error: s.error));
        if (s.connectionState == ConnectionState.waiting) return Scaffold(appBar: AppBar(), body: const Cargando());
        final cliente = s.data;
        if (cliente == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EstadoVacio(icono: Icons.person_off_outlined, titulo: 'El cliente ya no existe'),
          );
        }
        return _Contenido(cliente: cliente);
      },
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.cliente});
  final Cliente cliente;

  Future<void> _eliminar(BuildContext context) async {
    final ok = await confirmar(
      context,
      titulo: 'Eliminar cliente',
      mensaje: '¿Eliminar a ${cliente.nombre}? Esta acción no se puede deshacer.',
      confirmar: 'Eliminar',
      peligroso: true,
    );
    if (!ok || !context.mounted) return;
    final eliminado = await ejecutar(context, () => Sesion.of(context).clientes.eliminar(cliente.id), exito: 'Cliente eliminado');
    if (eliminado && context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final sesion = Sesion.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cliente'),
        actions: [
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => abrirFormulario(context, ClienteForm(cliente: cliente)),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'eliminar') _eliminar(context);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'eliminar', child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Eliminar'))),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-cliente-trabajo',
        onPressed: () async {
          final o = await abrirFormulario<Orden>(context, OrdenForm(clienteInicial: cliente));
          if (o != null && context.mounted) abrirPagina(context, OrdenDetallePage(ordenId: o.id));
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo trabajo'),
      ),
      body: StreamBuilder<List<Orden>>(
        stream: sesion.ordenes.deCliente(cliente.id),
        builder: (context, so) {
          final ordenes = so.data ?? const <Orden>[];
          final deuda = ordenes.where((o) => o.estado != EstadoOrden.cancelado).fold(0.0, (s, o) => s + o.saldo);
          final facturado = ordenes.where((o) => o.estado != EstadoOrden.cancelado).fold(0.0, (s, o) => s + o.total);
          return ListView(
            padding: const EdgeInsets.fromLTRB(Espacio.l, Espacio.l, Espacio.l, 96),
            children: [
              ContenidoCentrado(
                anchoMaximo: 860,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Encabezado(cliente: cliente),
                    const SizedBox(height: Espacio.m),
                    GrillaAdaptable(anchoMinimo: 200, children: [
                      Indicador(etiqueta: 'Trabajos', valor: '${ordenes.length}', icono: Icons.build_outlined),
                      Indicador(etiqueta: 'Total facturado', valor: Formato.moneda(facturado), icono: Icons.receipt_long_outlined),
                      Indicador(
                        etiqueta: 'Saldo pendiente',
                        valor: Formato.moneda(deuda),
                        icono: Icons.account_balance_wallet_outlined,
                        color: deuda > 0 ? context.colores.peligro : context.colores.exito,
                      ),
                    ]),
                    Seccion('Trabajos'),
                    if (so.hasError)
                      const EstadoError()
                    else if (!so.hasData)
                      const Cargando()
                    else if (ordenes.isEmpty)
                      _Vacio('Todavía no hay trabajos para este cliente.')
                    else
                      for (final o in ordenes) ...[
                        TarjetaOrden(
                          orden: o,
                          mostrarCliente: false,
                          onTap: () => abrirPagina(context, OrdenDetallePage(ordenId: o.id)),
                        ),
                        const SizedBox(height: Espacio.s),
                      ],
                    Seccion(
                      'Presupuestos',
                      accion: TextButton.icon(
                        onPressed: () async {
                          final p = await abrirFormulario<Presupuesto>(context, PresupuestoForm(clienteInicial: cliente));
                          if (p != null && context.mounted) abrirPagina(context, PresupuestoDetallePage(presupuestoId: p.id));
                        },
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Nuevo'),
                      ),
                    ),
                    StreamBuilder<List<Presupuesto>>(
                      stream: sesion.presupuestos.deCliente(cliente.id),
                      builder: (context, sp) {
                        if (sp.hasError) return const EstadoError();
                        if (!sp.hasData) return const Cargando();
                        if (sp.data!.isEmpty) return _Vacio('Sin presupuestos.');
                        return Column(
                          children: [
                            for (final p in sp.data!) ...[
                              TarjetaPresupuesto(
                                presupuesto: p,
                                mostrarCliente: false,
                                onTap: () => abrirPagina(context, PresupuestoDetallePage(presupuestoId: p.id)),
                              ),
                              const SizedBox(height: Espacio.s),
                            ],
                          ],
                        );
                      },
                    ),
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

class _Vacio extends StatelessWidget {
  const _Vacio(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: Espacio.l),
        child: Text(texto, style: TextStyle(color: context.esquema.onSurfaceVariant)),
      );
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.cliente});
  final Cliente cliente;

  @override
  Widget build(BuildContext context) {
    final datos = <(IconData, String)>[
      if (cliente.telefono.isNotEmpty) (Icons.phone_outlined, cliente.telefono),
      if (cliente.documento.isNotEmpty) (Icons.badge_outlined, cliente.documento),
      if (cliente.email.isNotEmpty) (Icons.alternate_email_rounded, cliente.email),
      if (cliente.direccion.isNotEmpty) (Icons.place_outlined, cliente.direccion),
    ];
    return AppCard(
      padding: const EdgeInsets.all(Espacio.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Iniciales(cliente.iniciales, radio: 28),
              const SizedBox(width: Espacio.l),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cliente.nombre, style: context.textos.titleLarge),
                    if (cliente.fechaAlta != null)
                      Text(
                        'Cliente desde ${Formato.fecha(cliente.fechaAlta!)}',
                        style: context.textos.bodySmall?.copyWith(color: context.esquema.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (datos.isNotEmpty) ...[
            const SizedBox(height: Espacio.l),
            Wrap(
              spacing: Espacio.xl,
              runSpacing: Espacio.s,
              children: [
                for (final d in datos)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(d.$1, size: 16, color: context.esquema.onSurfaceVariant),
                    const SizedBox(width: 6),
                    SelectableText(d.$2),
                  ]),
              ],
            ),
          ],
          if (cliente.notas.isNotEmpty) ...[
            const SizedBox(height: Espacio.m),
            Text(cliente.notas, style: context.textos.bodyMedium?.copyWith(color: context.esquema.onSurfaceVariant)),
          ],
          if (cliente.telefono.isNotEmpty) ...[
            const SizedBox(height: Espacio.l),
            Wrap(
              spacing: Espacio.s,
              runSpacing: Espacio.s,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () async {
                    final ok = await WhatsApp.enviar(cliente.telefono, 'Hola ${cliente.nombre.split(' ').first}! ');
                    if (!ok && context.mounted) mostrarMensaje(context, 'El teléfono no parece válido para WhatsApp', error: true);
                  },
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('WhatsApp'),
                ),
                OutlinedButton.icon(
                  onPressed: () => llamarPorTelefono(cliente.telefono),
                  icon: const Icon(Icons.call_outlined),
                  label: const Text('Llamar'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
