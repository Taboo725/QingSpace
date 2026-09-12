import 'package:flutter/material.dart';

/// Consistent full-page state indicator for loading, error, and empty states.
class PageStateWidget extends StatelessWidget {
  final IconData icon;
  final String message;
  final VoidCallback? onRetry;

  const PageStateWidget({
    super.key,
    required this.icon,
    required this.message,
    this.onRetry,
  });

  static Widget error({
    String message = '加载失败',
    VoidCallback? onRetry,
    Key? key,
  }) => PageStateWidget(
    key: key,
    icon: Icons.cloud_off_rounded,
    message: message,
    onRetry: onRetry,
  );

  static Widget empty({
    required String message,
    IconData icon = Icons.inbox_rounded,
    Key? key,
  }) => PageStateWidget(key: key, icon: icon, message: message);

  /// Wraps [state] in a scrollable so it can sit inside a [RefreshIndicator]
  /// and still respond to a pull gesture on an otherwise empty page.
  static Widget pullToRefreshBody(BuildContext context, Widget state) =>
      ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.5,
            child: Center(child: state),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(
      context,
    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 44, color: color),
        const SizedBox(height: 12),
        Text(
          message,
          style: TextStyle(fontSize: 14, color: color, letterSpacing: 0.2),
          textAlign: TextAlign.center,
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('重试'),
          ),
        ],
      ],
    );
  }
}
