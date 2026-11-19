import 'package:cloud_functions/cloud_functions.dart';

/// Acceso a las Cloud Functions del backend.
abstract final class Funciones {
  /// Misma región que el backend (functions/src/config.ts).
  static const region = 'southamerica-east1';

  static FirebaseFunctions get instancia => FirebaseFunctions.instanceFor(region: region);

  /// Llama a una función y devuelve su respuesta como mapa.
  static Future<Map<String, dynamic>> llamar(String nombre, Map<String, dynamic> datos) async {
    final r = await instancia
        .httpsCallable(nombre, options: HttpsCallableOptions(timeout: const Duration(seconds: 120)))
        .call<Object?>(datos);
    final data = r.data;
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }
}
