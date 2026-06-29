import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Paleta Oficial de Colores de Fitki (Fintech Premium y Accesible)
class AppColors {
  // Colores Base de la Paleta de Alto Contraste (WCAG 2.1 AA/AAA)
  static const indigoPrimary = Color(0xFF4F46E5);      // Indigo (Branding principal y botones)
  static const emeraldSuccess = Color(0xFF059669);     // Emerald Green (Ahorro, éxito, ingresos)
  static const amberWarning = Color(0xFFB45309);       // Amber Brown (Advertencias moderadas)
  static const crimsonError = Color(0xFFDC2626);        // Crimson Red (Gastos, deudas, alertas críticas)

  // Colores decorativos y de degradados (compatibilidad)
  static const blushPink = Color(0xFFFBE4E6);          // Rosa Pálido
  static const rosePink = Color(0xFFF59BA6);           // Rosa Rosado
  static const butterYellow = Color(0xFFFEE5A5);       // Amarillo Mantequilla
  static const mintTeal = Color(0xFF7CE4D2);           // Verde Menta
  static const skyBlue = Color(0xFF96D1EC);            // Azul Cielo

  // Asignaciones de Sistema mapeadas a la paleta accesible
  static const primary = indigoPrimary;
  static const secondary = emeraldSuccess;
  static const accent = amberWarning;
  static const warning = crimsonError;

  // Neutros Profesionales y Premium
  static const background = Color(0xFFF8FAFC);          // Slate 50 (Fondo principal)
  static const surface = Color(0xFFFFFFFF);             // Blanco puro para tarjetas y superficies
  static const cardBackground = Color(0xFFFFFFFF);      // Blanco para coherencia
  static const border = Color(0xFFE2E8F0);              // Slate 200 (Borde sutil)

  static const textPrimary = Color(0xFF0F172A);         // Slate 900
  static const textSecondary = Color(0xFF475569);       // Slate 600

  // Colores Temáticos por Módulo (Fondos)
  static const bgDashboard = Color(0xFFEFF6FF);         // Azul suave
  static const bgMetas = Color(0xFFECFDF5);             // Verde esmeralda suave
  static const bgDeudas = Color(0xFFFEF2F2);            // Rosa pálido suave
  static const bgAsistente = Color(0xFFFFFBEB);         // Amarillo suave

  // Colores Temáticos por Módulo (Bordes de Tarjetas)
  static const borderDashboard = Color(0xFFBFDBFE);
  static const borderMetas = Color(0xFFA7F3D0);
  static const borderDeudasAlerta = Color(0xFFFECACA);
  static const borderDeudasNormal = Color(0xFFFDE68A);
  static const borderAsistente = Color(0xFFFDE68A);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: GoogleFonts.outfitTextTheme(),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shadowColor: const Color(0x060F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border, width: 1.0),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16), // Botones más modernos y estilizados
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFC), // Off-white premium para los campos
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        hintStyle: GoogleFonts.outfit(
          color: AppColors.textSecondary,
          fontSize: 14,
        ),
      ),
    );
  }
}

String formatMonto(double monto) {
  // Manejo de valores negativos
  final bool isNegative = monto < 0;
  final double absoluteMonto = monto.abs();
  
  String formatted;
  if (absoluteMonto % 1 == 0) {
    formatted = absoluteMonto.toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  } else {
    formatted = absoluteMonto.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  }
  
  return isNegative ? '-$formatted' : formatted;
}

