import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Paleta Oficial de Colores Pastel de Fitki
class AppColors {
  static const background = Color(0xFFE0FEFE);          // Azul muy suave (Fondo principal)
  static const surface = Color(0xFFFFFFD8);             // Crema claro (Superficies de tarjetas/contenedores)
  static const cardBackground = Color(0xFFFFFFD8);      // Crema claro

  static const primary = Color(0xFFB5EAD7);             // Verde menta (Ahorro, éxito, ingresos)
  static const secondary = Color(0xFFC7CEEA);           // Lavanda grisáceo (Burbujas de chat de usuario, realces)
  static const accent = Color(0xFFFFDAC1);              // Beige/Melocotón cálido (Deudas normales, neutrales)
  static const warning = Color(0xFFFF9AA2);             // Rosa suave (Alertas, deudas urgentes, retrasos)

  static const textPrimary = Color(0xFF2D3436);
  static const textSecondary = Color(0xFF636E72);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        surface: AppColors.surface,
        background: AppColors.background,
      ),
      scaffoldBackgroundColor: AppColors.background,
      // Aplicación de la tipografía Outfit a todo el sistema
      textTheme: GoogleFonts.outfitTextTheme(),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.01),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24), // Bordes más suaves y redondeados (24px)
          side: const BorderSide(color: Color(0xFFE0ECEC), width: 1.2),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: GoogleFonts.outfit(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: const Color(0xFF3B4A4A),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24), // Botones tipo cápsula (24px)
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFFFFF5), // Crema muy suave para los campos
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24), // Inputs tipo cápsula
          borderSide: const BorderSide(color: Color(0xFFE0ECEC), width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: Color(0xFFE0ECEC), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: AppColors.secondary, width: 1.8),
        ),
        hintStyle: GoogleFonts.outfit(
          color: AppColors.textSecondary,
          fontSize: 14,
        ),
      ),
    );
  }
}
