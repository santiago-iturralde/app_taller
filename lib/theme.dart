import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Definimos los colores base de una vez por todas.
final _seedColor = Colors.blue;

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    // 1. Creamos el ColorScheme a partir de la semilla (seed)
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
      // Puedes sobrescribir colores específicos si quieres
      // primary: _seedColor,
      // secondary: Colors.amber,
    ),

    // 2. Usamos la tipografía de Google Fonts
    textTheme: GoogleFonts.poppinsTextTheme(),

    // 3. Definimos CÓMO se verán los componentes en TODA la app
    appBarTheme: AppBarTheme(
      backgroundColor: _seedColor,
      foregroundColor: Colors.white, // Color del texto y los iconos en la AppBar
      elevation: 2,
      centerTitle: true,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey.shade100, // Un gris muy sutil
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: _seedColor, width: 2),
      ),
      labelStyle: TextStyle(color: Colors.black54),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _seedColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: _seedColor,
      ),
    ),

    cardTheme: CardThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      elevation: 3,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: _seedColor,
      foregroundColor: Colors.white,
      shape: CircleBorder(),
    ),
  );
}