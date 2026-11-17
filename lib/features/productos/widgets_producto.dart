import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/componentes.dart';
import '../../data/models/producto.dart';

/// Etiqueta de stock: ícono + texto, nunca sólo color.
class EtiquetaStock extends StatelessWidget {
  const EtiquetaStock(this.p, {super.key, this.compacta = true});
  final Producto p;
  final bool compacta;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    if (!p.controlaStock) {
      return Etiqueta(texto: 'Servicio', color: c.info, fondo: c.infoSuave, icono: Icons.handyman_outlined, compacta: compacta);
    }
    final texto = 'Stock: ${Formato.cantidad(p.stock)}';
    if (p.sinStock) {
      return Etiqueta(texto: texto, color: c.peligro, fondo: c.peligroSuave, icono: Icons.remove_shopping_cart_outlined, compacta: compacta);
    }
    if (p.stockBajo) {
      return Etiqueta(texto: texto, color: c.alerta, fondo: c.alertaSuave, icono: Icons.warning_amber_rounded, compacta: compacta);
    }
    return Etiqueta(texto: texto, color: c.exito, fondo: c.exitoSuave, icono: Icons.check_rounded, compacta: compacta);
  }
}

class FilaProducto extends StatelessWidget {
  const FilaProducto({super.key, required this.producto, required this.onTap});
  final Producto producto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = producto;
    final sub = [p.codigo, p.categoria].where((e) => e.isNotEmpty).join(' · ');
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: Espacio.l, vertical: Espacio.m),
      child: Row(children: [
        IconoTile(p.tipo.icono, tamanio: 40),
        const SizedBox(width: Espacio.m),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.nombre, style: context.textos.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (sub.isNotEmpty)
              Text(sub, style: context.textos.bodySmall?.copyWith(color: context.esquema.onSurfaceVariant), maxLines: 1),
            const SizedBox(height: 4),
            EtiquetaStock(p),
          ]),
        ),
        const SizedBox(width: Espacio.s),
        Text(Formato.moneda(p.precio), style: context.textos.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
