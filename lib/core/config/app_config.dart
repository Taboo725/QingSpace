import 'package:flutter/foundation.dart';

class SidebarModule {
  final String title;
  final String iconName;
  final String? categoryFilter;
  final bool isHome;

  SidebarModule({
    required this.title,
    required this.iconName,
    this.categoryFilter,
    this.isHome = false,
  });
}

class AppConfig {
  // ── App constants ─────────────────────────────────────────────────────────

  static const String categoryField = 'category';

  // ── Debug ─────────────────────────────────────────────────────────────────

  static final ValueNotifier<bool> debugModeNotifier = ValueNotifier(false);
  static bool get debugMode => debugModeNotifier.value;
  static set debugMode(bool value) => debugModeNotifier.value = value;

  static final ValueNotifier<DateTime?> debugDateNotifier = ValueNotifier(null);
  static DateTime? get debugDate => debugDateNotifier.value;
  static set debugDate(DateTime? value) => debugDateNotifier.value = value;

  /// Returns the effective "today", respecting debug mode.
  static DateTime get effectiveNow =>
      debugMode && debugDate != null ? debugDate! : DateTime.now();

  // ── Navigation ────────────────────────────────────────────────────────────

  static List<SidebarModule> get modules => [
    SidebarModule(title: 'Home', iconName: 'home', isHome: true),
    SidebarModule(title: 'Moments', iconName: 'timeline'),
    SidebarModule(title: 'Diaries', iconName: 'book', categoryFilter: 'diaries'),
    SidebarModule(title: 'Letters', iconName: 'mail', categoryFilter: 'letters'),
    SidebarModule(title: 'Gallery', iconName: 'gallery'),
    if (debugMode) SidebarModule(title: 'Posts', iconName: 'all_inclusive'),
  ];
}
