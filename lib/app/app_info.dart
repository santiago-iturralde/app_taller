/// Datos del producto. Cambiar acá el nombre comercial o el contacto de
/// ventas impacta en toda la app.
abstract final class AppInfo {
  static const nombre = 'WorkControl';
  static const eslogan = 'La gestión de tu taller, simple y en un solo lugar.';

  /// Versión de compatibilidad de datos. Si en `configuracion/app_info` el
  /// campo `version` es mayor, la app web pide recargar para no operar con
  /// código viejo.
  static const versionDatos = 4;

  /// WhatsApp de ventas (formato internacional, sin +). Si está vacío, el
  /// botón de contratar PRO muestra "próximamente".
  static const whatsappVentas = '';

  /// Precios que se muestran en la pantalla de planes (los cobrás vos).
  static const precioBasico = r'$ 15.000';
  static const precioPro = r'$ 30.000';

  /// Días de prueba gratis del plan PRO para negocios nuevos (máximo 16:
  /// lo limitan las reglas de Firestore).
  static const diasPrueba = 15;

  /// Dirección pública de la app web (para los mensajes de invitación).
  /// En la versión web se usa la dirección actual del navegador.
  static const urlWeb = '';
}
