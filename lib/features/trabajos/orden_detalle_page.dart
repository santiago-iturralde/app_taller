import 'package:flutter/material.dart';

import '../../app/sesion.dart';
import '../../core/pdf/documentos_pdf.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formato.dart';
import '../../core/utils/whatsapp.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/feedback.dart';
import '../../data/models/caja.dart';
import '../../data/models/negocio.dart';
import '../../data/models/orden.dart';
import '../caja/cobro_form.dart';
import '../caja/widgets_caja.dart';
import '../clientes/cliente_detalle_page.dart';
import '../inicio/recordatorios.dart';
import 'orden_form.dart';
import 'widgets_orden.dart';

/// Arma el mensaje de WhatsApp de un trabajo a partir de la plantilla.
String mensajeOrden(Negocio negocio, Orden o, String plantilla) => WhatsApp.aplicarPlantilla(
      negocio.plantilla(plantilla),
      {
        'cliente': o.clienteNombre.split(' ').first,
        'equipo': o.equipo.descripcion,
        'numero': Formato.numeroComprobante(o.numero),
        'total': o.sinPresupuestar ? 'a confirmar' : Formato.moneda(o.total),
        'saldo': Formato.moneda(o.saldo),
        'negocio': negocio.nombre,
      },
    );

Future<void> avisarPorWhatsApp(BuildContext context, Orden o, String plantilla) async {
  if (o.clienteTelefono.isEmpty) {
    mostrarMensaje(context, 'El cliente no tiene teléfono cargado', error: true);
    return;
  }
  final ok = await WhatsApp.enviar(o.clienteTelefono, mensajeOrden(Sesion.of(context).negocio, o, plantilla));
  if (!ok && context.mounted) {
    mostrarMensaje(context, 'El teléfono "${o.clienteTelefono}" no parece válido para WhatsApp', error: true);
  }
}

Future<void> cambiarEstadoOrden(BuildContext context, Orden o, EstadoOrden nuevo) async {
  if (nuevo == EstadoOrden.cancelado) {
    final ok = await confirmar(
      context,
      titulo: 'Cancelar trabajo',
      mensaje: 'El trabajo quedará como cancelado y su saldo no se contará como deuda.',
      confirmar: 'Cancelar trabajo',
      peligroso: true,
    );
    if (!ok || !context.mounted) return;
  }
  final sesion = Sesion.of(context);
  final ok = await ejecutar(context, () => sesion.ordenes.cambiarEstado(o.id, nuevo));
  if (!ok || !context.mounted) return;
  mostrarMensaje(
    context,
    'Estado: ${nuevo.etiqueta}',
    accion: (nuevo == EstadoOrden.listo && o.clienteTelefono.isNotEmpty)
        ? SnackBarAction(
            label: 'Avisar por WhatsApp',
            onPressed: () => avisarPorWhatsApp(context, o.copyWith(estado: nuevo), PlantillasMensaje.listo),
          )
        : null,
  );
}

class OrdenDetallePage extends StatelessWidget {
  const OrdenDetallePage({super.key, required this.ordenId});
  final String ordenId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Orden?>(
      stream: Sesion.of(context).ordenes.observar(ordenId),
      builder: (context, s) {
        if (s.hasError) return Scaffold(appBar: AppBar(), body: EstadoError(error: s.error));
        if (s.connectionState == ConnectionState.waiting) return Scaffold(appBar: AppBar(), body: const Cargando());
        final orden = s.data;
        if (orden == null) {
          return Scaffold(appBar: AppBar(), body: const EstadoVacio(icono: Icons.search_off_rounded, titulo: 'El trabajo ya no existe'));
        }
        return _Detalle(orden: orden);
      },
    );
  }
}

class _Detalle extends StatelessWidget {
  const _Detalle({required this.orden});
  final Orden orden;

  Future<void> _eliminar(BuildContext context) async {
    final ok = await confirmar(
      context,
      titulo: 'Eliminar trabajo',
      mensaje: 'Se eliminará el trabajo N° ${Formato.numeroComprobante(orden.numero)}. Esta acción no se puede deshacer.',
      confirmar: 'Eliminar',
      peligroso: true,
    );
    if (!ok || !context.mounted) return;
    final eliminado = await ejecutar(context, () => Sesion.of(context).ordenes.eliminar(orden), exito: 'Trabajo eliminado');
    if (eliminado && context.mounted) Navigator.pop(context);
  }

