import 'package:flutter/material.dart';

import '../../app/sesion.dart';
import '../../core/pdf/documentos_pdf.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/feedback.dart';
import '../../data/models/fiscal.dart';
import '../../data/models/negocio.dart';
import '../trabajos/orden_detalle_page.dart';

/// Etiqueta del estado de un comprobante.
class EtiquetaFactura extends StatelessWidget {
  const EtiquetaFactura(this.f, {super.key, this.compacta = false});
  final Factura f;
  final bool compacta;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    if (f.anulada) return Etiqueta(texto: 'Anulada', color: c.neutro, fondo: c.neutroSuave, icono: Icons.block_rounded, compacta: compacta);
    return switch (f.estado) {
      EstadoFactura.autorizada => Etiqueta(texto: 'Autorizada', color: c.exito, fondo: c.exitoSuave, icono: Icons.verified_outlined, compacta: compacta),
      EstadoFactura.procesando => Etiqueta(texto: 'Procesando', color: c.info, fondo: c.infoSuave, icono: Icons.sync_rounded, compacta: compacta),
      EstadoFactura.rechazada => Etiqueta(texto: 'Rechazada', color: c.peligro, fondo: c.peligroSuave, icono: Icons.error_outline_rounded, compacta: compacta),
      EstadoFactura.incierta => Etiqueta(texto: 'Sin confirmar', color: c.alerta, fondo: c.alertaSuave, icono: Icons.help_outline_rounded, compacta: compacta),
    };
  }
}

Future<void> imprimirFactura(BuildContext context, Factura f) => DocumentosPdf.abrir(
      context,
      nombreArchivo: '${f.nombreTipo.replaceAll(' ', '_')}_${f.numeroCompleto}.pdf',
      generar: (pdf) => pdf.factura(f),
    );

class FacturaDetallePage extends StatelessWidget {
  const FacturaDetallePage({super.key, required this.facturaId});
  final String facturaId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Factura?>(
      stream: Sesion.of(context).facturacion.observar(facturaId),
      builder: (context, s) {
        if (s.hasError) return Scaffold(appBar: AppBar(), body: EstadoError(error: s.error));
        if (!s.hasData) return Scaffold(appBar: AppBar(), body: const Cargando());
        final f = s.data;
        if (f == null) return Scaffold(appBar: AppBar(), body: const EstadoVacio(icono: Icons.search_off_rounded, titulo: 'La factura no existe'));
        return _Detalle(f: f);
      },
    );
  }
}

class _Detalle extends StatelessWidget {
  const _Detalle({required this.f});
  final Factura f;

  Future<void> _anular(BuildContext context) async {
    final ok = await confirmar(
      context,
      titulo: 'Anular ${f.nombreTipo}',
      mensaje: 'Se emitirá una nota de crédito ${f.letra} por ${Formato.moneda(f.total)} que anula esta factura ante ARCA. '
          'Después vas a poder volver a facturar el trabajo o la venta.',
      confirmar: 'Emitir nota de crédito',
      peligroso: true,
    );
    if (!ok || !context.mounted) return;
    await ejecutar(context, () => Sesion.of(context).facturacion.anular(f.id), exito: 'Nota de crédito autorizada');
  }

