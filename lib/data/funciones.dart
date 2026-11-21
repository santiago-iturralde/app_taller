import 'dart:async';
import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../app/app_info.dart';

/// Error devuelto por el backend (o por no poder llegar a él). [codigo] usa
/// los nombres del protocolo callable en minúsculas: `unauthenticated`,
/// `invalid-argument`, `failed-precondition`, `unavailable`, etc.
class ErrorServidor implements Exception {
  const ErrorServidor(this.codigo, this.mensaje);
  final String codigo;
  final String mensaje;

  @override
  String toString() => 'ErrorServidor($codigo): $mensaje';
}

/// Acceso al backend (facturación ARCA).
///
/// El backend habla el protocolo "callable" de Firebase y puede correr en
/// dos lugares: en un servidor propio ([AppInfo.urlServidor], p. ej. Render,
/// sin plan Blaze) o como Cloud Functions. En ambos casos se envía el token
/// de sesión del usuario y el servidor lo verifica.
///
/// Al servidor propio se lo llama con HTTP directo: el plugin cloud_functions
/// no soporta `httpsCallableFromUrl` en la web (falla con "Int64 accessor
/// not supported by dart2js").
abstract final class Funciones {
  /// Misma región que las Cloud Functions (functions/src/config.ts).
  static const region = 'southamerica-east1';

  static const _emuladores = bool.fromEnvironment('EMULADORES');

  /// El servidor gratuito puede estar dormido y tardar en arrancar.
  static const _espera = Duration(seconds: 150);

  static bool get _usaServidorPropio => AppInfo.urlServidor.isNotEmpty && !_emuladores;

  /// Llama a una acción del backend y devuelve su respuesta como mapa.
  static Future<Map<String, dynamic>> llamar(String nombre, Map<String, dynamic> datos) async {
    final data = _usaServidorPropio ? await _llamarServidor(nombre, datos) : await _llamarCloudFunction(nombre, datos);
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  static Future<Object?> _llamarCloudFunction(String nombre, Map<String, dynamic> datos) async {
    final r = await FirebaseFunctions.instanceFor(region: region)
        .httpsCallable(nombre, options: HttpsCallableOptions(timeout: _espera))
        .call<Object?>(datos);
    return r.data;
  }

  static Future<Object?> _llamarServidor(String nombre, Map<String, dynamic> datos, {Duration espera = _espera}) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    final http.Response r;
    try {
      r = await http
          .post(
            Uri.parse('${AppInfo.urlServidor}/$nombre'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'data': datos}),
          )
          .timeout(espera);
    } on TimeoutException {
      throw const ErrorServidor('deadline-exceeded', 'El servidor tardó demasiado en responder. Probá de nuevo.');
    } catch (_) {
      throw const ErrorServidor('unavailable', 'No se pudo conectar con el servidor. Revisá tu internet e intentá de nuevo.');
    }

    return interpretarRespuesta(r.statusCode, r.bodyBytes);
  }

  /// Interpreta la respuesta del protocolo callable: `{"result": ...}` o
  /// `{"error": {"status", "message"}}`.
  @visibleForTesting
  static Object? interpretarRespuesta(int status, List<int> bytes) {
    final Object? cuerpo;
    try {
      cuerpo = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      throw ErrorServidor('internal', 'Respuesta inválida del servidor ($status).');
    }
    if (cuerpo is Map && cuerpo['error'] is Map) {
      final e = cuerpo['error'] as Map;
      final codigo = '${e['status'] ?? 'internal'}'.toLowerCase().replaceAll('_', '-');
      throw ErrorServidor(codigo, '${e['message'] ?? 'Ocurrió un error en el servidor.'}');
    }
    if (status != 200 || cuerpo is! Map || !cuerpo.containsKey('result')) {
      throw ErrorServidor('internal', 'Respuesta inválida del servidor ($status).');
    }
    return cuerpo['result'];
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
    _llamarServidor('despertar', const {}, espera: const Duration(seconds: 90)).then(
      (_) {},
      onError: (Object e) => debugPrint('No se pudo despertar el servidor: $e'),
    );
  }
}
