import 'package:flutter/material.dart';

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

Future<void> imprimirRecibo(BuildContext context, Pago pago) async {
  if (!await exigirPro(context, FuncionPro.recibosPdf) || !context.mounted) return;
  await DocumentosPdf.abrir(
    context,
    nombreArchivo: nombreArchivoPdf('Recibo', pago.numero, pago.clienteNombre),
    generar: (pdf) => pdf.recibo(pago),
  );
}

Future<void> anularPago(BuildContext context, Pago pago) async {
  final ok = await confirmar(
    context,
    titulo: 'Anular cobro',
    mensaje: 'El recibo N° ${Formato.numeroComprobante(pago.numero)} por ${Formato.moneda(pago.monto)} quedará anulado'
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
      p.medio.etiqueta,
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
        p.concepto.isEmpty ? 'Cobro N° ${Formato.numeroComprobante(p.numero)}' : p.concepto,
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
              _ => null,
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'recibo',
                child: ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: Text('Recibo N° ${Formato.numeroComprobante(p.numero)}'),
                  trailing: Sesion.of(context).negocio.esPro ? null : const DistintivoPro(),
                ),
              ),
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
