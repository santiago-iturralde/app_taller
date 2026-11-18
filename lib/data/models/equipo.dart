import 'comunes.dart';
import 'negocio.dart';

class Miembro {
  const Miembro({required this.uid, required this.rol, this.email = '', this.desde});

  final String uid;
  final RolMiembro rol;
  final String email;
  final DateTime? desde;

  factory Miembro.fromMap(String uid, Map<String, dynamic> m) => Miembro(
        uid: uid,
        rol: RolMiembro.desde(m['rol'] as String?),
        email: leerTexto(m['email']),
        desde: leerFecha(m['desde']),
      );
}

/// Invitación para sumarse a un negocio. Su ID es determinista
/// (`{negocioId}_{email}`) para que las reglas de seguridad puedan
/// validarla sin consultas.
class Invitacion {
  const Invitacion({
    required this.negocioId,
    required this.negocioNombre,
    required this.email,
    required this.rol,
    required this.vence,
    this.creadoPor = '',
  });

  static const diasDeValidez = 7;

  final String negocioId;
  final String negocioNombre;
  final String email;
  final RolMiembro rol;
  final DateTime vence;
  final String creadoPor;

  String get id => idPara(negocioId, email);
  bool get vencida => vence.isBefore(DateTime.now());

  static String normalizarEmail(String email) => email.trim().toLowerCase();
  static String idPara(String negocioId, String email) => '${negocioId}_${normalizarEmail(email)}';

  static bool emailValido(String email) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalizarEmail(email));

  factory Invitacion.fromMap(Map<String, dynamic> m) => Invitacion(
        negocioId: leerTexto(m['negocioId']),
        negocioNombre: leerTexto(m['negocioNombre']),
        email: leerTexto(m['email']),
        rol: RolMiembro.desde(m['rol'] as String?),
        vence: leerFecha(m['vence']) ?? DateTime.now(),
        creadoPor: leerTexto(m['creadoPor']),
      );

  Map<String, dynamic> toMap() => {
        'negocioId': negocioId,
        'negocioNombre': negocioNombre,
        'email': normalizarEmail(email),
        'rol': rol.valor,
        'creadoPor': creadoPor,
        'vence': vence,
      };
}
