/// Búsqueda por palabras clave compatible con Firestore.
///
/// Firestore no tiene búsqueda de texto libre. Guardamos en cada documento
/// una lista `keywords` con los prefijos de cada palabra relevante
/// ("juan" → j, ju, jua, juan) y consultamos con `array-contains` por el
/// primer término. El resto de los términos se filtra en memoria.
abstract final class Busqueda {
  static const int _largoMaximoPrefijo = 15;

  static const _acentos = {
    'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n',
    'à': 'a', 'è': 'e', 'ì': 'i', 'ò': 'o', 'ù': 'u',
  };

  /// Minúsculas, sin acentos.
  static String normalizar(String texto) {
    final buffer = StringBuffer();
    for (final rune in texto.toLowerCase().runes) {
      final c = String.fromCharCode(rune);
      buffer.write(_acentos[c] ?? c);
    }
    return buffer.toString();
  }

  static List<String> palabras(String texto) =>
      normalizar(texto).split(RegExp(r'[^a-z0-9]+')).where((p) => p.isNotEmpty).toList();

  /// Genera los prefijos de todas las palabras de [campos].
  static List<String> keywords(Iterable<String?> campos) {
    final resultado = <String>{};
    for (final campo in campos) {
      if (campo == null || campo.isEmpty) continue;
      for (final palabra in palabras(campo)) {
        final limite = palabra.length < _largoMaximoPrefijo ? palabra.length : _largoMaximoPrefijo;
        for (var i = 1; i <= limite; i++) {
          resultado.add(palabra.substring(0, i));
        }
      }
    }
    return resultado.toList()..sort();
  }

  /// Término que se usa en la consulta `array-contains` (el más largo,
  /// porque es el más selectivo). `null` si la búsqueda está vacía.
  static String? terminoPrincipal(String consulta) {
    final ps = palabras(consulta);
    if (ps.isEmpty) return null;
    ps.sort((a, b) => b.length.compareTo(a.length));
    final t = ps.first;
    return t.length > _largoMaximoPrefijo ? t.substring(0, _largoMaximoPrefijo) : t;
  }

  /// `true` si todas las palabras de [consulta] están en [keywords].
  static bool coincide(List<String> keywords, String consulta) {
    final set = keywords.toSet();
    return palabras(consulta).every((p) {
      final t = p.length > _largoMaximoPrefijo ? p.substring(0, _largoMaximoPrefijo) : p;
      return set.contains(t);
    });
  }
}
