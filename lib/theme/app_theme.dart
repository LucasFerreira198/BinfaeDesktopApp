import 'package:flutter/material.dart';

/// Sistema de Design Tático Aeroespacial - BINFAE-GL / Google Stitch UI
class AppColors {
  // Brand & Cores Primárias (Material 3 Aerospace Command)
  static const Color primary = Color(0xFFADC6FF);            // Ciano-Azul Tático Claro
  static const Color primaryContainer = Color(0xFF4C8EFF);   // Azul Aeronáutico Intenso
  static const Color onPrimary = Color(0xFF002E69);          // Azul Marinho Profundo
  static const Color onPrimaryContainer = Color(0xFF00285D);
  static const Color primaryFixed = Color(0xFFD8E2FF);
  static const Color primaryFixedDim = Color(0xFFADC6FF);

  // Cores Secundárias
  static const Color secondary = Color(0xFFAAC7FF);
  static const Color secondaryContainer = Color(0xFF0066CC);
  static const Color onSecondary = Color(0xFF002F65);
  static const Color onSecondaryContainer = Color(0xFFDFE8FF);

  // Terciária & Acentos Táticos (Verde Menta de Prontidão Operacional)
  static const Color tertiary = Color(0xFF27E0A9);           // Menta Tático de Alta Visibilidade
  static const Color tertiaryContainer = Color(0xFF00A47A);
  static const Color onTertiary = Color(0xFF003827);
  static const Color onTertiaryContainer = Color(0xFF003122);
  static const Color tertiaryFixed = Color(0xFF54FDC4);

  // Status & Alertas
  static const Color success = Color(0xFF27E0A9);            // Verde Operacional
  static const Color warning = Color(0xFFF59E0B);            // Âmbar Tático
  static const Color maintenance = Color(0xFFEAB308);        // Amarelo Manutenção
  static const Color danger = Color(0xFFFFB4AB);             // Vermelho Erro Tático
  static const Color error = Color(0xFFFFB4AB);
  static const Color errorContainer = Color(0xFF93000A);
  static const Color onError = Color(0xFF690005);
  static const Color info = Color(0xFF4C8EFF);

  // Camadas de Superfície Escura (Tactical Dark Navy - Stitch Baseline)
  static const Color surface = Color(0xFF0A122A);            // Superfície Base Profunda
  static const Color surfaceDim = Color(0xFF0A122A);
  static const Color surfaceBright = Color(0xFF313852);
  static const Color surfaceContainerLowest = Color(0xFF050D25); // Fundo mais escuro
  static const Color surfaceContainerLow = Color(0xFF131A33);    // Painéis secundários
  static const Color surfaceContainer = Color(0xFF171E37);       // Cards e containers padrão
  static const Color surfaceContainerHigh = Color(0xFF212942);   // Hover e elevações
  static const Color surfaceContainerHighest = Color(0xFF2C344D);// Destaques e inputs
  static const Color onSurface = Color(0xFFDBE1FF);              // Texto principal claro
  static const Color onSurfaceVariant = Color(0xFFC2C6D6);       // Texto secundário
  static const Color outline = Color(0xFF8C909F);                // Bordas neutras
  static const Color outlineVariant = Color(0xFF414754);         // Divisores e linhas finas

  // Aliases para compatibilidade reversa com o código existente
  static const Color cyan = Color(0xFF27E0A9);
  static const Color cyanLight = Color(0xFF54FDC4);
  static const Color cyanDark = Color(0xFF00A47A);
  static const Color primaryLight = Color(0xFFD8E2FF);
  static const Color primaryDark = Color(0xFF004494);
  static const Color accent = Color(0xFF4C8EFF);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color primaryBlue = Color(0xFF0066CC);

  static const Color darkBackground = surface;
  static const Color darkSurface = surfaceContainer;
  static const Color darkSurfaceVariant = surfaceContainerHigh;
  static const Color darkCard = surfaceContainer;
  static const Color darkCardHover = surfaceContainerHigh;
  static const Color darkBorder = outlineVariant;
  static const Color darkBorderHover = primary;
  static const Color darkText = onSurface;
  static const Color darkTextSecondary = onSurfaceVariant;

  // Light Theme Colors
  static const Color lightBackground = Color(0xFFF4F6FC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFE9EEF8);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFD3D8E8);
  static const Color lightBorderHover = Color(0xFF4C8EFF);
  static const Color lightText = Color(0xFF0A122A);

  static const Color cardBorder = outlineVariant;
  static const Color sidebarBackground = surfaceContainerLow;
  static const Color textPrimary = onSurface;
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.surface,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        secondaryContainer: AppColors.secondaryContainer,
        onSecondaryContainer: AppColors.onSecondaryContainer,
        tertiary: AppColors.tertiary,
        onTertiary: AppColors.onTertiary,
        tertiaryContainer: AppColors.tertiaryContainer,
        onTertiaryContainer: AppColors.onTertiaryContainer,
        surface: AppColors.surfaceContainer,
        onSurface: AppColors.onSurface,
        onSurfaceVariant: AppColors.onSurfaceVariant,
        outline: AppColors.outline,
        outlineVariant: AppColors.outlineVariant,
        error: AppColors.error,
        onError: AppColors.onError,
        errorContainer: AppColors.errorContainer,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.outlineVariant, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.outlineVariant, width: 1),
        ),
      ),
      dividerColor: AppColors.outlineVariant,
      dividerTheme: const DividerThemeData(
        color: AppColors.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.outlineVariant, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.outlineVariant, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        hintStyle: const TextStyle(color: AppColors.outline, fontSize: 13),
        labelStyle: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
      ),
      fontFamily: 'Inter',
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBackground,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryContainer,
        onPrimary: Colors.white,
        secondary: AppColors.secondaryContainer,
        surface: AppColors.lightSurface,
        error: AppColors.danger,
        onSurface: AppColors.lightText,
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.lightBorder, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.lightBorder, width: 1),
        ),
      ),
      dividerColor: AppColors.lightBorder,
      fontFamily: 'Inter',
    );
  }
}
