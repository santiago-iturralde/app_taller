import 'package:flutter/material.dart';

import '../../app/sesion.dart';
import '../../core/pdf/documentos_pdf.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formato.dart';
import '../../core/utils/whatsapp.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/feedback.dart';
import '../../data/models/negocio.dart';
import '../../data/models/presupuesto.dart';
import '../clientes/cliente_detalle_page.dart';
import '../trabajos/orden_detalle_page.dart';
import 'presupuesto_form.dart';
import 'widgets_presupuesto.dart';

class PresupuestoDetallePage extends StatelessWidget {
  const PresupuestoDetallePage({super.key, required this.presupuestoId});
  final String presupuestoId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Presupuesto?>(
      stream: Sesion.of(context).presupuestos.observar(presupuestoId),
      builder: (context, s) {
        if (s.hasError) return Scaffold(appBar: AppBar(), body: EstadoError(error: s.error));
        if (s.connectionState == ConnectionState.waiting) return Scaffold(appBar: AppBar(), body: const Cargando());
        final p = s.data;
        if (p == null) {
          return Scaffold(appBar: AppBar(), body: const EstadoVacio(icono: Icons.search_off_rounded, titulo: 'El presupuesto ya no existe'));
        }
        return _Detalle(p: p);
      },
    );
  }
}

class _Detalle extends StatelessWidget {
  const _Detalle({required this.p});
  final Presupuesto p;

  void _pdf(BuildContext context) => DocumentosPdf.abrir(
        context,
        nombreArchivo: nombreArchivoPdf('Presupuesto', p.numero, p.clienteNombre),
        generar: (pdf) => pdf.presupuesto(p),
      );

