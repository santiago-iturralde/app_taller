import 'comunes.dart';
import 'rubro.dart';

enum Plan { gratis, pro }

/// Funciones reservadas al plan PRO. Centralizado acá para que cambiar
/// qué es pago y qué no sea tocar una sola línea.
enum FuncionPro {
  reportes('Reportes y estadísticas'),
  recibosPdf('Recibos impresos'),
  exportarExcel('Exportar a Excel');

  const FuncionPro(this.nombre);
  final String nombre;
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

  bool get puedeAdministrar => this != empleado;
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
  final Plan plan;
  final DateTime? planVence;
  final Map<String, String> plantillas;
  final bool tieneLogo;

  Rubro get rubro => Rubro.porId(rubroId);

  bool get esPro => plan == Plan.pro && (planVence == null || planVence!.isAfter(DateTime.now()));

  bool permite(FuncionPro funcion) => esPro;

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
        plan: m['plan'] == 'pro' ? Plan.pro : Plan.gratis,
        planVence: leerFecha(m['planVence']),
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
        plantillas: plantillas ?? this.plantillas,
        tieneLogo: tieneLogo,
      );
}
