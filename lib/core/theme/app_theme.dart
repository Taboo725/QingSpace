import 'package:flutter/material.dart';
import 'theme_config.dart';

class AppTheme {
  // Keep original constants for fallback/default
  static const Color primaryColor = Color(0xFF2C3E50); // Deep Blue Grey
  static const Color accentColor = Color(0xFFE89AC7); // Soft Pink (Pastel)
  static const Color accentLight = Color(0xFFFDEEF5); // Very Light Pink
  static const Color backgroundColor = Color(0xFFF8F9FA); // Off White
  static const Color cardColor = Colors.white;
  static const Color errorColor = Color(0xFFE57373);

  // New method to generate theme based on config
  static ThemeData getTheme(ThemeConfig config) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: config.primaryColor,
        primary: config.primaryColor,
        secondary: config.accentColor,
        secondaryContainer: config.accentLight,
        onSecondaryContainer: config.primaryColor,
        // background: config.backgroundColor, // Deprecated
        surface: cardColor,
        error: errorColor,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: config.backgroundColor,
      // Minimalist Navigation Bar / Rail
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: config.backgroundColor,
        indicatorColor: config.accentLight,
        selectedIconTheme: IconThemeData(color: config.primaryColor),
        unselectedIconTheme: const IconThemeData(
          color: Color(0xFF616161),
        ), // Darker grey, less faded
        labelType: NavigationRailLabelType.all,
        selectedLabelTextStyle: TextStyle(
          color: config.primaryColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: const TextStyle(
          color: Color(0xFF616161),
          fontSize: 12,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: config.backgroundColor,
        indicatorColor: config.accentLight,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: config.primaryColor);
          }
          return const IconThemeData(color: Color(0xFF616161));
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              color: config.primaryColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            );
          }
          return const TextStyle(color: Color(0xFF616161), fontSize: 12);
        }),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: config.primaryColor,
          fontFamily: 'Source Han Serif CN',
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: config.primaryColor,
          fontFamily: 'Source Han Serif CN',
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF4A4A4A),
          height: 1.6,
          fontFamily: 'Source Han Serif CN',
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: const Color(0xFF666666),
          height: 1.5,
          fontFamily: 'Source Han Serif CN',
        ),
      ).apply(fontFamily: 'Source Han Serif CN'),
      appBarTheme: AppBarTheme(
        backgroundColor: config.backgroundColor,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: config.primaryColor),
        titleTextStyle: TextStyle(
          color: config.primaryColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          fontFamily: 'Source Han Serif CN',
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.withValues(alpha: 0.05)),
        ),
        margin: const EdgeInsets.only(bottom: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: config.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'Source Han Serif CN',
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: config.primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: config.primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: 'Source Han Serif CN',
          ),
        ),
      ),
      iconTheme: IconThemeData(color: config.primaryColor),
      dividerTheme: DividerThemeData(
        color: Colors.grey.withValues(alpha: 0.1),
        thickness: 1,
        space: 24,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: config.primaryColor, width: 2),
        ),
        labelStyle: TextStyle(color: config.primaryColor),
        hintStyle: TextStyle(color: Colors.grey.withValues(alpha: 0.6)),
      ),
    );
  }

  static ThemeData get lightTheme {
    return getTheme(
      const ThemeConfig(
        name: 'Default',
        primaryColor: primaryColor,
        accentColor: accentColor,
        accentLight: accentLight,
      ),
    );
  }
}
