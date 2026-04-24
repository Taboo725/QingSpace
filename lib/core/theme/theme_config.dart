import 'package:flutter/material.dart';

enum AppColorMode { classic, forest, sunset, lavender, cyan, sakura }

class ThemeConfig {
  final String name;
  final Color primaryColor;
  final Color accentColor;
  final Color accentLight;
  final Color backgroundColor;

  const ThemeConfig({
    required this.name,
    required this.primaryColor,
    required this.accentColor,
    required this.accentLight,
    this.backgroundColor = const Color(0xFFF8F9FA), // Default clean off-white
  });

  static const Map<AppColorMode, ThemeConfig> themes = {
    AppColorMode.classic: ThemeConfig(
      name: '极简主义',
      primaryColor: Color(0xFF2B2B2B), // Matte Black/Dark Grey
      accentColor: Color(0xFF9E9E9E), // Grey
      accentLight: Color(0xFFF5F5F5),
    ),
    AppColorMode.forest: ThemeConfig(
      name: '绿野仙踪',
      primaryColor: Color(0xFF558B2F), // Light Olive Green
      accentColor: Color(0xFFAED581), // Pale Lime
      accentLight: Color(0xFFF1F8E9),
    ),
    AppColorMode.sunset: ThemeConfig(
      name: '落日余晖',
      primaryColor: Color(0xFFBF360C), // Deep Burnt Orange
      accentColor: Color(0xFFFFCC80), // Soft Orange
      accentLight: Color(0xFFFFF3E0),
    ),
    AppColorMode.lavender: ThemeConfig(
      name: '紫韵流芳',
      primaryColor: Color(0xFF5E35B1), // Deep Purple
      accentColor: Color(0xFFB39DDB), // Soft Purple
      accentLight: Color(0xFFEDE7F6),
    ),
    AppColorMode.cyan: ThemeConfig(
      name: '碧水青天',
      primaryColor: Color(0xFF006064), // Deep Cyan
      accentColor: Color(0xFF4DD0E1), // Bright Cyan
      accentLight: Color(0xFFE0F7FA),
    ),
    AppColorMode.sakura: ThemeConfig(
      name: '繁花如梦',
      primaryColor: Color(0xFFE91E63), // Pink
      accentColor: Color(0xFFF48FB1), // Soft Pink
      accentLight: Color(0xFFFCE4EC),
    ),
  };
}
