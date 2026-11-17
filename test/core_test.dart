import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:taller_reparaciones/core/utils/busqueda.dart';
import 'package:taller_reparaciones/core/utils/formato.dart';
import 'package:taller_reparaciones/core/utils/whatsapp.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es_AR'));

  group('Formato.parseMonto', () {
    final casos = <String, double?>{
      '15000': 15000,
      '15.000': 15000,
      '1.000.000': 1000000,
      '15.000,50': 15000.5,
      '1234,5': 1234.5,
      '1234.5': 1234.5,
      '1,234.56': 1234.56,
      r'$ 1.200': 1200,
      '0': 0,
      '': null,
      'abc': null,
      '12,345': 12345,
    };
    casos.forEach((entrada, esperado) {
      test('"$entrada" → $esperado', () => expect(Formato.parseMonto(entrada), esperado));
    });
  });

  group('Formato.moneda', () {
    test('entero sin decimales', () => expect(Formato.moneda(15000), r'$ 15.000'));
    test('con decimales', () => expect(Formato.moneda(1234.5), r'$ 1.234,50'));
    test('ida y vuelta con montoEditable', () {
      expect(Formato.parseMonto(Formato.montoEditable(15000.75)), 15000.75);
      expect(Formato.parseMonto(Formato.montoEditable(1500)), 1500);
    });
  });

  test('Formato.numeroComprobante', () => expect(Formato.numeroComprobante(7), '00007'));

  test('Formato.relativo', () {
    final ahora = DateTime(2026, 11, 16, 10);
    expect(Formato.relativo(DateTime(2026, 11, 16, 8), ahora: ahora), 'hoy');
    expect(Formato.relativo(DateTime(2026, 11, 15, 23), ahora: ahora), 'ayer');
    expect(Formato.relativo(DateTime(2026, 11, 13), ahora: ahora), 'hace 3 días');
    expect(Formato.relativo(DateTime(2026, 10, 1), ahora: ahora), '01/10/2026');
  });

  group('Busqueda', () {
    test('normaliza acentos y mayúsculas', () => expect(Busqueda.normalizar('José PÉREZ Ñandú'), 'jose perez nandu'));

    test('genera prefijos de cada palabra', () {
      final k = Busqueda.keywords(['Juan Pérez', 'AB123CD']);
      expect(k, containsAll(['j', 'ju', 'juan', 'p', 'perez', 'ab123cd']));
      expect(k, isNot(contains('juan perez')));
    });

    test('coincide con varias palabras en cualquier orden', () {
      final k = Busqueda.keywords(['Juan Pérez', 'Toyota Corolla']);
      expect(Busqueda.coincide(k, 'perez juan'), isTrue);
      expect(Busqueda.coincide(k, 'coro jua'), isTrue);
      expect(Busqueda.coincide(k, 'juan gomez'), isFalse);
    });

    test('término principal es el más largo', () {
      expect(Busqueda.terminoPrincipal('a corolla'), 'corolla');
      expect(Busqueda.terminoPrincipal('   '), isNull);
    });
  });

  group('WhatsApp.normalizarTelefono', () {
    final casos = <String, String?>{
      '11 5544-3322': '5491155443322',
      '011 15 5544-3322': '5491155443322',
      '0223 15 555-1234': '5492235551234',
      '+54 9 11 5544 3322': '5491155443322',
      '54 11 5544 3322': '5491155443322',
      '1234': null,
      '': null,
    };
    casos.forEach((entrada, esperado) {
      test('"$entrada" → $esperado', () => expect(WhatsApp.normalizarTelefono(entrada), esperado));
    });

    test('arma el enlace wa.me con el texto codificado', () {
      final uri = WhatsApp.enlace('11 5544 3322', 'Hola Juan & cía')!;
      expect(uri.host, 'wa.me');
      expect(uri.path, '/5491155443322');
      expect(uri.queryParameters['text'], 'Hola Juan & cía');
    });
  });

  test('WhatsApp.aplicarPlantilla reemplaza y deja vacío lo desconocido', () {
    expect(
      WhatsApp.aplicarPlantilla('Hola {cliente}, total {total}{nada}', {'cliente': 'Ana', 'total': r'$ 100'}),
      r'Hola Ana, total $ 100',
    );
  });
}
