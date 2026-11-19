import 'package:flutter/material.dart';

import '../../app/app_info.dart';
import '../../app/sesion.dart';
import '../../core/pdf/documentos_pdf.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/feedback.dart';
import '../../data/models/caja.dart';
import '../../data/models/negocio.dart';
import '../planes/pro.dart';
import '../trabajos/orden_detalle_page.dart';
import '../facturacion/factura_detalle_page.dart';
import '../facturacion/facturar.dart';

Future<void> imprimirRecibo(BuildContext context, Pago pago) async {
  if (!await exigirPro(context, FuncionPro.recibosPdf) || !context.mounted) return;
  await DocumentosPdf.abrir(
    context,
    nombreArchivo: nombreArchivoPdf('Recibo', Formato.numeroRecibo(pago.numero, pago.numeroAnterior), pago.clienteNombre),
    generar: (pdf) => pdf.recibo(pago),
  );
}

Future<void> anularPago(BuildContext context, Pago pago) async {
  final ok = await confirmar(
    context,
    titulo: 'Anular cobro',
    mensaje: 'El recibo N° ${Formato.numeroRecibo(pago.numero, pago.numeroAnterior)} por ${Formato.moneda(pago.monto)} quedará anulado'
        '${pago.ordenId != null ? ' y se descontará de lo cobrado en el trabajo' : ''}'
        '${pago.esVenta ? ' y los productos vuelven al stock' : ''}. '
        'El número no se reutiliza.',
    confirmar: 'Anular',
    peligroso: true,
  );
  if (!ok || !context.mounted) return;
  await ejecutar(context, () => Sesion.of(context).caja.anularPago(pago), exito: 'Cobro anulado');
}

/// Fila de un cobro con acciones (recibo, ver trabajo, anular).
class FilaPago extends StatelessWidget {
  const FilaPago({super.key, required this.pago, this.mostrarCliente = true});
  final Pago pago;
  final bool mostrarCliente;

  @override
  Widget build(BuildContext context) {
    final p = pago;
    final tachado = p.anulado ? TextDecoration.lineThrough : null;
    final subtitulo = [
      if (mostrarCliente && p.clienteNombre.isNotEmpty) p.clienteNombre,
      if (p.delSistemaAnterior) 'Sistema anterior' else p.medio.etiqueta,
      Formato.fecha(p.fecha),
    ].join(' · ');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: Espacio.l),
      leading: IconoTile(
        p.esVenta ? Icons.shopping_bag_outlined : p.medio.icono,
        tamanio: 38,
        color: p.anulado ? context.colores.neutro : context.colores.exito,
        fondo: p.anulado ? context.colores.neutroSuave : context.colores.exitoSuave,
      ),
      title: Text(
        p.concepto.isEmpty ? 'Recibo N° ${Formato.numeroRecibo(p.numero, p.numeroAnterior)}' : p.concepto,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(decoration: tachado),
      ),
      subtitle: Text(
        p.anulado ? 'ANULADO · $subtitulo' : subtitulo,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            Formato.moneda(p.monto),
            style: context.textos.titleSmall?.copyWith(fontWeight: FontWeight.w700, decoration: tachado),
          ),
          PopupMenuButton<String>(
            tooltip: 'Opciones',
            onSelected: (v) => switch (v) {
              'recibo' => imprimirRecibo(context, p),
              'trabajo' => abrirPagina(context, OrdenDetallePage(ordenId: p.ordenId!)),
              'anular' => anularPago(context, p),
              'facturar' => facturar(
                  context,
                  origenTipo: 'pago',
                  origenId: p.id,
                  total: p.monto,
                  nombreCliente: p.clienteNombre,
                  clienteId: p.clienteId,
                ),
              'factura' => abrirPagina(context, FacturaDetallePage(facturaId: p.facturaId!)),
              _ => null,
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'recibo',
                child: ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: Text('Recibo N° ${Formato.numeroRecibo(p.numero, p.numeroAnterior)}'),
                  trailing: Sesion.of(context).negocio.permite(FuncionPro.recibosPdf) ? null : const DistintivoPro(),
                ),
              ),
              if (p.facturaId != null)
                const PopupMenuItem(value: 'factura', child: ListTile(leading: Icon(Icons.verified_outlined), title: Text('Ver factura')))
              else if (AppInfo.facturacionDisponible && p.facturable)
                const PopupMenuItem(value: 'facturar', child: ListTile(leading: Icon(Icons.receipt_long_outlined), title: Text('Facturar'))),
              if (p.ordenId != null && mostrarCliente)
                const PopupMenuItem(value: 'trabajo', child: ListTile(leading: Icon(Icons.build_outlined), title: Text('Ver trabajo'))),
              if (!p.anulado && Sesion.of(context).puede(Permiso.anularCobros))
                const PopupMenuItem(value: 'anular', child: ListTile(leading: Icon(Icons.block_rounded), title: Text('Anular cobro'))),
            ],
          ),
        ],
      ),
    );
  }
}
