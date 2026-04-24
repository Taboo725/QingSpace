import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qing_space/core/services/countdown_service.dart';
import 'package:qing_space/core/config/app_config.dart';

class CountdownCard extends StatefulWidget {
  const CountdownCard({super.key});

  @override
  State<CountdownCard> createState() => _CountdownCardState();
}

class _CountdownCardState extends State<CountdownCard> {
  late List<AnniversaryEvent> _events;
  late AnniversaryEvent _primaryEvent;
  AnniversaryEvent? _secondaryEvent;

  @override
  void initState() {
    super.initState();
    _refreshEvents();
    AppConfig.debugDateNotifier.addListener(_refreshEventsState);
    AppConfig.debugModeNotifier.addListener(_refreshEventsState);
  }

  @override
  void dispose() {
    AppConfig.debugDateNotifier.removeListener(_refreshEventsState);
    AppConfig.debugModeNotifier.removeListener(_refreshEventsState);
    super.dispose();
  }

  void _refreshEventsState() {
    setState(() {
      _refreshEvents();
    });
  }

  void _refreshEvents() {
    _events = CountdownService().getUpcomingEvents();
    if (_events.isNotEmpty) {
      _primaryEvent = _events.first;
      if (_events.length > 1) {
        _secondaryEvent = _events[1];
      } else {
        _secondaryEvent = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_events.isEmpty) return const SizedBox.shrink();

    // Responsive: On desktop, limit the max width
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              // Primary Event Card
              _buildPrimaryCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryCard() {
    final isToday = _primaryEvent.isToday;

    return Container(
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
          isToday ? _buildCelebrationContent() : _buildCountdownContent(),
          if (_secondaryEvent != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isToday
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.next_week, // Changed from event_upcoming
                    size: 14,
                    color: isToday ? Colors.white : Colors.grey[400],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Next: ${_secondaryEvent!.title} in ${_secondaryEvent!.daysUntil} days",
                    style: GoogleFonts.sourceSans3(
                      color: isToday ? Colors.white : Colors.grey[600],
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 400.ms),
          ],
        ],
      ),
    );
  }

  Widget _buildCelebrationContent() {
    IconData icon;
    // Check if birthday
    if (_primaryEvent.title.contains("Birthday")) {
      icon = Icons.cake_rounded;
    } else if (_primaryEvent.title.contains("Valentine") ||
        _primaryEvent.title.contains("七夕")) {
      // Updated for Chinese
      icon = Icons.favorite_rounded;
    } else if (_primaryEvent.title.contains("Anniversary")) {
      icon = Icons.card_giftcard_rounded;
    } else {
      icon = Icons.celebration_rounded;
    }

    // Customize text for birthday
    String celebrationText = "Today is";
    if (_primaryEvent.title.contains("Birthday")) {
      celebrationText = "Happy Birthday to You!";
    } else if (_primaryEvent.title.contains("七夕")) {
      celebrationText = "Happy Qixi Festival!";
    } else if (_primaryEvent.title.contains("Valentine")) {
      celebrationText = "Happy Valentine's Day!";
    }

    return Column(
      children: [
        Icon(icon, size: 48, color: Colors.white),
        const SizedBox(height: 16),
        Text(
          celebrationText,
          style: const TextStyle(
            fontFamily: 'Source Han Serif CN',
            color: Colors.white, // Increased contrast
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _primaryEvent.title,
          style: const TextStyle(
            fontFamily: 'Source Han Serif CN',
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _primaryEvent.description,
          style: const TextStyle(
            fontFamily: 'Source Han Serif CN',
            color: Colors.white,
            fontSize: 16,
          ),
        ),
      ],
    ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack);
  }

  Widget _buildCountdownContent() {
    IconData icon;
    // Determine icon based on event type
    if (_primaryEvent.title.contains("WQT's Birthday")) {
      // Updated from "Birthday"
      icon = Icons.cake_outlined;
    } else if (_primaryEvent.title.contains("LQL's Birthday")) {
      icon = Icons.cake_outlined;
    } else if (_primaryEvent.title.contains("Valentine") ||
        _primaryEvent.title.contains("七夕")) {
      // Updated for Chinese
      icon = Icons.favorite_border;
    } else if (_primaryEvent.title.contains("Anniversary")) {
      icon = Icons.event_available;
    } else {
      icon = Icons.event;
    }

    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Theme.of(context).primaryColor, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "UPCOMING",
                style: TextStyle(
                  fontFamily: 'Source Han Serif CN',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[400],
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _primaryEvent.title,
                style: TextStyle(
                  fontFamily: 'Source Han Serif CN',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _primaryEvent.description, // Date string
                style: TextStyle(
                  fontFamily: 'Source Han Serif CN',
                  color: Theme.of(
                    context,
                  ).primaryColor.withValues(alpha: 0.8), // Updated deprecation
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
            color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(
                "${_primaryEvent.daysUntil}",
                style: TextStyle(
                  fontFamily: 'Source Han Serif CN',
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                  height: 1,
                ),
              ),
              Text(
                "Days",
                style: TextStyle(
                  fontFamily: 'Source Han Serif CN',
                  fontSize: 10,
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
