import 'package:intl/intl.dart';

/// Formatos de presentación (moneda, fechas, números) para Argentina.
abstract final class Formato {
  static const locale = 'es_AR';

  // Patrón explícito: el CLDR de es_AR pone el símbolo al final ("15.000 $"),
  // pero en Argentina se escribe "$ 15.000".
  static final _moneda = NumberFormat.currency(locale: locale, symbol: r'$', customPattern: '¤ #,##0.00');
  static final _monedaEntera = NumberFormat.currency(locale: locale, symbol: r'$', customPattern: '¤ #,##0', decimalDigits: 0);
  static final _numeroEditable = NumberFormat('#,##0.##', locale);
  static final _cantidad = NumberFormat('#,##0.##', locale);

  /// `15000` → `$ 15.000` · `1234.5` → `$ 1.234,50`
  static String moneda(num valor) {
    final redondeado = (valor * 100).round() / 100;
    final esEntero = redondeado == redondeado.truncateToDouble();
    return (esEntero ? _monedaEntera : _moneda).format(redondeado);
  }

  /// Valor para precargar un campo de monto editable: `15000` → `15.000`.
  static String montoEditable(num? valor) {
    if (valor == null || valor == 0) return '';
    return _numeroEditable.format(valor);
  }

  static String cantidad(num valor) => _cantidad.format(valor);

  static String fecha(DateTime d) => DateFormat('dd/MM/yyyy', locale).format(d);
  static String fechaHora(DateTime d) => DateFormat('dd/MM/yyyy HH:mm', locale).format(d);
  static String fechaLarga(DateTime d) => capitalizar(DateFormat("EEEE d 'de' MMMM", locale).format(d));
  static String diaMes(DateTime d) => DateFormat('d MMM', locale).format(d).replaceAll('.', '');
  static String mesAnio(DateTime d) => capitalizar(DateFormat('MMMM yyyy', locale).format(d));
  static String mes(DateTime d) => capitalizar(DateFormat('MMMM', locale).format(d));

  /// Número de comprobante con ceros a la izquierda: `7` → `00007`.
  static String numeroComprobante(int numero) => numero.toString().padLeft(5, '0');

  /// Número de recibo. Los importados del sistema anterior no tienen número
  /// nuevo (0) y muestran el que tenían.
  static String numeroRecibo(int numero, String anterior) =>
      numero > 0 ? numeroComprobante(numero) : (anterior.isEmpty ? 's/n' : anterior);

  static String capitalizar(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// Texto relativo corto: "hoy", "ayer", "hace 3 días", o la fecha.
  static String relativo(DateTime d, {DateTime? ahora}) {
    final hoy = _soloFecha(ahora ?? DateTime.now());
    final dias = hoy.difference(_soloFecha(d)).inDays;
    if (dias == 0) return 'hoy';
    if (dias == 1) return 'ayer';
    if (dias > 1 && dias < 7) return 'hace $dias días';
    if (dias == -1) return 'mañana';
    return fecha(d);
  }

  static DateTime _soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Interpreta montos escritos como los escribe la gente en Argentina:
  /// `15.000`, `15000`, `15.000,50`, `1234,5`, `$ 1.200`, `1200.75`.
  /// Devuelve `null` si no hay un número válido.
  static double? parseMonto(String entrada) {
    var s = entrada.trim().replaceAll(RegExp(r'[^\d,.\-]'), '');
    if (s.isEmpty || s == '-') return null;

    final ultimaComa = s.lastIndexOf(',');
    final ultimoPunto = s.lastIndexOf('.');

    if (ultimaComa >= 0 && ultimoPunto >= 0) {
      // El separador que aparece último es el decimal.
      s = ultimaComa > ultimoPunto
          ? s.replaceAll('.', '').replaceAll(',', '.')
          : s.replaceAll(',', '');
    } else if (ultimaComa >= 0) {
      final partes = s.split(',');
      s = (partes.length == 2 && partes[1].length <= 2) ? '${partes[0]}.${partes[1]}' : s.replaceAll(',', '');
    } else if (ultimoPunto >= 0) {
      final partes = s.split('.');
      // "15.000" o "1.000.000" son separadores de miles; "12.5" es decimal.
      if (partes.length > 2 || partes[1].length == 3) s = s.replaceAll('.', '');
    }
    return double.tryParse(s);
  }
}
