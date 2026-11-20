/// Datos del producto. Cambiar acá el nombre comercial o el contacto de
/// ventas impacta en toda la app.
abstract final class AppInfo {
  static const nombre = 'WorkControl';
  static const eslogan = 'La gestión de tu negocio, simple y en un solo lugar.';

  /// Versión de compatibilidad de datos. Si en `configuracion/app_info` el
  /// campo `version` es mayor, la app web pide recargar para no operar con
  /// código viejo.
  static const versionDatos = 5;

  /// WhatsApp de ventas (formato internacional, sin +). Si está vacío, el
  /// botón de contratar PRO muestra "próximamente".
  static const whatsappVentas = '5492284203790';

  /// Precios que se muestran en la pantalla de planes (los cobrás vos).
  static const precioBasico = r'$ 15.000';
  static const precioPro = r'$ 30.000';

  /// Días de prueba gratis del plan PRO para negocios nuevos (máximo 16:
  /// lo limitan las reglas de Firestore).
  static const diasPrueba = 10;

  /// Facturación electrónica ARCA. Necesita el backend publicado (ver
  /// docs/PUBLICAR.md, Parte B): mientras esté en `false` se ocultan las
  /// facturas y el plan Básico la muestra como "próximamente".
  static const facturacionDisponible = true;

  /// Dirección del backend propio (servidor HTTP de functions/, en Render).
  /// Vacío = usar las Cloud Functions de Firebase (requieren plan Blaze).
  static const urlServidor = 'https://workcontrol-arca.onrender.com';

  /// Dirección pública de la app web (para los mensajes de invitación).
  /// En la versión web se usa la dirección actual del navegador.
  static const urlWeb = '';

  /// Descarga de la app de Android: siempre la última versión publicada en
  /// GitHub Releases del repositorio público de descargas (Firebase Hosting
  /// gratis no permite APKs). El aviso de versión nueva la ofrece en el celular.
  static const urlApk = 'https://github.com/santiago-iturralde/workcontrol-descargas/releases/latest/download/workcontrol.apk';
}
