import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qing_space/core/theme/app_theme.dart';
import 'package:qing_space/core/theme/theme_config.dart';
import 'package:qing_space/core/widgets/net_image.dart';
import 'package:qing_space/core/widgets/page_state_widget.dart';
import 'package:qing_space/features/home/widgets/post_card.dart';
import 'package:qing_space/models/post.dart';

Widget host(Widget child) => MaterialApp(
  theme: AppTheme.getTheme(ThemeConfig.themes[AppColorMode.classic]!),
  home: Scaffold(body: child),
);

void main() {
  group('PageStateWidget', () {
    testWidgets('error state shows a retry button that fires', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        host(
          PageStateWidget.error(message: '加载失败', onRetry: () => retried = true),
        ),
      );

      expect(find.text('加载失败'), findsOneWidget);
      await tester.tap(find.text('重试'));
      expect(retried, isTrue);
    });

    testWidgets('empty state has no retry button', (tester) async {
      await tester.pumpWidget(host(PageStateWidget.empty(message: '暂无照片')));
      expect(find.text('暂无照片'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsNothing);
    });
  });

  group('PostCard', () {
    const post = Post(
      title: 'Spring Trip',
      date: '2025-04-29',
      content: '',
      path: 'data/posts/2025-04-29-Spring Trip.md',
      abstract: 'A short summary',
    );

    testWidgets('renders the date rail and forwards taps', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        host(PostCard(post: post, onTap: () => tapped = true)),
      );

      expect(find.text('Spring Trip'), findsOneWidget);
      expect(find.text('A short summary'), findsOneWidget);
      expect(find.text('29'), findsOneWidget);
      expect(find.text('2025'), findsOneWidget);

      await tester.tap(find.text('Spring Trip'));
      expect(tapped, isTrue);
    });

    testWidgets('omits the date rail when the post has no date', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          PostCard(
            post: post.copyWith(date: ''),
            onTap: () {},
          ),
        ),
      );
      expect(find.text('2025'), findsNothing);
      expect(find.text('Spring Trip'), findsOneWidget);
    });
  });

  group('ImageErrorBox', () {
    testWidgets('shows a caption in full mode and hides it when compact', (
      tester,
    ) async {
      await tester.pumpWidget(host(const ImageErrorBox()));
      expect(find.text('图片加载失败'), findsOneWidget);

      await tester.pumpWidget(host(const ImageErrorBox(compact: true)));
      expect(find.text('图片加载失败'), findsNothing);
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    });
  });
}
