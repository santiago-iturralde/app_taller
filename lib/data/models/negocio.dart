import 'comunes.dart';
import 'rubro.dart';

/// Planes comerciales, de menor a mayor.
enum Plan {
  gratis('free', 'Gratis'),
  basico('basico', 'Básico'),
  pro('pro', 'PRO');

  const Plan(this.valor, this.nombre);
  final String valor;
  final String nombre;

  static Plan desde(String? v) => values.firstWhere((p) => p.valor == v, orElse: () => gratis);

  bool incluye(FuncionPro f) => index >= f.planMinimo.index;
}

/// Funciones pagas y el plan mínimo que las incluye. Centralizado acá: para
/// cambiar qué incluye cada plan se toca una sola línea. (El servidor y las
/// reglas aplican las mismas condiciones: facturación con plan pago,
/// equipo con PRO.)
enum FuncionPro {
  recibosPdf('Recibos impresos', Plan.basico),
  exportarExcel('Exportar a Excel', Plan.basico),
  facturacion('Facturación electrónica ARCA', Plan.basico),
  reportes('Reportes y estadísticas', Plan.pro),
  equipo('Trabajar en equipo', Plan.pro);

  const FuncionPro(this.nombre, this.planMinimo);
  final String nombre;
  final Plan planMinimo;
}

enum RolMiembro {
  duenio('Dueño'),
  admin('Administrador'),
  empleado('Empleado');

  const RolMiembro(this.etiqueta);
  final String etiqueta;

  static RolMiembro desde(String? v) => switch (v) {
        'owner' => duenio,
        'admin' => admin,
        _ => empleado,
      };

  String get valor => switch (this) {
        duenio => 'owner',
        admin => 'admin',
        empleado => 'empleado',
      };

  String get descripcion => switch (this) {
        duenio => 'Control total del negocio.',
        admin => 'Todo, salvo gestionar administradores y el plan.',
        empleado => 'Trabaja el día a día. No ve gastos ni reportes, no borra ni anula cobros.',
      };

  bool get puedeAdministrar => this != empleado;

  bool puede(Permiso p) => switch (p) {
        Permiso.invitarAdministradores || Permiso.cambiarRoles => this == duenio,
        _ => this != empleado,
      };
}

/// Acciones restringidas por rol. Las reglas de Firestore aplican las
/// mismas restricciones del lado del servidor; esto sólo adapta la UI.
enum Permiso {
  verReportes,
  verGastos,
  anularCobros,
  eliminarRegistros,
  editarCatalogo,
  ajustarStock,
  editarNegocio,
  gestionarEquipo,
  invitarAdministradores,
  cambiarRoles,
  exportar,
  verTotalesCaja,
}

/// Plantillas de mensajes de WhatsApp editables por cada negocio.
abstract final class PlantillasMensaje {
  static const listo = 'listo';
  static const recibido = 'recibido';
  static const presupuesto = 'presupuesto';
  static const recordatorio = 'recordatorio';

  static const porDefecto = {
    recibido: 'Hola {cliente}! Te confirmamos que recibimos tu {equipo} en {negocio}. '
        'Tu número de orden es {numero}. Te avisamos cuando esté listo.',
    listo: 'Hola {cliente}! Tu {equipo} ya está listo para retirar en {negocio}. '
        'Total: {total}. Saldo a pagar: {saldo}. ¡Te esperamos!',
    presupuesto: 'Hola {cliente}! Te pasamos el presupuesto N° {numero} de {negocio} por {total}. '
        'Cualquier consulta, escribinos.',
    recordatorio: 'Hola {cliente}! Te escribimos de {negocio}: a tu {equipo} le toca el próximo service {proximo}. '
        '¿Querés que coordinemos un turno?',
  };

  static const variables = {
    '{cliente}': 'Nombre del cliente',
    '{equipo}': 'Equipo o vehículo',
    '{numero}': 'Número de orden o presupuesto',
    '{total}': 'Importe total',
    '{saldo}': 'Saldo pendiente',
    '{negocio}': 'Nombre de tu negocio',
    '{proximo}': 'Fecha o km del próximo service',
  };

