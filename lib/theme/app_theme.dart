import 'package:flutter/material.dart';

class AppColors {
  // Brand & Acentos Neon (Teal/Cyan & Indigo Militar)
  static const Color cyan = Color(0xFF00D2B4);       // Neon Cyan principal
  static const Color cyanLight = Color(0xFF2DD4BF);
  static const Color cyanDark = Color(0xFF0D9488);
  static const Color primary = Color(0xFF00D2B4);    // Ciano Neon como cor primária
  static const Color primaryLight = Color(0xFF2DD4BF);
  static const Color primaryDark = Color(0xFF0D9488);
  static const Color accent = Color(0xFF6366F1);     // Indigo elétrico
  static const Color purple = Color(0xFF7C3AED);
  static const Color primaryBlue = Color(0xFF2563EB); // Azul primário clássico

  // Status & Disponibilidade
  static const Color success = Color(0xFF10B981);    // Verde-disponibilidade
  static const Color warning = Color(0xFFF59E0B);    // Âmbar / Cautelado
  static const Color maintenance = Color(0xFFEAB308);// Manutenção
  static const Color danger = Color(0xFFEF4444);     // Atrasada / Baixo estoque
  static const Color info = Color(0xFF38BDF8);       // Azul Céu

  // Obsidian Dark Theme (Estética Militar Escura de Alto Contraste)
  static const Color darkBackground = Color(0xFF0B0F17); // Obsidian base profundo
  static const Color darkSurface = Color(0xFF101520);    // Superfície escura
  static const Color darkSurfaceVariant = Color(0xFF151D2A);
  static const Color darkCard = Color(0xFF151D2A);       // Superfície de cards e tabelas
  static const Color darkCardHover = Color(0xFF1C2638);  // Hover suave
  static const Color darkBorder = Color(0xFF232B3E);     // Bordas finas de 1px
  static const Color darkBorderHover = Color(0xFF00D2B4);
  static const Color darkText = Color(0xFFF9FAFB);
  static const Color darkTextSecondary = Color(0xFF94A3B8);

  // Light Theme Colors
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF1F5F9);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightBorderHover = Color(0xFF00D2B4);
  static const Color lightText = Color(0xFF0F172A);

  // Aliases de conveniência
  static const Color cardBorder = darkBorder;
  static const Color sidebarBackground = darkBackground;
  static const Color textPrimary = darkText;
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.primaryLight,
        surface: AppColors.darkSurface,
        error: AppColors.danger,
        onPrimary: Colors.white,
        onSurface: AppColors.darkText,
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.darkBorder, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.darkBorder, width: 1),
        ),
      ),
      dividerColor: AppColors.darkBorder,
      fontFamily: 'Segoe UI',
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBackground,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.primaryLight,
        surface: AppColors.lightSurface,
        error: AppColors.danger,
        onPrimary: Colors.white,
        onSurface: AppColors.lightText,
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.lightBorder, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.lightBorder, width: 1),
        ),
      ),
      dividerColor: AppColors.lightBorder,
      fontFamily: 'Segoe UI',
    );
  }
}