  void _imprimir(BuildContext context) => DocumentosPdf.abrir(
        context,
        nombreArchivo: nombreArchivoPdf('Orden', orden.numero, orden.clienteNombre),
        generar: (pdf) => pdf.orden(orden),
      );

  @override
  Widget build(BuildContext context) {
    final rubro = Sesion.of(context).negocio.rubro;
    final ancho = context.esEscritorio;

    final principal = [
      _Encabezado(orden: orden),
      const SizedBox(height: Espacio.m),
      _Acciones(orden: orden),
      const SizedBox(height: Espacio.m),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trabajo', style: context.textos.titleSmall),
            const SizedBox(height: Espacio.s),
            Text(orden.problema.isEmpty ? '-' : orden.problema),
            if (orden.notas.isNotEmpty) ...[
              const SizedBox(height: Espacio.l),
              Row(children: [
                Icon(Icons.lock_outline_rounded, size: 14, color: context.esquema.onSurfaceVariant),
                const SizedBox(width: 4),
                Text('Notas internas', style: context.textos.labelMedium?.copyWith(color: context.esquema.onSurfaceVariant)),
              ]),
              const SizedBox(height: 4),
              Text(orden.notas),
            ],
            const Divider(height: Espacio.xxl),
            Wrap(
              spacing: Espacio.xl,
              runSpacing: Espacio.s,
              children: [
                _MiniDato('Ingreso', Formato.fecha(orden.fechaIngreso)),
                if (orden.fechaEstimada != null) _MiniDato('Entrega estimada', Formato.fecha(orden.fechaEstimada!)),
                if (orden.fechaListo != null) _MiniDato('Listo', Formato.fecha(orden.fechaListo!)),
                if (orden.fechaEntrega != null) _MiniDato('Entregado', Formato.fecha(orden.fechaEntrega!)),
                if (orden.equipo.identificador.isNotEmpty) _MiniDato(rubro.identificador, orden.equipo.identificador),
                if (orden.equipo.kilometraje != null) _MiniDato('Kilometraje', '${Formato.cantidad(orden.equipo.kilometraje!)} km'),
              ],
            ),
          ],
        ),
      ),
    ];
    final lateral = [
      _Importe(orden: orden),
      if (orden.tieneProximoService) ...[const SizedBox(height: Espacio.m), _ProximoService(orden: orden)],
      const SizedBox(height: Espacio.m),
      _Cobros(orden: orden),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Trabajo N° ${Formato.numeroComprobante(orden.numero)}'),
        actions: [
          IconButton(tooltip: 'Imprimir orden', icon: const Icon(Icons.print_outlined), onPressed: () => _imprimir(context)),
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => abrirFormulario(context, OrdenForm(orden: orden)),
          ),
          PopupMenuButton<String>(
            onSelected: (v) => switch (v) {
              'cancelar' => cambiarEstadoOrden(context, orden, EstadoOrden.cancelado),
              'eliminar' => _eliminar(context),
              'recibido' => avisarPorWhatsApp(context, orden, PlantillasMensaje.recibido),
              _ => null,
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'recibido',
                child: ListTile(leading: Icon(Icons.chat_outlined), title: Text('Enviar confirmación de recepción')),
              ),
              if (orden.estado != EstadoOrden.cancelado)
                const PopupMenuItem(value: 'cancelar', child: ListTile(leading: Icon(Icons.block_rounded), title: Text('Cancelar trabajo'))),
              if (Sesion.of(context).puede(Permiso.eliminarRegistros))
                const PopupMenuItem(value: 'eliminar', child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Eliminar'))),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Espacio.l),
        child: ContenidoCentrado(
          child: ancho
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: principal)),
                    const SizedBox(width: Espacio.l),
                    Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: lateral)),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [...principal, const SizedBox(height: Espacio.m), ...lateral],
                ),
        ),
      ),
    );
  }
}

