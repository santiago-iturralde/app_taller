/// Datos del producto. Cambiar acá el nombre comercial o el contacto de
/// ventas impacta en toda la app.
abstract final class AppInfo {
  static const nombre = 'WorkControl';
  static const eslogan = 'La gestión de tu negocio, simple y en un solo lugar.';

  /// Versión de compatibilidad de datos. Si en `configuracion/app_info` el
  /// campo `version` es mayor, la app web pide recargar para no operar con
  /// código viejo.
  static const versionDatos = 4;

  /// WhatsApp de ventas (formato internacional, sin +). Si está vacío, el
  /// botón de contratar PRO muestra "próximamente".
  static const whatsappVentas = '5492284203790';

  /// Precios que se muestran en la pantalla de planes (los cobrás vos).
  static const precioBasico = r'$ 15.000';
  static const precioPro = r'$ 30.000';

  /// Días de prueba gratis del plan PRO para negocios nuevos (máximo 16:
  /// lo limitan las reglas de Firestore).
  static const diasPrueba = 10;

  /// Facturación electrónica ARCA. Necesita el backend (Cloud Functions),
  /// que requiere el plan Blaze de Firebase: mientras esté en `false` se
  /// ocultan las facturas y el plan Básico la muestra como "próximamente".
  /// Para activarla ver docs/PUBLICAR.md (pasos 1, 2 y 4).
  static const facturacionDisponible = false;

  /// Dirección pública de la app web (para los mensajes de invitación).
  /// En la versión web se usa la dirección actual del navegador.
  static const urlWeb = '';

  /// Descarga de la app de Android (se publica junto con la web: ver
  /// docs/PUBLICAR.md). El aviso de versión nueva la ofrece en el celular.
  static const urlApk = 'https://taller-app-admin.web.app/descargas/workcontrol.apk';
}
