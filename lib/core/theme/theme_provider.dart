import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_config.dart';
import 'app_theme.dart';

class ThemeProvider with ChangeNotifier {
  static const String _themeKey = 'app_theme_mode';
  AppColorMode _currentMode = AppColorMode.classic;

  AppColorMode get currentMode => _currentMode;
  ThemeConfig get currentConfig => ThemeConfig.themes[_currentMode]!;

  late ThemeData _themeData;
  ThemeData get themeData => _themeData;

  ThemeProvider() {
    _themeData = AppTheme.getTheme(currentConfig);
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final loadedModeIndex = prefs.getInt(_themeKey);
    if (loadedModeIndex != null) {
      if (loadedModeIndex >= 0 &&
          loadedModeIndex < AppColorMode.values.length) {
        _currentMode = AppColorMode.values[loadedModeIndex];
        _themeData = AppTheme.getTheme(currentConfig);
        notifyListeners();
      }
    }
  }

  Future<void> setTheme(AppColorMode mode) async {
    if (_currentMode == mode) return;

    _currentMode = mode;
    _themeData = AppTheme.getTheme(currentConfig);
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode.index);
  }
}