class _MiniDato extends StatelessWidget {
  const _MiniDato(this.etiqueta, this.valor);
  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(etiqueta, style: context.textos.labelSmall?.copyWith(color: context.esquema.onSurfaceVariant)),
          Text(valor, style: context.textos.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      );
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.orden});
  final Orden orden;

  @override
  Widget build(BuildContext context) {
    final rubro = Sesion.of(context).negocio.rubro;
    return AppCard(
      padding: const EdgeInsets.all(Espacio.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconoTile(rubro.icono, tamanio: 48),
              const SizedBox(width: Espacio.l),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(orden.equipo.descripcion, style: context.textos.titleLarge),
                    const SizedBox(height: 2),
                    InkWell(
                      onTap: orden.clienteId.isEmpty
                          ? null
                          : () => abrirPagina(context, ClienteDetallePage(clienteId: orden.clienteId)),
                      child: Text(
                        orden.clienteNombre,
                        style: context.textos.bodyMedium?.copyWith(
                          color: context.esquema.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Espacio.l),
          Wrap(spacing: Espacio.s, runSpacing: Espacio.s, children: [
            EtiquetaEstado(orden.estado),
            EtiquetaPago(orden),
            if (orden.atrasada)
              Etiqueta(texto: 'Atrasado', color: context.colores.alerta, fondo: context.colores.alertaSuave, icono: Icons.schedule_rounded),
          ]),
          if (orden.estado != EstadoOrden.cancelado) ...[
            const SizedBox(height: Espacio.xl),
            _Progreso(estado: orden.estado),
          ],
        ],
      ),
    );
  }
}

/// Línea de progreso Recibido → En proceso → Listo → Entregado.
class _Progreso extends StatelessWidget {
  const _Progreso({required this.estado});
  final EstadoOrden estado;

  static const _pasos = [EstadoOrden.recibido, EstadoOrden.enProceso, EstadoOrden.listo, EstadoOrden.entregado];

  int get _actual => switch (estado) {
        EstadoOrden.esperandoRepuesto => 1,
        _ => _pasos.indexOf(estado),
      };

