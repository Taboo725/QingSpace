import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';
import 'theme_config.dart';

class ThemeProvider with ChangeNotifier {
  static const String _themeKey = 'app_theme_mode';

  AppColorMode _currentMode = AppColorMode.classic;
  ThemeData _themeData = AppTheme.getTheme(
    ThemeConfig.themes[AppColorMode.classic]!,
  );

  AppColorMode get currentMode => _currentMode;
  ThemeConfig get currentConfig => ThemeConfig.themes[_currentMode]!;
  ThemeData get themeData => _themeData;

  /// Restores the saved theme. Awaited before the first frame so the app never
  /// paints the default palette and then flips to the user's choice.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_themeKey);
    if (index == null || index < 0 || index >= AppColorMode.values.length) {
      return;
    }
    _apply(AppColorMode.values[index]);
  }

  Future<void> setTheme(AppColorMode mode) async {
    if (_currentMode == mode) return;
    _apply(mode);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode.index);
  }

  void _apply(AppColorMode mode) {
    _currentMode = mode;
    _themeData = AppTheme.getTheme(currentConfig);
    notifyListeners();
  }
}
