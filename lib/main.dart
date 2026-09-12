import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/config/app_info.dart';
import 'core/services/couple_config.dart';
import 'core/services/data_source_manager.dart';
import 'core/services/gitee_client.dart';
import 'core/services/github_client.dart';
import 'core/services/github_service.dart';
import 'core/theme/theme_provider.dart';
import 'features/home/home_page.dart';
import 'features/onboarding/onboarding_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Raise the image cache above the 100 MB default: the gallery and post pages
  // hold many decoded photos on screen at once, and eviction there costs a
  // visible re-decode flash. Call sites downscale via memCacheWidth, so this
  // budget holds roughly a hundred thumbnails rather than a handful of originals.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 200 * 1024 * 1024;

  // These all read local state only — SharedPreferences or the platform
  // package metadata — so startup is not gated on connectivity.
  final theme = ThemeProvider();
  await Future.wait([
    GitHubClient.init(),
    GiteeClient.init(),
    CoupleConfig.init(),
    AppInfo.init(),
    theme.load(),
  ]);
  // Source probing continues in the background; readers await it via
  // DataSourceManager.ready before their first request.
  await DataSourceManager.instance.init();

  runApp(QingSpaceApp(themeProvider: theme));
}

class QingSpaceApp extends StatelessWidget {
  final ThemeProvider themeProvider;

  const QingSpaceApp({super.key, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => GithubService()),
        ChangeNotifierProvider.value(value: themeProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, child) => MaterialApp(
          title: 'Qing Space',
          debugShowCheckedModeBanner: false,
          theme: theme.themeData,
          routes: {'/home': (_) => const HomePage()},
          home: child,
        ),
        child: CoupleConfig.isConfigured
            ? const HomePage()
            : const OnboardingPage(),
      ),
    );
  }
}