  @override
  Widget build(BuildContext context) {
    final activo = context.esquema.primary;
    final inactivo = context.colores.borde;
    return Row(
      children: [
        for (var i = 0; i < _pasos.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                Row(children: [
                  Expanded(child: Container(height: 3, color: i == 0 ? Colors.transparent : (i <= _actual ? activo : inactivo))),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i <= _actual ? activo : context.esquema.surface,
                      border: Border.all(color: i <= _actual ? activo : inactivo, width: 2),
                    ),
                    child: i < _actual || (i == _actual && estado == EstadoOrden.entregado)
                        ? Icon(Icons.check_rounded, size: 14, color: context.esquema.onPrimary)
                        : null,
                  ),
                  Expanded(
                    child: Container(
                      height: 3,
                      color: i == _pasos.length - 1 ? Colors.transparent : (i < _actual ? activo : inactivo),
                    ),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(
                  i == 1 && estado == EstadoOrden.esperandoRepuesto ? 'Esperando repuesto' : _pasos[i].etiqueta.split(' ').first,
                  textAlign: TextAlign.center,
                  style: context.textos.labelSmall?.copyWith(
                    fontWeight: i == _actual ? FontWeight.w700 : FontWeight.w500,
                    color: i <= _actual ? null : context.esquema.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Acción principal según el estado + cambio de estado libre + WhatsApp.
class _Acciones extends StatelessWidget {
  const _Acciones({required this.orden});
  final Orden orden;

  @override
  Widget build(BuildContext context) {
    final siguiente = orden.estado.siguiente;
    return Wrap(
      spacing: Espacio.s,
      runSpacing: Espacio.s,
      children: [
        if (siguiente != null)
          FilledButton.icon(
            onPressed: () => cambiarEstadoOrden(context, orden, siguiente),
            icon: Icon(siguiente.icono),
            label: Text(switch (siguiente) {
              EstadoOrden.enProceso => 'Empezar trabajo',
              EstadoOrden.listo => 'Marcar como listo',
              EstadoOrden.entregado => 'Entregar al cliente',
              _ => siguiente.etiqueta,
            }),
          ),
        MenuAnchor(
          builder: (context, controller, _) => OutlinedButton.icon(
            onPressed: () => controller.isOpen ? controller.close() : controller.open(),
            icon: const Icon(Icons.swap_horiz_rounded),
            label: const Text('Cambiar estado'),
          ),
          menuChildren: [
            for (final e in EstadoOrden.values.where((e) => e != orden.estado && e != EstadoOrden.cancelado))
              MenuItemButton(
                leadingIcon: Icon(e.icono, size: 20),
                onPressed: () => cambiarEstadoOrden(context, orden, e),
                child: Text(e.etiqueta),
              ),
          ],
        ),
        if (orden.clienteTelefono.isNotEmpty)
          OutlinedButton.icon(
            onPressed: () => avisarPorWhatsApp(
              context,
              orden,
              orden.estado == EstadoOrden.listo ? PlantillasMensaje.listo : PlantillasMensaje.recibido,
            ),
            icon: const Icon(Icons.chat_outlined),
            label: Text(orden.estado == EstadoOrden.listo ? 'Avisar que está listo' : 'WhatsApp'),
          ),
      ],
    );
  }
}

class _Importe extends StatelessWidget {
  const _Importe({required this.orden});
  final Orden orden;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: Text('Importe', style: context.textos.titleSmall)),
            TextButton(
              onPressed: () => abrirFormulario(context, OrdenForm(orden: orden)),
              child: Text(orden.items.isEmpty ? 'Cargar' : 'Editar'),
            ),
          ]),
          if (orden.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Espacio.s),
              child: Text('Todavía no tiene importe.', style: TextStyle(color: context.esquema.onSurfaceVariant)),
            )
          else ...[
            for (final i in orden.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text.rich(TextSpan(children: [
                        TextSpan(text: i.descripcion),
                        if (i.cantidad != 1)
                          TextSpan(
                            text: '  ${Formato.cantidad(i.cantidad)} × ${Formato.moneda(i.precioUnitario)}',
                            style: TextStyle(color: context.esquema.onSurfaceVariant, fontSize: 12),
                          ),
                      ])),
                    ),
                    Text(Formato.moneda(i.subtotal)),
                  ],
                ),
              ),
            const Divider(height: Espacio.xl),
            FilaDato('Total', Formato.moneda(orden.total), destacado: true),
            FilaDato('Cobrado', Formato.moneda(orden.pagado), colorValor: context.colores.exito),
            if (orden.estado != EstadoOrden.cancelado)
              FilaDato('Saldo', Formato.moneda(orden.saldo), destacado: true, colorValor: orden.saldo > 0 ? context.colores.peligro : null),
          ],
          if (orden.estado != EstadoOrden.cancelado && (orden.saldo > 0 || orden.sinPresupuestar)) ...[
            const SizedBox(height: Espacio.m),
            FilledButton.icon(
              onPressed: () => abrirFormulario<Pago>(context, CobroForm(orden: orden)),
              icon: const Icon(Icons.payments_outlined),
              label: Text(orden.sinPresupuestar ? 'Registrar seña' : 'Registrar cobro'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Cobros extends StatelessWidget {
  const _Cobros({required this.orden});
  final Orden orden;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Pago>>(
      stream: Sesion.of(context).caja.pagosDeOrden(orden.id),
      builder: (context, s) {
        final pagos = s.data ?? const [];
        if (pagos.isEmpty) return const SizedBox.shrink();
        return AppCard(
          padding: const EdgeInsets.symmetric(vertical: Espacio.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Espacio.l),
                child: Text('Cobros', style: context.textos.titleSmall),
              ),
              for (final p in pagos) FilaPago(pago: p, mostrarCliente: false),
            ],
          ),
        );
      },
    );
  }
}

class _ProximoService extends StatelessWidget {
  const _ProximoService({required this.orden});
  final Orden orden;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.event_repeat_rounded, color: context.esquema.primary),
          const SizedBox(width: Espacio.s),
          Expanded(child: Text('Próximo service', style: context.textos.titleSmall)),
          if (orden.recordatorioEnviado)
            Etiqueta(texto: 'Avisado', color: context.colores.exito, fondo: context.colores.exitoSuave, icono: Icons.done_rounded, compacta: true),
        ]),
        const SizedBox(height: Espacio.s),
        Text(Formato.capitalizar(describirProximoService(orden))),
        if (orden.clienteTelefono.isNotEmpty) ...[
          const SizedBox(height: Espacio.m),
          OutlinedButton.icon(
            onPressed: () => enviarRecordatorio(context, orden),
            icon: const Icon(Icons.chat_outlined),
            label: Text(orden.recordatorioEnviado ? 'Volver a recordar' : 'Enviar recordatorio'),
          ),
        ],
      ]),
    );
  }
}