  @override
  Widget build(BuildContext context) {
    final sesion = Sesion.of(context);
    final secundario = TextStyle(color: context.esquema.onSurfaceVariant);
    final puedeAnular = f.estado == EstadoFactura.autorizada &&
        !f.esNotaCredito &&
        !f.anulada &&
        f.notaCreditoId == null &&
        sesion.puede(Permiso.eliminarRegistros);

    return Scaffold(
      appBar: AppBar(
        title: Text(f.nombreTipo),
        actions: [
          if (f.estado == EstadoFactura.autorizada)
            IconButton(tooltip: 'PDF', icon: const Icon(Icons.picture_as_pdf_outlined), onPressed: () => imprimirFactura(context, f)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(Espacio.l),
        children: [
          ContenidoCentrado(
            anchoMaximo: 760,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              AppCard(
                padding: const EdgeInsets.all(Espacio.xl),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(border: Border.all(color: context.esquema.onSurface, width: 2), borderRadius: BorderRadius.circular(Radios.s)),
                      child: Text(f.letra, style: context.textos.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(width: Espacio.l),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${f.nombreTipo} N° ${f.numeroCompleto}', style: context.textos.titleMedium),
                        Text(f.fecha != null ? Formato.fecha(f.fecha!) : 'Sin fecha', style: secundario),
                      ]),
                    ),
                    EtiquetaFactura(f),
                  ]),
                  if (f.ambiente == AmbienteArca.homologacion) ...[
                    const SizedBox(height: Espacio.m),
                    Etiqueta(
                      texto: 'Comprobante de prueba: sin validez fiscal',
                      color: context.colores.alerta,
                      fondo: context.colores.alertaSuave,
                      icono: Icons.science_outlined,
                    ),
                  ],
                  if (f.mensaje != null) ...[
                    const SizedBox(height: Espacio.m),
                    Text(f.mensaje!, style: TextStyle(color: f.estado == EstadoFactura.rechazada ? context.colores.peligro : null)),
                  ],
                  if (f.cae != null) ...[
                    const SizedBox(height: Espacio.l),
                    Wrap(spacing: Espacio.xl, runSpacing: Espacio.s, children: [
                      _Dato('CAE', f.cae!),
                      if (f.caeVence != null) _Dato('Vto. CAE', Formato.fecha(f.caeVence!)),
                      if (f.asociada != null) _Dato('Anula a', f.asociada!),
                    ]),
                  ],
                  const SizedBox(height: Espacio.l),
                  Wrap(spacing: Espacio.s, runSpacing: Espacio.s, children: [
                    if (f.estado == EstadoFactura.autorizada)
                      FilledButton.icon(onPressed: () => imprimirFactura(context, f), icon: const Icon(Icons.print_outlined), label: const Text('Imprimir / compartir')),
                    if (f.estado == EstadoFactura.incierta)
                      FilledButton.icon(
                        onPressed: () => ejecutar(context, () => sesion.facturacion.reintentar(f.id), exito: 'Comprobante verificado'),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Verificar con ARCA'),
                      ),
                    if (f.origenTipo == 'orden' && f.origenId.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () => abrirPagina(context, OrdenDetallePage(ordenId: f.origenId)),
                        icon: const Icon(Icons.build_outlined),
                        label: Text('Trabajo N° ${Formato.numeroComprobante(f.origenNumero ?? 0)}'),
                      ),
                    if (f.notaCreditoId != null)
                      OutlinedButton.icon(
                        onPressed: () => abrirPagina(context, FacturaDetallePage(facturaId: f.notaCreditoId!)),
                        icon: const Icon(Icons.receipt_long_outlined),
                        label: const Text('Ver nota de crédito'),
                      ),
                    if (puedeAnular)
                      TextButton.icon(onPressed: () => _anular(context), icon: const Icon(Icons.block_rounded), label: const Text('Anular con nota de crédito')),
                  ]),
                ]),
              ),
              const SizedBox(height: Espacio.m),
              AppCard(
                padding: const EdgeInsets.all(Espacio.xl),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(f.receptorNombre, style: context.textos.titleSmall),
                  Text('${f.documentoReceptor} · ${f.receptorCondicion.etiqueta}', style: secundario),
                  const Divider(height: Espacio.xl),
                  for (final i in f.items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        Expanded(child: Text(i.cantidad == 1 ? i.descripcion : '${Formato.cantidad(i.cantidad)} × ${i.descripcion}')),
                        Text(Formato.moneda(i.subtotal)),
                      ]),
                    ),
                  const Divider(height: Espacio.xl),
                  if (f.discriminaIva) ...[
                    FilaDato('Neto gravado', Formato.moneda(f.neto)),
                    FilaDato('IVA ${Formato.cantidad(f.alicuota ?? 0)}%', Formato.moneda(f.iva)),
                  ],
                  FilaDato('Total', Formato.moneda(f.total), destacado: true),
                ]),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.etiqueta, this.valor);
  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(etiqueta, style: context.textos.labelSmall?.copyWith(color: context.esquema.onSurfaceVariant)),
        SelectableText(valor, style: const TextStyle(fontWeight: FontWeight.w600)),
      ]);
}
