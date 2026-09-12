import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/countdown_service.dart';

const String _kSerif = 'Source Han Serif CN';

/// Shows the next anniversary — as a countdown normally, or as a celebration
/// banner when it falls today — plus a one-line peek at the one after it.
class CountdownCard extends StatefulWidget {
  const CountdownCard({super.key});

  @override
  State<CountdownCard> createState() => _CountdownCardState();
}

class _CountdownCardState extends State<CountdownCard> {
  static const _service = CountdownService();

  List<AnniversaryEvent> _events = const [];

  AnniversaryEvent? get _primary => _events.firstOrNull;
  AnniversaryEvent? get _secondary => _events.length > 1 ? _events[1] : null;

  @override
  void initState() {
    super.initState();
    _events = _service.getUpcomingEvents();
    AppConfig.debugDateNotifier.addListener(_refresh);
    AppConfig.debugModeNotifier.addListener(_refresh);
  }

  @override
  void dispose() {
    AppConfig.debugDateNotifier.removeListener(_refresh);
    AppConfig.debugModeNotifier.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() => _events = _service.getUpcomingEvents());

  @override
  Widget build(BuildContext context) {
    final primary = _primary;
    if (primary == null) return const SizedBox.shrink();

    final isToday = primary.isToday;
    final secondary = _secondary;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFB7B2).withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
              gradient: isToday
                  ? const LinearGradient(
                      colors: [Color(0xFFFF9A9E), Color(0xFFFECFEF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
            ),
            child: Column(
              children: [
                if (isToday)
                  _CelebrationContent(event: primary)
                else
                  _CountdownContent(event: primary),
                if (secondary != null) ...[
                  const SizedBox(height: 16),
                  _NextUpChip(
                    event: secondary,
                    onGradient: isToday,
                  ).animate().fadeIn(delay: 400.ms),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension on AnniversaryKind {
  IconData get filledIcon => switch (this) {
    AnniversaryKind.birthday => Icons.cake_rounded,
    AnniversaryKind.valentines ||
    AnniversaryKind.qixi => Icons.favorite_rounded,
    AnniversaryKind.hundredDay ||
    AnniversaryKind.yearly => Icons.card_giftcard_rounded,
  };

  IconData get outlinedIcon => switch (this) {
    AnniversaryKind.birthday => Icons.cake_outlined,
    AnniversaryKind.valentines || AnniversaryKind.qixi => Icons.favorite_border,
    AnniversaryKind.hundredDay ||
    AnniversaryKind.yearly => Icons.event_available,
  };

  String get greeting => switch (this) {
    AnniversaryKind.birthday => 'Happy Birthday to You!',
    AnniversaryKind.valentines => "Happy Valentine's Day!",
    AnniversaryKind.qixi => 'Happy Qixi Festival!',
    AnniversaryKind.hundredDay || AnniversaryKind.yearly => 'Today is',
  };
}

class _CelebrationContent extends StatelessWidget {
  final AnniversaryEvent event;

  const _CelebrationContent({required this.event});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(event.kind.filledIcon, size: 48, color: Colors.white),
        const SizedBox(height: 16),
        Text(
          event.kind.greeting,
          style: const TextStyle(
            fontFamily: _kSerif,
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          event.title,
          style: const TextStyle(
            fontFamily: _kSerif,
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          event.description,
          style: const TextStyle(
            fontFamily: _kSerif,
            color: Colors.white,
            fontSize: 16,
          ),
        ),
      ],
    ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack);
  }
}

class _CountdownContent extends StatelessWidget {
  final AnniversaryEvent event;

  const _CountdownContent({required this.event});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final tint = primary.withValues(alpha: 0.05);

    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
          child: Icon(event.kind.outlinedIcon, color: primary, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'UPCOMING',
                style: TextStyle(
                  fontFamily: _kSerif,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[400],
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                event.title,
                style: TextStyle(
                  fontFamily: _kSerif,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                event.description,
                style: TextStyle(
                  fontFamily: _kSerif,
                  color: primary.withValues(alpha: 0.8),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(
                '${event.daysUntil}',
                style: TextStyle(
                  fontFamily: _kSerif,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: primary,
                  height: 1,
                ),
              ),
              Text(
                'Days',
                style: TextStyle(
                  fontFamily: _kSerif,
                  fontSize: 10,
                  color: primary.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NextUpChip extends StatelessWidget {
  final AnniversaryEvent event;

  /// True when the chip sits on the celebration gradient rather than on white.
  final bool onGradient;

  const _NextUpChip({required this.event, required this.onGradient});

  @override
  Widget build(BuildContext context) {
    final foreground = onGradient ? Colors.white : Colors.grey[600];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: onGradient
            ? Colors.white.withValues(alpha: 0.2)
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.next_week,
            size: 14,
            color: onGradient ? Colors.white : Colors.grey[400],
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Next: ${event.title} in ${event.daysUntil} days',
              style: GoogleFonts.sourceSans3(
                color: foreground,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
