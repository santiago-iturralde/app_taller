import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta base: azules y grises pizarra. Todos los colores de la app salen
/// de acá; las pantallas nunca usan colores sueltos.
abstract final class Paleta {
  // Azules de marca
  static const azul50 = Color(0xFFEEF3FF);
  static const azul300 = Color(0xFF8DB0FF);
  static const azul400 = Color(0xFF6E9BFF);
  static const azul500 = Color(0xFF3D72F5);
  static const azul600 = Color(0xFF2155E6);
  static const azul700 = Color(0xFF1A44C2);

  // Navy (modo oscuro y barra lateral)
  static const navy950 = Color(0xFF070D19);
  static const navy900 = Color(0xFF0B1220);
  static const navy850 = Color(0xFF0F1828);
  static const navy800 = Color(0xFF121C2E);
  static const navy750 = Color(0xFF162236);
  static const navy700 = Color(0xFF1B2940);
  static const navy650 = Color(0xFF22324D);
  static const navy600 = Color(0xFF2B3D5C);
  static const navy500 = Color(0xFF3A5077);

  // Grises pizarra (modo claro)
  static const pizarra50 = Color(0xFFF4F6FA);
  static const pizarra100 = Color(0xFFEAEFF5);
  static const pizarra200 = Color(0xFFDDE4EE);
  static const pizarra300 = Color(0xFFC7D1DF);
  static const pizarra400 = Color(0xFF94A3BA);
  static const pizarra500 = Color(0xFF64748B);
  static const pizarra600 = Color(0xFF4A5A72);
  static const pizarra800 = Color(0xFF1E293B);
  static const pizarra900 = Color(0xFF0F1B2D);
  static const pizarraTexto = Color(0xFFE3E9F3);
  static const pizarraTextoSuave = Color(0xFF93A3BD);
}

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
    required this.lateralFondo,
    required this.lateralTexto,
    required this.lateralTextoSuave,
    required this.lateralActivo,
    required this.lateralBorde,
  });

  final Color exito, exitoSuave;
  final Color alerta, alertaSuave;
  final Color peligro, peligroSuave;
  final Color info, infoSuave;
  final Color neutro, neutroSuave;
  final Color pro, proSuave;
  final Color borde;
  final Color fondoSutil;

  /// Barra lateral de escritorio: navy en ambos modos.
  final Color lateralFondo, lateralTexto, lateralTextoSuave, lateralActivo, lateralBorde;

  static const claro = AppColors(
    exito: Color(0xFF15803D),
    exitoSuave: Color(0xFFDCFCE7),
    alerta: Color(0xFFB45309),
    alertaSuave: Color(0xFFFEF3C7),
    peligro: Color(0xFFDC2626),
    peligroSuave: Color(0xFFFEE2E2),
    info: Paleta.azul600,
    infoSuave: Color(0xFFDDE7FF),
    neutro: Paleta.pizarra600,
    neutroSuave: Paleta.pizarra100,
    pro: Color(0xFFB45309),
    proSuave: Color(0xFFFEF3C7),
    borde: Paleta.pizarra200,
    fondoSutil: Paleta.pizarra50,
    lateralFondo: Paleta.navy900,
    lateralTexto: Paleta.pizarraTexto,
    lateralTextoSuave: Paleta.pizarraTextoSuave,
    lateralActivo: Color(0x332155E6),
    lateralBorde: Paleta.navy700,
  );

  static const oscuro = AppColors(
    exito: Color(0xFF34D399),
    exitoSuave: Color(0xFF0F2E2B),
    alerta: Color(0xFFFBBF24),
    alertaSuave: Color(0xFF33290F),
    peligro: Color(0xFFF87171),
    peligroSuave: Color(0xFF3A1A24),
    info: Paleta.azul400,
    infoSuave: Color(0xFF172A52),
    neutro: Color(0xFFA9B6CB),
    neutroSuave: Paleta.navy700,
    pro: Color(0xFFFBBF24),
    proSuave: Color(0xFF33290F),
    borde: Paleta.navy650,
    fondoSutil: Paleta.navy850,
    lateralFondo: Paleta.navy950,
    lateralTexto: Paleta.pizarraTexto,
    lateralTextoSuave: Paleta.pizarraTextoSuave,
    lateralActivo: Color(0x336E9BFF),
    lateralBorde: Paleta.navy750,
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
      lateralFondo: l(lateralFondo, other.lateralFondo),
      lateralTexto: l(lateralTexto, other.lateralTexto),
      lateralTextoSuave: l(lateralTextoSuave, other.lateralTextoSuave),
      lateralActivo: l(lateralActivo, other.lateralActivo),
      lateralBorde: l(lateralBorde, other.lateralBorde),
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
  static const Color marca = Paleta.azul600;

  static final ThemeData claro = _construir(Brightness.light);
  static final ThemeData oscuro = _construir(Brightness.dark);

  static ThemeData _construir(Brightness brillo) {
    final esOscuro = brillo == Brightness.dark;
    final colores = esOscuro ? AppColors.oscuro : AppColors.claro;

    final scheme = ColorScheme.fromSeed(seedColor: marca, brightness: brillo).copyWith(
      primary: esOscuro ? Paleta.azul400 : Paleta.azul600,
      onPrimary: esOscuro ? const Color(0xFF061331) : Colors.white,
      primaryContainer: esOscuro ? const Color(0xFF1A2F5E) : Paleta.azul50,
      onPrimaryContainer: esOscuro ? Paleta.azul300 : Paleta.azul700,
      secondaryContainer: esOscuro ? const Color(0xFF1A2F5E) : const Color(0xFFDDE7FF),
      onSecondaryContainer: esOscuro ? Paleta.azul300 : Paleta.azul700,
      surface: esOscuro ? Paleta.navy800 : Colors.white,
      onSurface: esOscuro ? Paleta.pizarraTexto : Paleta.pizarra900,
      onSurfaceVariant: esOscuro ? Paleta.pizarraTextoSuave : Paleta.pizarra500,
      surfaceContainerLowest: esOscuro ? Paleta.navy900 : const Color(0xFFEEF2F7),
      surfaceContainerLow: esOscuro ? Paleta.navy850 : Paleta.pizarra50,
      surfaceContainer: esOscuro ? Paleta.navy750 : Paleta.pizarra100,
      surfaceContainerHigh: esOscuro ? Paleta.navy700 : Paleta.pizarra200,
      surfaceContainerHighest: esOscuro ? Paleta.navy650 : Paleta.pizarra300,
      outline: esOscuro ? Paleta.navy500 : Paleta.pizarra300,
      outlineVariant: colores.borde,
      error: colores.peligro,
      inverseSurface: esOscuro ? Paleta.pizarraTexto : Paleta.navy800,
      onInverseSurface: esOscuro ? Paleta.navy900 : Paleta.pizarraTexto,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brillo,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surfaceContainerLowest,
      canvasColor: scheme.surface,
      extensions: [colores],
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
        backgroundColor: esOscuro ? Paleta.navy900 : Colors.white,
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
        fillColor: esOscuro ? Paleta.navy850 : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: bordeInput,
        enabledBorder: bordeInput.copyWith(borderSide: BorderSide(color: esOscuro ? Paleta.navy600 : Paleta.pizarra300)),
        focusedBorder: bordeInput.copyWith(borderSide: BorderSide(color: scheme.primary, width: 2)),
        errorBorder: bordeInput.copyWith(borderSide: BorderSide(color: scheme.error)),
        focusedErrorBorder: bordeInput.copyWith(borderSide: BorderSide(color: scheme.error, width: 2)),
        disabledBorder: bordeInput.copyWith(borderSide: BorderSide(color: colores.borde)),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
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
          foregroundColor: esOscuro ? Paleta.pizarraTexto : Paleta.pizarra800,
          side: BorderSide(color: esOscuro ? Paleta.navy600 : Paleta.pizarra300),
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
        backgroundColor: esOscuro ? Paleta.navy800 : Colors.white,
        selectedColor: scheme.primaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radios.s)),
        side: BorderSide(color: esOscuro ? Paleta.navy600 : Paleta.pizarra200),
        labelStyle: texto.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: esOscuro ? Paleta.navy950 : Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        height: 68,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => texto.labelSmall?.copyWith(
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant,
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radios.m)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: esOscuro ? Paleta.navy750 : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radios.m),
          side: BorderSide(color: colores.borde),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(esOscuro ? Paleta.navy750 : Colors.white),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radios.m),
            side: BorderSide(color: colores.borde),
          )),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radios.l),
          side: esOscuro ? BorderSide(color: colores.borde) : BorderSide.none,
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: esOscuro ? Paleta.navy750 : Paleta.azul600,
        headerForegroundColor: esOscuro ? Paleta.pizarraTexto : Colors.white,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: scheme.outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radios.l + 4)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: esOscuro ? Paleta.navy650 : Paleta.navy800,
        contentTextStyle: texto.bodyMedium?.copyWith(color: Paleta.pizarraTexto),
        actionTextColor: Paleta.azul300,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radios.m)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: esOscuro ? Paleta.navy800 : Colors.white,
          selectedBackgroundColor: scheme.primaryContainer,
          selectedForegroundColor: scheme.onPrimaryContainer,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radios.m)),
          side: BorderSide(color: esOscuro ? Paleta.navy600 : Paleta.pizarra300),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: colores.borde,
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.primary,
        labelStyle: texto.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: texto.labelLarge,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: esOscuro ? Paleta.navy700 : Paleta.pizarra200,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: esOscuro ? Paleta.navy650 : Paleta.navy800,
          borderRadius: BorderRadius.circular(Radios.s),
        ),
        textStyle: texto.bodySmall?.copyWith(color: Paleta.pizarraTexto),
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
  bool get esOscuro => Theme.of(this).brightness == Brightness.dark;
}
