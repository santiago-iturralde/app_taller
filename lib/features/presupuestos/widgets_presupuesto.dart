import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/componentes.dart';
import '../../data/models/presupuesto.dart';

class EtiquetaPresupuesto extends StatelessWidget {
  const EtiquetaPresupuesto(this.p, {super.key, this.compacta = false});
  final Presupuesto p;
  final bool compacta;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    if (p.vencido) {
      return Etiqueta(texto: 'Vencido', color: c.neutro, fondo: c.neutroSuave, icono: Icons.event_busy_outlined, compacta: compacta);
    }
    final (color, fondo) = switch (p.estado) {
      EstadoPresupuesto.pendiente => (c.alerta, c.alertaSuave),
      EstadoPresupuesto.aprobado => (c.exito, c.exitoSuave),
      EstadoPresupuesto.rechazado => (c.peligro, c.peligroSuave),
    };
    return Etiqueta(texto: p.estado.etiqueta, color: color, fondo: fondo, icono: p.estado.icono, compacta: compacta);
  }
}

class TarjetaPresupuesto extends StatelessWidget {
  const TarjetaPresupuesto({super.key, required this.presupuesto, required this.onTap, this.mostrarCliente = true});
  final Presupuesto presupuesto;
  final VoidCallback onTap;
  final bool mostrarCliente;

  @override
  Widget build(BuildContext context) {
    final p = presupuesto;
    final secundario = context.textos.bodySmall?.copyWith(color: context.esquema.onSurfaceVariant);
    final resumen = p.items.map((i) => i.descripcion).where((d) => d.isNotEmpty).join(', ');
    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IconoTile(Icons.request_quote_outlined, tamanio: 42),
          const SizedBox(width: Espacio.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      mostrarCliente ? p.clienteNombre : (p.equipo.isEmpty ? 'Presupuesto' : p.equipo),
                      style: context.textos.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(Formato.moneda(p.total), style: context.textos.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                ]),
                if (mostrarCliente && p.equipo.isNotEmpty) Text(p.equipo, style: secundario, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (resumen.isNotEmpty) Text(resumen, style: secundario, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: Espacio.s),
                Wrap(
                  spacing: Espacio.s,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    EtiquetaPresupuesto(p, compacta: true),
                    Text('N° ${Formato.numeroComprobante(p.numero)} · ${Formato.fecha(p.fecha)}', style: secundario),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
