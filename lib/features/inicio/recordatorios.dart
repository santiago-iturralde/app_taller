import 'package:flutter/material.dart';

import '../../app/sesion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formato.dart';
import '../../core/utils/whatsapp.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/feedback.dart';
import '../../data/models/negocio.dart';
import '../../data/models/orden.dart';
import '../trabajos/orden_detalle_page.dart';

/// Días de anticipación con que se muestran los recordatorios.
const kDiasAnticipacionRecordatorio = 15;

/// "el 15/03/2027 o a los 85.000 km"
String describirProximoService(Orden o) {
  final partes = [
    if (o.proximoServiceFecha != null) 'el ${Formato.fecha(o.proximoServiceFecha!)}',
    if (o.proximoServiceKm != null) 'a los ${Formato.cantidad(o.proximoServiceKm!)} km',
  ];
  return partes.join(' o ');
}

/// Abre WhatsApp con el recordatorio y lo marca como enviado.
Future<void> enviarRecordatorio(BuildContext context, Orden o) async {
  final sesion = Sesion.of(context);
  if (o.clienteTelefono.isEmpty) {
    mostrarMensaje(context, 'El cliente no tiene teléfono cargado', error: true);
    return;
  }
  final mensaje = WhatsApp.aplicarPlantilla(sesion.negocio.plantilla(PlantillasMensaje.recordatorio), {
    'cliente': o.clienteNombre.split(' ').first,
    'equipo': o.equipo.descripcion,
    'numero': Formato.numeroComprobante(o.numero),
    'proximo': describirProximoService(o),
    'negocio': sesion.negocio.nombre,
  });
  final ok = await WhatsApp.enviar(o.clienteTelefono, mensaje);
  if (!context.mounted) return;
  if (!ok) {
    mostrarMensaje(context, 'El teléfono no parece válido para WhatsApp', error: true);
    return;
  }
  await ejecutar(context, () => sesion.ordenes.marcarRecordatorio(o.id));
}

/// Lista de services a recordar (vencidos o dentro de los próximos días).
/// No se muestra si no hay ninguno.
class SeccionRecordatorios extends StatelessWidget {
  const SeccionRecordatorios({super.key});

  @override
  Widget build(BuildContext context) {
    final hasta = DateTime.now().add(const Duration(days: kDiasAnticipacionRecordatorio));
    return StreamBuilder<List<Orden>>(
      stream: Sesion.of(context).ordenes.recordatoriosPendientes(DateTime(hasta.year, hasta.month, hasta.day, 23, 59)),
      builder: (context, s) {
        final lista = s.data ?? const <Orden>[];
        if (lista.isEmpty) return const SizedBox.shrink();
        final hoy = DateTime.now();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Seccion('Recordatorios de service (${lista.length})'),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: Espacio.s),
            child: Column(children: [
              for (final o in lista.take(8))
                ListTile(
                  leading: IconoTile(
                    Icons.notifications_active_outlined,
                    tamanio: 38,
                    color: o.proximoServiceFecha!.isBefore(hoy) ? context.colores.alerta : context.colores.info,
                    fondo: o.proximoServiceFecha!.isBefore(hoy) ? context.colores.alertaSuave : context.colores.infoSuave,
                  ),
                  title: Text('${o.clienteNombre} · ${o.equipo.descripcion}', maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${o.proximoServiceFecha!.isBefore(hoy) ? 'Venció' : 'Vence'} ${describirProximoService(o)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => abrirPagina(context, OrdenDetallePage(ordenId: o.id)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (o.clienteTelefono.isNotEmpty)
                      IconButton.filledTonal(
                        tooltip: 'Enviar recordatorio por WhatsApp',
                        icon: const Icon(Icons.chat_outlined, size: 20),
                        onPressed: () => enviarRecordatorio(context, o),
                      ),
                    IconButton(
                      tooltip: 'Marcar como avisado',
                      icon: const Icon(Icons.done_rounded),
                      onPressed: () => ejecutar(
                        context,
                        () => Sesion.of(context).ordenes.marcarRecordatorio(o.id),
                        exito: 'Recordatorio marcado como avisado',
                      ),
                    ),
                  ]),
                ),
            ]),
          ),
        ]);
      },
    );
  }
}
