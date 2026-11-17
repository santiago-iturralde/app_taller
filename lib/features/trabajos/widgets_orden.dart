import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/componentes.dart';
import '../../data/models/orden.dart';

({Color color, Color fondo}) coloresEstado(BuildContext context, EstadoOrden e) {
  final c = context.colores;
  return switch (e) {
    EstadoOrden.recibido => (color: c.neutro, fondo: c.neutroSuave),
    EstadoOrden.enProceso => (color: c.info, fondo: c.infoSuave),
    EstadoOrden.esperandoRepuesto => (color: c.alerta, fondo: c.alertaSuave),
    EstadoOrden.listo => (color: c.exito, fondo: c.exitoSuave),
    EstadoOrden.entregado => (color: c.neutro, fondo: c.neutroSuave),
    EstadoOrden.cancelado => (color: c.peligro, fondo: c.peligroSuave),
  };
}

class EtiquetaEstado extends StatelessWidget {
  const EtiquetaEstado(this.estado, {super.key, this.compacta = false});
  final EstadoOrden estado;
  final bool compacta;

  @override
  Widget build(BuildContext context) {
    final c = coloresEstado(context, estado);
    return Etiqueta(texto: estado.etiqueta, color: c.color, fondo: c.fondo, icono: estado.icono, compacta: compacta);
  }
}

class EtiquetaPago extends StatelessWidget {
  const EtiquetaPago(this.orden, {super.key, this.compacta = false});
  final Orden orden;
  final bool compacta;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    if (orden.estado == EstadoOrden.cancelado) return const SizedBox.shrink();
    if (orden.sinPresupuestar) {
      return Etiqueta(texto: 'A presupuestar', color: c.neutro, fondo: c.neutroSuave, icono: Icons.edit_note_rounded, compacta: compacta);
    }
    if (orden.pagadoCompleto) {
      return Etiqueta(texto: 'Pagado', color: c.exito, fondo: c.exitoSuave, icono: Icons.done_all_rounded, compacta: compacta);
    }
    return Etiqueta(
      texto: orden.pagado > 0 ? 'Debe ${Formato.moneda(orden.saldo)}' : 'Sin cobrar',
      color: c.peligro,
      fondo: c.peligroSuave,
      icono: Icons.payments_outlined,
      compacta: compacta,
    );
  }
}

/// Fila de trabajo para listas.
class TarjetaOrden extends StatelessWidget {
  const TarjetaOrden({super.key, required this.orden, required this.onTap, this.mostrarCliente = true, this.accion});

  final Orden orden;
  final VoidCallback onTap;
  final bool mostrarCliente;

  /// Acción rápida opcional a la derecha (por ejemplo, avisar por WhatsApp).
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final o = orden;
    final secundario = context.textos.bodySmall?.copyWith(color: context.esquema.onSurfaceVariant);
    final c = coloresEstado(context, o.estado);
    final subtitulo = [
      if (mostrarCliente) o.clienteNombre,
      if (o.equipo.identificador.isNotEmpty) o.equipo.identificador,
    ].join(' · ');

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(Espacio.l),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconoTile(o.estado.icono, color: c.color, fondo: c.fondo, tamanio: 42),
          const SizedBox(width: Espacio.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        o.equipo.descripcion.isEmpty ? 'Trabajo sin descripción' : o.equipo.descripcion,
                        style: context.textos.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: Espacio.s),
                    Text(
                      o.sinPresupuestar ? '—' : Formato.moneda(o.total),
                      style: context.textos.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                if (subtitulo.isNotEmpty)
                  Text(subtitulo, style: secundario, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (o.problema.isNotEmpty)
                  Text(o.problema, style: secundario, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: Espacio.s),
                Wrap(
                  spacing: Espacio.s,
                  runSpacing: Espacio.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    EtiquetaEstado(o.estado, compacta: true),
                    EtiquetaPago(o, compacta: true),
                    if (o.atrasada)
                      Etiqueta(
                        texto: 'Atrasado',
                        color: context.colores.alerta,
                        fondo: context.colores.alertaSuave,
                        icono: Icons.schedule_rounded,
                        compacta: true,
                      ),
                    Text('N° ${Formato.numeroComprobante(o.numero)} · ${Formato.relativo(o.fechaIngreso)}', style: secundario),
                  ],
                ),
              ],
            ),
          ),
          if (accion != null) ...[const SizedBox(width: Espacio.s), accion!],
        ],
      ),
    );
  }
}
