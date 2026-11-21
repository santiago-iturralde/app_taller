import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:taller_reparaciones/core/widgets/feedback.dart';
import 'package:taller_reparaciones/data/funciones.dart';

List<int> _json(Object o) => utf8.encode(jsonEncode(o));

void main() {
  group('Respuesta del servidor (protocolo callable)', () {
    test('devuelve el resultado', () {
      expect(Funciones.interpretarRespuesta(200, _json({'result': {'csr': 'x'}})), {'csr': 'x'});
      expect(Funciones.interpretarRespuesta(200, _json({'result': null})), isNull);
    });

    test('convierte los errores con su mensaje (con acentos)', () {
      expect(
        () => Funciones.interpretarRespuesta(412, _json({'error': {'status': 'FAILED_PRECONDITION', 'message': 'Tu plan no incluye facturación.'}})),
        throwsA(isA<ErrorServidor>()
            .having((e) => e.codigo, 'codigo', 'failed-precondition')
            .having((e) => mensajeDeError(e), 'mensaje', 'Tu plan no incluye facturación.')),
      );
      expect(
        () => Funciones.interpretarRespuesta(401, _json({'error': {'status': 'UNAUTHENTICATED', 'message': 'x'}})),
        throwsA(isA<ErrorServidor>().having((e) => mensajeDeError(e), 'mensaje', 'Tu sesión venció. Volvé a ingresar.')),
      );
    });

    test('respuestas inválidas', () {
      expect(() => Funciones.interpretarRespuesta(502, utf8.encode('<html>Bad gateway</html>')),
          throwsA(isA<ErrorServidor>().having((e) => e.codigo, 'codigo', 'internal')));
      expect(() => Funciones.interpretarRespuesta(200, _json({'otra': 1})), throwsA(isA<ErrorServidor>()));
    });
  });
}
