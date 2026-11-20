import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../app/app_info.dart';

/// Acceso al backend (facturación ARCA).
///
/// El backend habla el protocolo "callable" de Firebase y puede correr en
/// dos lugares: en un servidor propio ([AppInfo.urlServidor], p. ej. Render,
/// sin plan Blaze) o como Cloud Functions. En ambos casos se envía el token
/// de sesión del usuario y el servidor lo verifica.
abstract final class Funciones {
  /// Misma región que las Cloud Functions (functions/src/config.ts).
  static const region = 'southamerica-east1';

  static const _emuladores = bool.fromEnvironment('EMULADORES');

  static FirebaseFunctions get instancia => FirebaseFunctions.instanceFor(region: region);

  static bool get _usaServidorPropio => AppInfo.urlServidor.isNotEmpty && !_emuladores;

  static HttpsCallable _funcion(String nombre, Duration timeout) {
    final opciones = HttpsCallableOptions(timeout: timeout);
    return _usaServidorPropio
        ? instancia.httpsCallableFromUrl('${AppInfo.urlServidor}/$nombre', options: opciones)
        : instancia.httpsCallable(nombre, options: opciones);
  }

  /// Llama a una acción del backend y devuelve su respuesta como mapa.
  /// El tiempo de espera contempla que el servidor gratuito esté dormido.
  static Future<Map<String, dynamic>> llamar(String nombre, Map<String, dynamic> datos) async {
    final r = await _funcion(nombre, const Duration(seconds: 150)).call<Object?>(datos);
    final data = r.data;
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  static DateTime? _ultimoDespertar;

  /// El hosting gratuito duerme el servidor tras unos minutos sin uso y
  /// tarda en arrancar. Se llama al entrar a facturar para que, cuando el
  /// usuario confirme, ya esté despierto. No espera ni falla.
  static void despertar() {
    if (!_usaServidorPropio) return;
    final ahora = DateTime.now();
    if (_ultimoDespertar != null && ahora.difference(_ultimoDespertar!) < const Duration(minutes: 5)) return;
    _ultimoDespertar = ahora;
    _funcion('despertar', const Duration(seconds: 90)).call<Object?>().then(
          (_) {},
          onError: (Object e) => debugPrint('No se pudo despertar el servidor: $e'),
        );
  }
}
