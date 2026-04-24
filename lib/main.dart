import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/services/couple_config.dart';
import 'core/services/data_source_manager.dart';
import 'core/services/gitee_client.dart';
import 'core/services/github_client.dart';
import 'core/services/github_service.dart';
import 'core/theme/theme_provider.dart';
import 'features/home/home_page.dart';
import 'features/onboarding/onboarding_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Increase image memory cache to 200 MB to reduce eviction in image-heavy pages.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 200 * 1024 * 1024;
  await GitHubClient.init();
  await GiteeClient.init();
  await DataSourceManager.instance.init();
  await CoupleConfig.init();
  runApp(const QingSpaceApp());
}

class QingSpaceApp extends StatelessWidget {
  const QingSpaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => GithubService()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Qing Space',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.themeData,
            routes: {
              '/home': (_) => const HomePage(),
            },
            home: CoupleConfig.isConfigured
                ? const HomePage()
                : const OnboardingPage(),
          );
        },
      ),
    );
  }
}
