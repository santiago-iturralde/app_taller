import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/app_info.dart';
import '../../app/sesion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formato.dart';
import '../../core/utils/whatsapp.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/feedback.dart';
import '../../data/models/negocio.dart';
import 'planes_page.dart';

/// "Plan PRO", "Plan PRO (prueba)", "Plan Gratis"…
String etiquetaPlan(Negocio n) {
  final prueba = n.prueba && !n.vencido ? ' (prueba)' : '';
  return 'Plan ${n.planEfectivo.nombre}$prueba';
}

/// Devuelve `true` si el negocio puede usar [funcion]. Si no, muestra la
/// invitación a mejorar el plan y devuelve `false`.
Future<bool> exigirPro(BuildContext context, FuncionPro funcion) async {
  if (Sesion.of(context).negocio.permite(funcion)) return true;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: IconoTile(Icons.workspace_premium_rounded, color: context.colores.pro, fondo: context.colores.proSuave, tamanio: 56),
      title: Text(funcion.nombre),
      content: Text(
        'Esta función está incluida desde el plan ${funcion.planMinimo.nombre}.',
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Ahora no')),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            abrirPagina(context, const PlanesPage());
          },
          child: const Text('Ver planes'),
        ),
      ],
    ),
  );
  return false;
}

/// Abre WhatsApp con el vendedor para renovar o contratar.
Future<void> contactarVentas(BuildContext context, {String? plan}) async {
  final negocio = Sesion.of(context).negocio;
  if (AppInfo.whatsappVentas.isEmpty) {
    mostrarMensaje(context, 'Contactate con quien te vendió el sistema para renovar tu plan.');
    return;
  }
  await WhatsApp.enviar(
    AppInfo.whatsappVentas,
    'Hola! Quiero ${plan == null ? 'renovar mi plan' : 'contratar el plan $plan'} de ${AppInfo.nombre} '
    'para "${negocio.nombre}" (código ${negocio.id}).',
  );
}

/// Días antes del vencimiento a partir de los que se muestra el aviso.
const kDiasAvisoVencimiento = 7;

enum _TipoAviso { prueba, porVencer, vencido }

/// Aviso de prueba / vencimiento del plan. Se puede ocultar por el día.
class AvisoPlan extends StatefulWidget {
  const AvisoPlan({super.key});

  @override
  State<AvisoPlan> createState() => _AvisoPlanState();
}

class _AvisoPlanState extends State<AvisoPlan> {
  static String _hoy() {
    final d = DateTime.now();
    return '${d.year}-${d.month}-${d.day}';
  }

  String? _ocultadoEl;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => _ocultadoEl = p.getString('avisoPlanOcultado'));
    }).catchError((_) {});
  }

  Future<void> _ocultar() async {
    setState(() => _ocultadoEl = _hoy());
    try {
      (await SharedPreferences.getInstance()).setString('avisoPlanOcultado', _hoy());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final sesion = Sesion.of(context);
    // El aviso de pago le interesa al dueño o a un administrador.
    if (!sesion.puede(Permiso.editarNegocio)) return const SizedBox.shrink();
    final n = sesion.negocio;
    final dias = n.diasRestantes();
    final _TipoAviso? tipo = n.vencido
        ? _TipoAviso.vencido
        : (n.prueba && dias != null)
            ? _TipoAviso.prueba
            : (dias != null && dias <= kDiasAvisoVencimiento)
                ? _TipoAviso.porVencer
                : null;
    // El aviso de plan vencido no se oculta; los otros, por el día.
    if (tipo == null || (tipo != _TipoAviso.vencido && _ocultadoEl == _hoy())) return const SizedBox.shrink();

    final c = context.colores;
    final (color, fondo, icono, texto) = switch (tipo) {
      _TipoAviso.prueba => (
          c.info,
          c.infoSuave,
          Icons.rocket_launch_outlined,
          'Estás probando el plan PRO gratis: ${_quedan(dias!)} (hasta el ${Formato.fecha(n.planVence!)}).',
        ),
      _TipoAviso.porVencer => (
          c.alerta,
          c.alertaSuave,
          Icons.event_outlined,
          'Tu plan ${n.plan.nombre} vence ${dias == 0 ? 'hoy' : 'el ${Formato.fecha(n.planVence!)}'}. Renovalo para no perder funciones.',
        ),
      _TipoAviso.vencido => (
          c.peligro,
          c.peligroSuave,
          Icons.error_outline_rounded,
          'Tu plan ${n.plan.nombre} venció el ${Formato.fecha(n.planVence!)}. Tus datos están a salvo; '
              'renovalo para recuperar las funciones pagas.',
        ),
    };

    return Material(
      color: fondo,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Espacio.l, vertical: Espacio.s),
          child: Row(children: [
            Icon(icono, color: color, size: 20),
            const SizedBox(width: Espacio.m),
            Expanded(child: Text(texto, style: TextStyle(color: context.esquema.onSurface))),
            const SizedBox(width: Espacio.s),
            TextButton(
              onPressed: () => tipo == _TipoAviso.prueba ? abrirPagina(context, const PlanesPage()) : contactarVentas(context),
              child: Text(tipo == _TipoAviso.prueba ? 'Ver planes' : 'Renovar'),
            ),
            if (tipo != _TipoAviso.vencido)
              IconButton(tooltip: 'Ocultar por hoy', icon: const Icon(Icons.close_rounded, size: 18), onPressed: _ocultar),
          ]),
        ),
      ),
    );
  }

  static String _quedan(int dias) => switch (dias) {
        <= 0 => 'termina hoy',
        1 => 'te queda 1 día',
        _ => 'te quedan $dias días',
      };
}