  static const etiquetas = {
    recibido: 'Al recibir un trabajo',
    listo: 'Trabajo listo para retirar',
    presupuesto: 'Envío de presupuesto',
    recordatorio: 'Recordatorio de service',
  };
}

class Negocio {
  const Negocio({
    required this.id,
    required this.nombre,
    required this.rubroId,
    required this.ownerUid,
    this.direccion = '',
    this.telefono = '',
    this.email = '',
    this.cuit = '',
    this.plan = Plan.gratis,
    this.planVence,
    this.prueba = false,
    this.plantillas = const {},
    this.tieneLogo = false,
  });

  final String id;
  final String nombre;
  final String rubroId;
  final String ownerUid;
  final String direccion;
  final String telefono;
  final String email;
  final String cuit;
  /// Plan contratado (puede estar vencido: ver [planEfectivo]).
  final Plan plan;
  final DateTime? planVence;

  /// `true` durante el período de prueba gratuito.
  final bool prueba;
  final Map<String, String> plantillas;
  final bool tieneLogo;

  Rubro get rubro => Rubro.porId(rubroId);

  /// `true` si tenía un plan pago y ya venció.
  bool get vencido => plan != Plan.gratis && planVence != null && planVence!.isBefore(DateTime.now());

  /// Plan con el que funciona hoy: si el plan pago venció, queda en Gratis
  /// (sin perder datos).
  Plan get planEfectivo => vencido ? Plan.gratis : plan;

  bool get esPro => planEfectivo == Plan.pro;

  bool permite(FuncionPro funcion) => planEfectivo.incluye(funcion);

  /// Días que faltan para el vencimiento (0 = vence hoy), o null si no vence.
  int? diasRestantes([DateTime? ahora]) {
    if (planVence == null || plan == Plan.gratis) return null;
    final hoy = ahora ?? DateTime.now();
    final d = DateTime(planVence!.year, planVence!.month, planVence!.day);
    return d.difference(DateTime(hoy.year, hoy.month, hoy.day)).inDays;
  }

  String plantilla(String clave) {
    final propia = plantillas[clave];
    return (propia != null && propia.trim().isNotEmpty) ? propia : PlantillasMensaje.porDefecto[clave] ?? '';
  }

  factory Negocio.fromMap(String id, Map<String, dynamic> m) => Negocio(
        id: id,
        nombre: leerTexto(m['nombre']),
        rubroId: leerTexto(m['rubro']),
        ownerUid: leerTexto(m['ownerUid']),
        direccion: leerTexto(m['direccion']),
        telefono: leerTexto(m['telefono']),
        email: leerTexto(m['email']),
        cuit: leerTexto(m['cuit']),
        plan: Plan.desde(m['plan'] as String?),
        planVence: leerFecha(m['planVence']),
        prueba: m['prueba'] == true,
        plantillas: (m['plantillas'] is Map)
            ? Map<String, dynamic>.from(m['plantillas'] as Map).map((k, v) => MapEntry(k, v.toString()))
            : const {},
        tieneLogo: m['tieneLogo'] == true,
      );

  /// Campos que el negocio puede editar. `plan`, `planVence` y `ownerUid`
  /// quedan fuera a propósito: sólo los modifica el servidor.
  Map<String, dynamic> datosEditables() => {
        'nombre': nombre,
        'rubro': rubroId,
        'direccion': direccion,
        'telefono': telefono,
        'email': email,
        'cuit': cuit,
        'plantillas': plantillas,
      };

  Negocio copyWith({
    String? nombre,
    String? rubroId,
    String? direccion,
    String? telefono,
    String? email,
    String? cuit,
    Map<String, String>? plantillas,
  }) =>
      Negocio(
        id: id,
        nombre: nombre ?? this.nombre,
        rubroId: rubroId ?? this.rubroId,
        ownerUid: ownerUid,
        direccion: direccion ?? this.direccion,
        telefono: telefono ?? this.telefono,
        email: email ?? this.email,
        cuit: cuit ?? this.cuit,
        plan: plan,
        planVence: planVence,
        prueba: prueba,
        plantillas: plantillas ?? this.plantillas,
        tieneLogo: tieneLogo,
      );
}
