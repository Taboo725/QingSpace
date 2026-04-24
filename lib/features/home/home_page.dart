import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'dashboard/dashboard_page.dart';
import '../post/posts_page.dart';
import '../moment/moment_page.dart';
import '../gallery/gallery_page.dart';
import '../settings/settings_page.dart';
import '../../core/config/app_config.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  int _refreshCount = 0;

  void _refreshCurrentPage() {
    setState(() => _refreshCount++);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(
        [AppConfig.debugModeNotifier, AppConfig.debugDateNotifier]
            as List<Listenable>,
      ),
      builder: (context, child) {
        final isDesktop = MediaQuery.sizeOf(context).width >= 600;

        final safeIndex =
            (_selectedIndex >= 0 && _selectedIndex < AppConfig.modules.length)
            ? _selectedIndex
            : 0;
        final currentModule = AppConfig.modules[safeIndex];
        final title = currentModule.title;

        Widget currentPage;
        if (currentModule.isHome) {
          currentPage = DashboardPage(
            key: ValueKey('home_${_refreshCount}_${AppConfig.debugDate}'),
          );
        } else if (currentModule.title == 'Moments') {
          currentPage = MomentsPage(key: ValueKey('moments_$_refreshCount'));
        } else if (currentModule.title == 'Gallery') {
          currentPage = GalleryPage(key: ValueKey('gallery_$_refreshCount'));
        } else {
          currentPage = PostsPage(
            key: ValueKey('${currentModule.title}_$_refreshCount'),
            categoryFilter: currentModule.categoryFilter,
          );
        }

        return Scaffold(
          bottomNavigationBar: !isDesktop
              ? NavigationBar(
                  selectedIndex: safeIndex,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor
                      .withValues(alpha: 0.9),
                  elevation: 0,
                  onDestinationSelected: (int index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  destinations: AppConfig.modules.map((module) {
                    return NavigationDestination(
                      icon: Icon(_getIcon(module.iconName)),
                      selectedIcon: Icon(
                        _getIcon(module.iconName),
                        color: Theme.of(context).primaryColor,
                      ),
                      label: module.title,
                    );
                  }).toList(),
                )
              : null,
          body: Stack(
            children: [
              // Diffuse Orb 1 - Top Left (Primary Color)
              Positioned(
                top: -30,
                left: -30,
                child: RepaintBoundary(
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
                    child: Container(
                      width: 450,
                      height: 450,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).primaryColor.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),

              // Diffuse Orb 2 - Bottom Right (Secondary Color)
              Positioned(
                bottom: -80,
                right: -20,
                child: RepaintBoundary(
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
                    child: Container(
                      width: 520,
                      height: 520,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.secondary.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),

              // Diffuse Orb 3 - Middle Right Accent (Atmospheric)
              Positioned(
                top: 200,
                right: -60,
                child: RepaintBoundary(
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.secondaryContainer.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),

              // Main Content Layer
              Column(
                children: [
                  AppBar(
                    title: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        fontSize: 22,
                      ),
                    ),
                    centerTitle: false,
                    elevation: 0,
                    backgroundColor: Colors.transparent,
                    actions: [
                      if (isDesktop)
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded),
                          tooltip: 'Refresh',
                          onPressed: _refreshCurrentPage,
                        ),
                      if (!isDesktop)
                        IconButton(
                          icon: const Icon(Icons.settings),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SettingsPage(),
                              ),
                            );
                          },
                        ),
                    ],
                    automaticallyImplyLeading: false,
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        if (isDesktop)
                          NavigationRail(
                            backgroundColor: Colors.transparent,
                            selectedIndex: safeIndex,
                            onDestinationSelected: (int index) {
                              setState(() {
                                _selectedIndex = index;
                              });
                            },
                            destinations: AppConfig.modules.map((module) {
                              return NavigationRailDestination(
                                icon: Icon(_getIcon(module.iconName)),
                                selectedIcon: Icon(
                                  _getIcon(module.iconName),
                                  color: Theme.of(context).primaryColor,
                                ),
                                label: Text(module.title),
                              );
                            }).toList(),
                            trailing: Expanded(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 20.0),
                                  child: IconButton(
                                    icon: const Icon(Icons.settings),
                                    color: Theme.of(
                                      context,
                                    ).primaryColor.withValues(alpha: 0.7),
                                    tooltip: 'Settings',
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const SettingsPage(),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (isDesktop)
                          const VerticalDivider(
                            thickness: 1,
                            width: 1,
                            color: Color(0xFFEEEEEE),
                          ),
                        Expanded(child: currentPage),
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

  IconData _getIcon(String name) {
    switch (name) {
      case 'home':
        return Icons.home_filled;
      case 'gallery':
        return Icons.photo_library;
      case 'timeline':
        return Icons.camera;
      case 'all_inclusive':
        return Icons.article;
      case 'book':
        return Icons.book;
      case 'mail':
        return Icons.mail;
      default:
        return Icons.circle;
    }
  }
}
