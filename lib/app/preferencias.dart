import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias de este dispositivo (no se sincronizan entre equipos).
class Preferencias extends ChangeNotifier {
  Preferencias._(this._prefs);

  static const _claveTema = 'tema';
  final SharedPreferences? _prefs;

  static Future<Preferencias> cargar() async {
    try {
      return Preferencias._(await SharedPreferences.getInstance());
    } catch (_) {
      // Navegación privada o almacenamiento bloqueado: se usan valores por defecto.
      return Preferencias._(null);
    }
  }

  /// Por defecto, modo oscuro.
  ThemeMode get tema => switch (_prefs?.getString(_claveTema)) {
        'claro' => ThemeMode.light,
        'sistema' => ThemeMode.system,
        _ => ThemeMode.dark,
      };

  Future<void> cambiarTema(ThemeMode modo) async {
    final valor = switch (modo) {
      ThemeMode.light => 'claro',
      ThemeMode.system => 'sistema',
      ThemeMode.dark => 'oscuro',
    };
    try {
      await _prefs?.setString(_claveTema, valor);
    } catch (_) {}
    notifyListeners();
  }
}

class PreferenciasScope extends InheritedNotifier<Preferencias> {
  const PreferenciasScope({super.key, required Preferencias preferencias, required super.child})
      : super(notifier: preferencias);

  static Preferencias of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PreferenciasScope>()!.notifier!;
}

/// Selector Claro / Oscuro / Sistema.
class SelectorTema extends StatelessWidget {
  const SelectorTema({super.key, this.compacto = false});
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final prefs = PreferenciasScope.of(context);
    return SegmentedButton<ThemeMode>(
      showSelectedIcon: false,
      style: compacto ? const ButtonStyle(visualDensity: VisualDensity.compact) : null,
      segments: [
        ButtonSegment(value: ThemeMode.light, icon: const Icon(Icons.light_mode_outlined), label: compacto ? null : const Text('Claro'), tooltip: 'Claro'),
        ButtonSegment(value: ThemeMode.dark, icon: const Icon(Icons.dark_mode_outlined), label: compacto ? null : const Text('Oscuro'), tooltip: 'Oscuro'),
        ButtonSegment(value: ThemeMode.system, icon: const Icon(Icons.brightness_auto_outlined), label: compacto ? null : const Text('Sistema'), tooltip: 'Según el sistema'),
      ],
      selected: {prefs.tema},
      onSelectionChanged: (s) => prefs.cambiarTema(s.first),
    );
  }
}
