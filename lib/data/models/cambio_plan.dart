import 'dart:math' as math;

import 'negocio.dart';

/// Resultado de un cambio de plan hecho por el administrador de la
/// plataforma. Lógica pura: la usa [AdminRepository] y tiene tests.
class CambioPlan {
  const CambioPlan({required this.accion, required this.plan, required this.vence, required this.prueba});

  /// `activar`, `prueba` o `gratis` (queda en la auditoría).
  final String accion;
  final Plan plan;
  final DateTime? vence;
  final bool prueba;

  static const maxMeses = 36;
  static const maxDiasPrueba = 90;

  /// Activa o renueva un plan pago. Si se renueva el mismo plan antes de
  /// que venza, los meses se suman al vencimiento actual (no se pierde lo
  /// pagado).
  factory CambioPlan.activar(Negocio actual, Plan plan, int meses, {DateTime? ahora}) {
    if (plan == Plan.gratis) throw ArgumentError('Elegí un plan pago.');
    if (meses < 1 || meses > maxMeses) throw ArgumentError('Cantidad de meses inválida.');
    final hoy = ahora ?? DateTime.now();
    final vence = actual.planVence;
    final vigente = vence != null && vence.isAfter(hoy) && actual.plan == plan;
    return CambioPlan(accion: 'activar', plan: plan, vence: sumarMeses(vigente ? vence : hoy, meses), prueba: false);
  }

  /// Prueba del plan PRO por [dias] desde hoy.
  factory CambioPlan.prueba(int dias, {DateTime? ahora}) {
    if (dias < 1 || dias > maxDiasPrueba) throw ArgumentError('Cantidad de días inválida.');
    return CambioPlan(
      accion: 'prueba',
      plan: Plan.pro,
      vence: (ahora ?? DateTime.now()).add(Duration(days: dias)),
      prueba: true,
    );
  }

  const CambioPlan.gratis() : this(accion: 'gratis', plan: Plan.gratis, vence: null, prueba: false);
}

/// Suma meses respetando fin de mes (31/01 + 1 mes = 28 o 29/02).
DateTime sumarMeses(DateTime d, int meses) {
  final total = d.month - 1 + meses;
  final anio = d.year + total ~/ 12;
  final mes = total % 12 + 1;
  final ultimo = DateTime(anio, mes + 1, 0).day;
  return DateTime(anio, mes, math.min(d.day, ultimo), d.hour, d.minute, d.second);
}
