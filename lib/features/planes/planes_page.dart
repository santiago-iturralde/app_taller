import 'package:flutter/material.dart';

import '../../app/app_info.dart';
import '../../app/sesion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/componentes.dart';
import '../../data/models/negocio.dart';
import 'pro.dart';

class PlanesPage extends StatelessWidget {
  const PlanesPage({super.key});

  static const _base = [
    'Clientes, trabajos y presupuestos ilimitados',
    'Órdenes de trabajo y presupuestos en PDF',
    'Productos, stock y ventas de mostrador',
    'Cobros, señas y gastos',
    'Avisos y recordatorios por WhatsApp',
  ];

  @override
  Widget build(BuildContext context) {
    final negocio = Sesion.of(context).negocio;
    final actual = negocio.planEfectivo;
    String? estado;
    if (negocio.vencido) {
      estado = 'Tu plan ${negocio.plan.nombre} venció el ${Formato.fecha(negocio.planVence!)}.';
    } else if (negocio.planVence != null && actual != Plan.gratis) {
      estado = '${etiquetaPlan(negocio)} activo hasta el ${Formato.fecha(negocio.planVence!)}.';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Planes')),
      body: ListView(
        padding: const EdgeInsets.all(Espacio.l),
        children: [
          ContenidoCentrado(
            anchoMaximo: 1040,
            child: Column(children: [
              const SizedBox(height: Espacio.l),
              Text('Elegí el plan para tu negocio', style: context.textos.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: Espacio.s),
              Text(
                estado ?? 'Todos los planes incluyen tus datos seguros en la nube y las actualizaciones.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.esquema.onSurfaceVariant),
              ),
              const SizedBox(height: Espacio.xl),
              GrillaAdaptable(anchoMinimo: 300, espacio: Espacio.l, children: [
                _Plan(plan: Plan.gratis, precio: r'$ 0', actual: actual == Plan.gratis, funciones: _base),
                _Plan(
                  plan: Plan.basico,
                  precio: AppInfo.precioBasico,
                  actual: actual == Plan.basico,
                  funciones: [
                    'Todo lo del plan Gratis',
                    for (final f in FuncionPro.values.where((f) => f.planMinimo == Plan.basico)) f.nombre,
                  ],
                ),
                _Plan(
                  plan: Plan.pro,
                  precio: AppInfo.precioPro,
                  destacado: true,
                  actual: actual == Plan.pro,
                  funciones: [
                    'Todo lo del plan Básico',
                    for (final f in FuncionPro.values.where((f) => f.planMinimo == Plan.pro)) f.nombre,
                    'Soporte prioritario',
                  ],
                ),
              ]),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Plan extends StatelessWidget {
  const _Plan({required this.plan, required this.precio, required this.funciones, this.destacado = false, this.actual = false});

  final Plan plan;
  final String precio;
  final List<String> funciones;
  final bool destacado;
  final bool actual;

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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(plan.nombre, style: context.textos.titleLarge),
            const Spacer(),
            if (actual) Etiqueta(texto: 'Tu plan', color: c.exito, fondo: c.exitoSuave, icono: Icons.check_rounded),
          ]),
          const SizedBox(height: Espacio.m),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(precio, style: context.textos.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
            if (plan != Plan.gratis) Text(' / mes', style: TextStyle(color: context.esquema.onSurfaceVariant)),
          ]),
          const SizedBox(height: Espacio.l),
          for (final f in funciones)
            Padding(
              padding: const EdgeInsets.only(bottom: Espacio.s),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.check_circle_rounded, size: 18, color: destacado ? context.esquema.primary : c.neutro),
                const SizedBox(width: Espacio.s),
                Expanded(child: Text(f)),
              ]),
            ),
          if (plan != Plan.gratis && !actual) ...[
            const SizedBox(height: Espacio.l),
            SizedBox(
              width: double.infinity,
              child: destacado
                  ? FilledButton(onPressed: () => contactarVentas(context, plan: plan.nombre), child: Text('Quiero el plan ${plan.nombre}'))
                  : OutlinedButton(onPressed: () => contactarVentas(context, plan: plan.nombre), child: Text('Quiero el plan ${plan.nombre}')),
            ),
          ],
        ]),
      ),
    );
  }
}
