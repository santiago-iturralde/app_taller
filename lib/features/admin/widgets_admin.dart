import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/componentes.dart';
import '../../data/models/negocio.dart';
import '../../data/repositories/admin_repository.dart';

/// Plan + estado de vencimiento, siempre con ícono y texto.
class EtiquetaPlanAdmin extends StatelessWidget {
  const EtiquetaPlanAdmin({super.key, required this.negocio});
  final Negocio negocio;

  @override
  Widget build(BuildContext context) {
    final n = negocio;
    final c = context.colores;
    final dias = n.diasRestantes();
    if (n.vencido) {
      return Etiqueta(texto: '${n.plan.nombre} vencido', color: c.peligro, fondo: c.peligroSuave, icono: Icons.error_outline_rounded, compacta: true);
    }
    if (n.plan == Plan.gratis) {
      return Etiqueta(texto: 'Gratis', color: c.neutro, fondo: c.neutroSuave, compacta: true);
    }
    final vence = dias == null ? '' : ' · ${dias <= 0 ? 'vence hoy' : '$dias d'}';
    if (n.prueba) {
      return Etiqueta(texto: 'Prueba$vence', color: c.info, fondo: c.infoSuave, icono: Icons.rocket_launch_outlined, compacta: true);
    }
    final porVencer = dias != null && dias <= 7;
    return Etiqueta(
      texto: '${n.plan.nombre}$vence',
      color: porVencer ? c.alerta : c.exito,
      fondo: porVencer ? c.alertaSuave : c.exitoSuave,
      icono: porVencer ? Icons.event_outlined : Icons.verified_outlined,
      compacta: true,
    );
  }
}

String _accion(RegistroPlan r) => switch (r.accion) {
      'activar' => 'Activó ${r.planNuevo.nombre}',
      'prueba' => 'Dio prueba',
      'gratis' => 'Pasó a Gratis',
      _ => r.accion,
    };

class HistorialPlanes extends StatelessWidget {
  const HistorialPlanes({super.key, required this.stream, this.mostrarNegocio = false});
  final Stream<List<RegistroPlan>> stream;
  final bool mostrarNegocio;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RegistroPlan>>(
      stream: stream,
      builder: (context, s) {
        if (s.hasError) return EstadoError(error: s.error);
        if (!s.hasData) return const SizedBox(height: 80, child: Cargando());
        if (s.data!.isEmpty) {
          return AppCard(child: Text('Sin movimientos todavía.', style: TextStyle(color: context.esquema.onSurfaceVariant)));
        }
        return AppCard(
          padding: const EdgeInsets.symmetric(vertical: Espacio.s),
          child: Column(children: [
            for (final r in s.data!)
              ListTile(
                leading: const Icon(Icons.history_rounded),
                title: Text([if (mostrarNegocio) r.negocioNombre, _accion(r)].join(' · ')),
                subtitle: Text([
                  if (r.fecha != null) Formato.fechaHora(r.fecha!),
                  if (r.venceNuevo != null) 'vence ${Formato.fecha(r.venceNuevo!)}',
                  if (r.nota.isNotEmpty) r.nota,
                ].join(' · ')),
                trailing: r.monto == null || r.monto == 0
                    ? null
                    : Text(Formato.moneda(r.monto!), style: context.textos.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              ),
          ]),
        );
      },
    );
  }
}