  Future<void> _whatsapp(BuildContext context) async {
    final negocio = Sesion.of(context).negocio;
    if (p.clienteTelefono.isEmpty) {
      mostrarMensaje(context, 'El cliente no tiene teléfono cargado', error: true);
      return;
    }
    final detalle = p.items.map((i) => '• ${i.descripcion}: ${Formato.moneda(i.subtotal)}').join('\n');
    final mensaje = '${WhatsApp.aplicarPlantilla(negocio.plantilla(PlantillasMensaje.presupuesto), {
          'cliente': p.clienteNombre.split(' ').first,
          'numero': Formato.numeroComprobante(p.numero),
          'total': Formato.moneda(p.total),
          'equipo': p.equipo,
          'negocio': negocio.nombre,
        })}\n\n$detalle';
    final ok = await WhatsApp.enviar(p.clienteTelefono, mensaje);
    if (!ok && context.mounted) mostrarMensaje(context, 'El teléfono no parece válido para WhatsApp', error: true);
  }

  Future<void> _convertir(BuildContext context) async {
    final ok = await confirmar(
      context,
      titulo: 'Convertir en trabajo',
      mensaje: 'Se marcará el presupuesto como aprobado y se creará un trabajo con estos ítems.',
      confirmar: 'Crear trabajo',
    );
    if (!ok || !context.mounted) return;
    final sesion = Sesion.of(context);
    try {
      final orden = await sesion.presupuestos.convertirEnOrden(p);
      if (!context.mounted) return;
      mostrarMensaje(context, 'Trabajo N° ${Formato.numeroComprobante(orden.numero)} creado');
      abrirPagina(context, OrdenDetallePage(ordenId: orden.id));
    } catch (e) {
      if (context.mounted) mostrarMensaje(context, mensajeDeError(e), error: true);
    }
  }

  Future<void> _eliminar(BuildContext context) async {
    final ok = await confirmar(
      context,
      titulo: 'Eliminar presupuesto',
      mensaje: '¿Eliminar el presupuesto N° ${Formato.numeroComprobante(p.numero)}?',
      confirmar: 'Eliminar',
      peligroso: true,
    );
    if (!ok || !context.mounted) return;
    final hecho = await ejecutar(context, () => Sesion.of(context).presupuestos.eliminar(p), exito: 'Presupuesto eliminado');
    if (hecho && context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final repo = Sesion.of(context).presupuestos;
    final pendiente = p.estado == EstadoPresupuesto.pendiente;
    return Scaffold(
      appBar: AppBar(
        title: Text('Presupuesto N° ${Formato.numeroComprobante(p.numero)}'),
        actions: [
          IconButton(tooltip: 'PDF', icon: const Icon(Icons.picture_as_pdf_outlined), onPressed: () => _pdf(context)),
          if (p.ordenId == null)
            IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => abrirFormulario(context, PresupuestoForm(presupuesto: p)),
            ),
          PopupMenuButton<String>(
            onSelected: (v) => switch (v) {
              'rechazar' => ejecutar(context, () => repo.cambiarEstado(p.id, EstadoPresupuesto.rechazado), exito: 'Marcado como rechazado'),
              'pendiente' => ejecutar(context, () => repo.cambiarEstado(p.id, EstadoPresupuesto.pendiente)),
              'eliminar' => _eliminar(context),
              _ => null,
            },
            itemBuilder: (_) => [
              if (pendiente)
                const PopupMenuItem(value: 'rechazar', child: ListTile(leading: Icon(Icons.thumb_down_alt_outlined), title: Text('Marcar como rechazado'))),
              if (p.estado == EstadoPresupuesto.rechazado)
                const PopupMenuItem(value: 'pendiente', child: ListTile(leading: Icon(Icons.undo_rounded), title: Text('Volver a pendiente'))),
              if (p.ordenId == null && Sesion.of(context).puede(Permiso.eliminarRegistros))
                const PopupMenuItem(value: 'eliminar', child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Eliminar'))),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Espacio.l),
        child: ContenidoCentrado(
          anchoMaximo: 760,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                padding: const EdgeInsets.all(Espacio.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => abrirPagina(context, ClienteDetallePage(clienteId: p.clienteId)),
                          child: Text(p.clienteNombre, style: context.textos.titleLarge),
                        ),
                      ),
                      EtiquetaPresupuesto(p),
                    ]),
                    if (p.equipo.isNotEmpty) Text(p.equipo, style: TextStyle(color: context.esquema.onSurfaceVariant)),
                    const SizedBox(height: Espacio.s),
                    Text(
                      'Emitido el ${Formato.fecha(p.fecha)} · Válido hasta el ${Formato.fecha(p.vence)}',
                      style: context.textos.bodySmall?.copyWith(color: context.esquema.onSurfaceVariant),
                    ),
                    const SizedBox(height: Espacio.l),
                    Wrap(spacing: Espacio.s, runSpacing: Espacio.s, children: [
                      if (p.ordenId != null)
                        FilledButton.tonalIcon(
                          onPressed: () => abrirPagina(context, OrdenDetallePage(ordenId: p.ordenId!)),
                          icon: const Icon(Icons.build_outlined),
                          label: const Text('Ver trabajo'),
                        )
                      else if (p.estado != EstadoPresupuesto.rechazado)
                        FilledButton.icon(
                          onPressed: () => _convertir(context),
                          icon: const Icon(Icons.task_alt_rounded),
                          label: const Text('Aprobar y crear trabajo'),
                        ),
                      OutlinedButton.icon(onPressed: () => _whatsapp(context), icon: const Icon(Icons.chat_outlined), label: const Text('Enviar por WhatsApp')),
                      OutlinedButton.icon(onPressed: () => _pdf(context), icon: const Icon(Icons.picture_as_pdf_outlined), label: const Text('PDF')),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: Espacio.m),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Detalle', style: context.textos.titleSmall),
                    const SizedBox(height: Espacio.s),
                    for (final i in p.items)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(children: [
                          Expanded(child: Text(i.descripcion)),
                          if (i.cantidad != 1)
                            Text(
                              '${Formato.cantidad(i.cantidad)} × ${Formato.moneda(i.precioUnitario)}   ',
                              style: TextStyle(color: context.esquema.onSurfaceVariant, fontSize: 12),
                            ),
                          Text(Formato.moneda(i.subtotal)),
                        ]),
                      ),
                    const Divider(height: Espacio.xl),
                    FilaDato('Total', Formato.moneda(p.total), destacado: true),
                    if (p.notas.isNotEmpty) ...[
                      const SizedBox(height: Espacio.l),
                      Text('Observaciones', style: context.textos.labelMedium?.copyWith(color: context.esquema.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      Text(p.notas),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
