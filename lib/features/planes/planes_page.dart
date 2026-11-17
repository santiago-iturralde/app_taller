import 'package:flutter/material.dart';

import '../../app/app_info.dart';
import '../../app/sesion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formato.dart';
import '../../core/utils/whatsapp.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/feedback.dart';

class PlanesPage extends StatelessWidget {
  const PlanesPage({super.key});

  Future<void> _contratar(BuildContext context) async {
    final negocio = Sesion.of(context).negocio;
    if (AppInfo.whatsappVentas.isEmpty) {
      mostrarMensaje(context, 'Muy pronto vas a poder contratar el plan PRO desde acá.');
      return;
    }
    await WhatsApp.enviar(
      AppInfo.whatsappVentas,
      'Hola! Quiero activar el plan PRO de ${AppInfo.nombre} para "${negocio.nombre}" (ID ${negocio.id}).',
    );
  }

  @override
  Widget build(BuildContext context) {
    final negocio = Sesion.of(context).negocio;
    final esPro = negocio.esPro;
    return Scaffold(
      appBar: AppBar(title: const Text('Planes')),
      body: ListView(
        padding: const EdgeInsets.all(Espacio.l),
        children: [
          ContenidoCentrado(
            anchoMaximo: 860,
            child: Column(
              children: [
                const SizedBox(height: Espacio.l),
                Text('Elegí el plan para tu negocio', style: context.textos.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: Espacio.s),
                Text(
                  esPro
                      ? 'Tenés el plan PRO activo${negocio.planVence != null ? ' hasta el ${Formato.fecha(negocio.planVence!)}' : ''}. ¡Gracias!'
                      : 'Empezá gratis y pasate a PRO cuando lo necesites.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.esquema.onSurfaceVariant),
                ),
                const SizedBox(height: Espacio.xl),
                GrillaAdaptable(anchoMinimo: 340, espacio: Espacio.l, children: [
                  _Plan(
                    nombre: 'Gratis',
                    precio: r'$0',
                    actual: !esPro,
                    funciones: const [
                      'Clientes y trabajos ilimitados',
                      'Órdenes de trabajo en PDF',
                      'Presupuestos en PDF y por WhatsApp',
                      'Cobros, señas y control de gastos',
                      'Avisos por WhatsApp',
                    ],
                  ),
                  _Plan(
                    nombre: 'PRO',
                    precio: AppInfo.precioPro,
                    periodo: '/ mes',
                    destacado: true,
                    actual: esPro,
                    funciones: const [
                      'Todo lo del plan Gratis',
                      'Reportes y estadísticas mensuales',
                      'Recibos impresos numerados',
                      'Exportación completa a Excel',
                      'Soporte prioritario',
                    ],
                    onContratar: esPro ? null : () => _contratar(context),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Plan extends StatelessWidget {
  const _Plan({
    required this.nombre,
    required this.precio,
    required this.funciones,
    this.periodo = '',
    this.destacado = false,
    this.actual = false,
    this.onContratar,
  });

  final String nombre;
  final String precio;
  final String periodo;
  final List<String> funciones;
  final bool destacado;
  final bool actual;
  final VoidCallback? onContratar;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radios.l),
        side: BorderSide(color: destacado ? context.esquema.primary : c.borde, width: destacado ? 2 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Espacio.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(nombre, style: context.textos.titleLarge),
              const Spacer(),
              if (actual) Etiqueta(texto: 'Tu plan', color: c.exito, fondo: c.exitoSuave, icono: Icons.check_rounded),
            ]),
            const SizedBox(height: Espacio.m),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(precio, style: context.textos.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                if (periodo.isNotEmpty) Text(' $periodo', style: TextStyle(color: context.esquema.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: Espacio.l),
            for (final f in funciones)
              Padding(
                padding: const EdgeInsets.only(bottom: Espacio.s),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 18, color: destacado ? context.esquema.primary : c.neutro),
                    const SizedBox(width: Espacio.s),
                    Expanded(child: Text(f)),
                  ],
                ),
              ),
            if (onContratar != null) ...[
              const SizedBox(height: Espacio.l),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: onContratar, child: const Text('Quiero el plan PRO')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
