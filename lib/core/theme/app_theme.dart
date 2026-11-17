import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colores semánticos que Material no trae de fábrica (éxito, alerta, etc.).
///
/// Se leen con `context.colores` y tienen variante clara y oscura.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.exito,
    required this.exitoSuave,
    required this.alerta,
    required this.alertaSuave,
    required this.peligro,
    required this.peligroSuave,
    required this.info,
    required this.infoSuave,
    required this.neutro,
    required this.neutroSuave,
    required this.pro,
    required this.proSuave,
    required this.borde,
    required this.fondoSutil,
  });

  final Color exito, exitoSuave;
  final Color alerta, alertaSuave;
  final Color peligro, peligroSuave;
  final Color info, infoSuave;
  final Color neutro, neutroSuave;
  final Color pro, proSuave;
  final Color borde;
  final Color fondoSutil;

  static const claro = AppColors(
    exito: Color(0xFF15803D),
    exitoSuave: Color(0xFFDCFCE7),
    alerta: Color(0xFFB45309),
    alertaSuave: Color(0xFFFEF3C7),
    peligro: Color(0xFFDC2626),
    peligroSuave: Color(0xFFFEE2E2),
    info: Color(0xFF1D4ED8),
    infoSuave: Color(0xFFDBEAFE),
    neutro: Color(0xFF475569),
    neutroSuave: Color(0xFFF1F5F9),
    pro: Color(0xFFB45309),
    proSuave: Color(0xFFFEF3C7),
    borde: Color(0xFFE4E7EC),
    fondoSutil: Color(0xFFF8FAFC),
  );

  static const oscuro = AppColors(
    exito: Color(0xFF4ADE80),
    exitoSuave: Color(0xFF14321F),
    alerta: Color(0xFFFBBF24),
    alertaSuave: Color(0xFF3A2C0B),
    peligro: Color(0xFFF87171),
    peligroSuave: Color(0xFF3B1414),
    info: Color(0xFF93C5FD),
    infoSuave: Color(0xFF172A4A),
    neutro: Color(0xFFCBD5E1),
    neutroSuave: Color(0xFF1F2530),
    pro: Color(0xFFFBBF24),
    proSuave: Color(0xFF3A2C0B),
    borde: Color(0xFF2A303B),
    fondoSutil: Color(0xFF161A21),
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      exito: l(exito, other.exito),
      exitoSuave: l(exitoSuave, other.exitoSuave),
      alerta: l(alerta, other.alerta),
      alertaSuave: l(alertaSuave, other.alertaSuave),
      peligro: l(peligro, other.peligro),
      peligroSuave: l(peligroSuave, other.peligroSuave),
      info: l(info, other.info),
      infoSuave: l(infoSuave, other.infoSuave),
      neutro: l(neutro, other.neutro),
      neutroSuave: l(neutroSuave, other.neutroSuave),
      pro: l(pro, other.pro),
      proSuave: l(proSuave, other.proSuave),
      borde: l(borde, other.borde),
      fondoSutil: l(fondoSutil, other.fondoSutil),
    );
  }
}

/// Espaciados y radios del sistema de diseño. Usar siempre estos valores
/// en lugar de números sueltos para mantener la consistencia visual.
abstract final class Espacio {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

abstract final class Radios {
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
}

/// Ancho a partir del cual la app usa el diseño de escritorio.
const double kAnchoEscritorio = 900;

/// Ancho máximo del contenido para que no se estire en monitores grandes.
const double kAnchoMaximoContenido = 1120;

abstract final class AppTheme {
  static const Color marca = Color(0xFF2346D8);

  static ThemeData get claro => _construir(Brightness.light);
  static ThemeData get oscuro => _construir(Brightness.dark);

  static ThemeData _construir(Brightness brillo) {
    final esOscuro = brillo == Brightness.dark;
    final colores = esOscuro ? AppColors.oscuro : AppColors.claro;

    final scheme = ColorScheme.fromSeed(
      seedColor: marca,
      brightness: brillo,
    ).copyWith(
      primary: esOscuro ? const Color(0xFF8EA6FF) : marca,
      onPrimary: esOscuro ? const Color(0xFF0B1640) : Colors.white,
      surface: esOscuro ? const Color(0xFF12151B) : Colors.white,
      surfaceContainerLowest: esOscuro ? const Color(0xFF0C0E12) : const Color(0xFFF5F6F8),
      surfaceContainerLow: esOscuro ? const Color(0xFF171A21) : const Color(0xFFF8F9FB),
      surfaceContainer: esOscuro ? const Color(0xFF1B1F27) : const Color(0xFFF1F3F6),
      surfaceContainerHigh: esOscuro ? const Color(0xFF222731) : const Color(0xFFEBEEF2),
      outline: esOscuro ? const Color(0xFF3A414E) : const Color(0xFFCBD2DC),
      outlineVariant: colores.borde,
      error: colores.peligro,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brillo,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surfaceContainerLowest,
      extensions: [colores],
      visualDensity: VisualDensity.standard,
    );

    final texto = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    final bordeInput = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radios.m),
      borderSide: BorderSide(color: scheme.outline),
    );

    return base.copyWith(
      textTheme: texto.copyWith(
        headlineSmall: texto.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4),
        titleLarge: texto.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
        titleMedium: texto.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        titleSmall: texto.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        labelLarge: texto.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        shape: Border(bottom: BorderSide(color: colores.borde)),
        titleTextStyle: texto.titleLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 19),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radios.l),
          side: BorderSide(color: colores.borde),
        ),
      ),
      dividerTheme: DividerThemeData(color: colores.borde, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: bordeInput,
        enabledBorder: bordeInput,
        focusedBorder: bordeInput.copyWith(borderSide: BorderSide(color: scheme.primary, width: 2)),
        errorBorder: bordeInput.copyWith(borderSide: BorderSide(color: scheme.error)),
        focusedErrorBorder: bordeInput.copyWith(borderSide: BorderSide(color: scheme.error, width: 2)),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 46),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radios.m)),
          textStyle: texto.labelLarge?.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 46),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radios.m)),
          textStyle: texto.labelLarge?.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radios.m)),
          textStyle: texto.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radios.l)),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radios.s)),
        side: BorderSide(color: colores.borde),
        labelStyle: texto.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: 0.12),
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => texto.labelSmall?.copyWith(
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.12),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radios.m)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radios.l)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radios.l + 4)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        width: null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radios.m)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radios.m)),
          side: BorderSide(color: scheme.outline),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: colores.borde,
        labelStyle: texto.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: texto.labelLarge,
      ),
    );
  }
}

extension ContextoTema on BuildContext {
  ThemeData get tema => Theme.of(this);
  ColorScheme get esquema => Theme.of(this).colorScheme;
  TextTheme get textos => Theme.of(this).textTheme;
  AppColors get colores => Theme.of(this).extension<AppColors>()!;
  bool get esEscritorio => MediaQuery.sizeOf(this).width >= kAnchoEscritorio;
}
