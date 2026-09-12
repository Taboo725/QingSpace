import 'package:flutter/material.dart';

/// Which page a sidebar entry opens.
enum ModuleKind { home, moments, gallery, posts }

@immutable
class SidebarModule {
  final String title;
  final IconData icon;
  final ModuleKind kind;

  /// Frontmatter category this module filters posts by; null shows every post.
  final String? categoryFilter;

  const SidebarModule({
    required this.title,
    required this.icon,
    required this.kind,
    this.categoryFilter,
  });
}

class AppConfig {
  const AppConfig._();

  // ── Debug ─────────────────────────────────────────────────────────────────

  static final ValueNotifier<bool> debugModeNotifier = ValueNotifier(false);
  static bool get debugMode => debugModeNotifier.value;
  static set debugMode(bool value) => debugModeNotifier.value = value;

  static final ValueNotifier<DateTime?> debugDateNotifier = ValueNotifier(null);
  static DateTime? get debugDate => debugDateNotifier.value;
  static set debugDate(DateTime? value) => debugDateNotifier.value = value;

  /// Returns the effective "today", respecting the debug date override.
  static DateTime get effectiveNow =>
      debugMode && debugDate != null ? debugDate! : DateTime.now();

  // ── Navigation ────────────────────────────────────────────────────────────

  static const List<SidebarModule> _baseModules = [
    SidebarModule(
      title: 'Home',
      icon: Icons.home_filled,
      kind: ModuleKind.home,
    ),
    SidebarModule(
      title: 'Moments',
      icon: Icons.camera,
      kind: ModuleKind.moments,
    ),
    SidebarModule(
      title: 'Diaries',
      icon: Icons.book,
      kind: ModuleKind.posts,
      categoryFilter: 'diaries',
    ),
    SidebarModule(
      title: 'Letters',
      icon: Icons.mail,
      kind: ModuleKind.posts,
      categoryFilter: 'letters',
    ),
    SidebarModule(
      title: 'Gallery',
      icon: Icons.photo_library,
      kind: ModuleKind.gallery,
    ),
  ];

  /// Shows every post regardless of category; debug builds only.
  static const SidebarModule _allPostsModule = SidebarModule(
    title: 'Posts',
    icon: Icons.article,
    kind: ModuleKind.posts,
  );

  static const List<SidebarModule> _debugModules = [
    ..._baseModules,
    _allPostsModule,
  ];

  /// Constant lists, so rebuilding the nav rail allocates nothing.
  static List<SidebarModule> get modules =>
      debugMode ? _debugModules : _baseModules;
}
