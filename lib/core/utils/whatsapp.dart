import 'package:url_launcher/url_launcher.dart';

/// Envío de mensajes por WhatsApp usando enlaces `wa.me`.
///
/// El mensaje se abre en el WhatsApp del propio negocio (celular o
/// WhatsApp Web) ya escrito: no requiere servidor, no comparte números
/// entre clientes del sistema y respeta las condiciones de WhatsApp.
abstract final class WhatsApp {
  /// Normaliza un teléfono argentino al formato internacional que espera
  /// WhatsApp (`549` + característica + número, sin el 0 ni el 15).
  ///
  /// Devuelve `null` si no parece un número válido.
  static String? normalizarTelefono(String telefono, {String codigoPais = '54'}) {
    var d = telefono.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('00')) d = d.substring(2);
    if (d.isEmpty) return null;

    if (codigoPais == '54') {
      if (d.startsWith('549')) return d.length >= 12 ? d : null;
      if (d.startsWith('54') && d.length == 12) return '549${d.substring(2)}';
      if (d.startsWith('0')) d = d.substring(1);
      // Celular escrito con 15: característica (2 a 4 dígitos) + 15 + número.
      if (d.length == 12) {
        for (final largoCaracteristica in [2, 3, 4]) {
          if (d.substring(largoCaracteristica, largoCaracteristica + 2) == '15') {
            d = d.substring(0, largoCaracteristica) + d.substring(largoCaracteristica + 2);
            break;
          }
        }
      }
      if (d.length == 10) return '549$d';
      return null;
    }

    return d.startsWith(codigoPais) ? d : '$codigoPais$d';
  }

  static Uri? enlace(String telefono, String mensaje) {
    final numero = normalizarTelefono(telefono);
    if (numero == null) return null;
    return Uri.https('wa.me', '/$numero', {'text': mensaje});
  }

  /// Abre WhatsApp con el mensaje escrito. Devuelve `false` si el teléfono
  /// no es válido o no se pudo abrir.
  static Future<bool> enviar(String telefono, String mensaje) async {
    final uri = enlace(telefono, mensaje);
    if (uri == null) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Abre WhatsApp para elegir a quién mandarle [mensaje].
  static Future<bool> compartir(String mensaje) =>
      launchUrl(Uri.https('wa.me', '/', {'text': mensaje}), mode: LaunchMode.externalApplication);

  /// Reemplaza `{clave}` por su valor. Las claves sin valor quedan vacías.
  static String aplicarPlantilla(String plantilla, Map<String, String> valores) {
    return plantilla.replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) => valores[m.group(1)] ?? '').trim();
  }
}

/// Abre el marcador del teléfono.
Future<bool> llamarPorTelefono(String telefono) {
  final limpio = telefono.replaceAll(RegExp(r'[^\d+]'), '');
  return launchUrl(Uri(scheme: 'tel', path: limpio));
}
