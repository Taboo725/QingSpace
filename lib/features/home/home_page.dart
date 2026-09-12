import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/services/update_service.dart';
import '../gallery/gallery_page.dart';
import '../moment/moment_page.dart';
import '../post/posts_page.dart';
import '../settings/settings_page.dart';
import '../update/update_dialog.dart';
import 'dashboard/dashboard_page.dart';

/// Width at which the bottom nav bar gives way to a side rail.
const double _kDesktopBreakpoint = 600;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final UpdateService _updateService = UpdateService();

  int _selectedIndex = 0;

  /// Bumped to force the active page to rebuild from scratch on refresh.
  int _refreshCount = 0;

  @override
  void initState() {
    super.initState();
    // Deferred to after the first frame so the dashboard paints immediately;
    // the service itself throttles to one network check a day.
    WidgetsBinding.instance.addPostFrameCallback((_) => _offerUpdate());
  }

  @override
  void dispose() {
    _updateService.dispose();
    super.dispose();
  }

  Future<void> _offerUpdate() async {
    final release = await _updateService.checkInBackground();
    if (release == null || !mounted) return;
    await showUpdateDialog(context, release: release, service: _updateService);
  }

  void _refreshCurrentPage() => setState(() => _refreshCount++);

  void _openSettings() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const SettingsPage()),
  );

  Widget _pageFor(SidebarModule module) => switch (module.kind) {
    ModuleKind.home => DashboardPage(
      key: ValueKey('home_${_refreshCount}_${AppConfig.debugDate}'),
    ),
    ModuleKind.moments => MomentsPage(key: ValueKey('moments_$_refreshCount')),
    ModuleKind.gallery => GalleryPage(key: ValueKey('gallery_$_refreshCount')),
    ModuleKind.posts => PostsPage(
      key: ValueKey('${module.title}_$_refreshCount'),
      categoryFilter: module.categoryFilter,
    ),
  };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AppConfig.debugModeNotifier,
        AppConfig.debugDateNotifier,
      ]),
      builder: (context, _) {
        final isDesktop =
            MediaQuery.sizeOf(context).width >= _kDesktopBreakpoint;
        final modules = AppConfig.modules;
        // The module list shrinks when debug mode is turned off, so clamp
        // rather than trusting the stored index.
        final index = _selectedIndex.clamp(0, modules.length - 1);
        final module = modules[index];

        return Scaffold(
          bottomNavigationBar: isDesktop
              ? null
              : _BottomNav(
                  modules: modules,
                  selectedIndex: index,
                  onSelected: (i) => setState(() => _selectedIndex = i),
                ),
          body: Stack(
            children: [
              const _AmbientBackground(),
              Column(
                children: [
                  AppBar(
                    title: Text(
                      module.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        fontSize: 22,
                      ),
                    ),
                    centerTitle: false,
                    elevation: 0,
                    backgroundColor: Colors.transparent,
                    automaticallyImplyLeading: false,
                    actions: [
                      if (isDesktop)
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded),
                          tooltip: 'Refresh',
                          onPressed: _refreshCurrentPage,
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.settings),
                          tooltip: 'Settings',
                          onPressed: _openSettings,
                        ),
                    ],
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        if (isDesktop) ...[
                          _SideRail(
                            modules: modules,
                            selectedIndex: index,
                            onSelected: (i) =>
                                setState(() => _selectedIndex = i),
                            onSettings: _openSettings,
                          ),
                          const VerticalDivider(
                            thickness: 1,
                            width: 1,
                            color: Color(0xFFEEEEEE),
                          ),
                        ],
                        Expanded(child: _pageFor(module)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Navigation ──────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final List<SidebarModule> modules;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _BottomNav({
    required this.modules,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return NavigationBar(
      selectedIndex: selectedIndex,
      backgroundColor: theme.scaffoldBackgroundColor.withValues(alpha: 0.9),
      elevation: 0,
      onDestinationSelected: onSelected,
      destinations: [
        for (final module in modules)
          NavigationDestination(
            icon: Icon(module.icon),
            selectedIcon: Icon(module.icon, color: theme.primaryColor),
            label: module.title,
          ),
      ],
    );
  }
}

class _SideRail extends StatelessWidget {
  final List<SidebarModule> modules;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onSettings;

  const _SideRail({
    required this.modules,
    required this.selectedIndex,
    required this.onSelected,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return NavigationRail(
      backgroundColor: Colors.transparent,
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      destinations: [
        for (final module in modules)
          NavigationRailDestination(
            icon: Icon(module.icon),
            selectedIcon: Icon(module.icon, color: primary),
            label: Text(module.title),
          ),
      ],
      trailing: Expanded(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: IconButton(
              icon: const Icon(Icons.settings),
              color: primary.withValues(alpha: 0.7),
              tooltip: 'Settings',
              onPressed: onSettings,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Background ──────────────────────────────────────────────────────────────

/// Three soft, heavily blurred colour orbs behind the content.
///
/// Held as a `const` widget so navigating between modules never re-runs the
/// blur filters; each orb is additionally isolated in its own repaint boundary.
class _AmbientBackground extends StatelessWidget {
  const _AmbientBackground();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Positioned(
          top: -30,
          left: -30,
          child: _Orb(
            size: 450,
            blur: 120,
            color: Theme.of(context).primaryColor.withValues(alpha: 0.16),
          ),
        ),
        Positioned(
          bottom: -80,
          right: -20,
          child: _Orb(
            size: 520,
            blur: 120,
            color: scheme.secondary.withValues(alpha: 0.16),
          ),
        ),
        Positioned(
          top: 200,
          right: -60,
          child: _Orb(
            size: 250,
            blur: 90,
            color: scheme.secondaryContainer.withValues(alpha: 0.2),
          ),
        ),
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final double blur;
  final Color color;

  const _Orb({required this.size, required this.blur, required this.color});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
