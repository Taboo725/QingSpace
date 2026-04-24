import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:qing_space/core/config/app_config.dart';

class DaysCounter extends StatelessWidget {
  final DateTime startDate;

  const DaysCounter({super.key, required this.startDate});

  @override
  Widget build(BuildContext context) {
    final now = AppConfig.effectiveNow;
    final days = now.difference(startDate).inDays + 1;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'We have been together for',
            style: GoogleFonts.libreBaskerville(
              fontSize: 14,
              color: Colors.grey[600],
              letterSpacing: 1.2,
            ),
          ).animate().fadeIn(duration: 600.ms),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$days',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                  height: 1.0,
                ),
              ).animate().scale(
                delay: 200.ms,
                duration: 800.ms,
                curve: Curves.easeOutBack,
              ),
              const SizedBox(width: 8),
              Text(
                'Days',
                style: GoogleFonts.libreBaskerville(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ).animate().fadeIn(delay: 600.ms),
            ],
          ),
          const SizedBox(height: 8),
          Container(
                width: 40,
                height: 2,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.secondary.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              )
              .animate()
              .fadeIn(delay: 800.ms)
              .scaleX(alignment: Alignment.centerLeft),
          const SizedBox(height: 16),
          Text(
            'Since ${startDate.year}/${startDate.month.toString().padLeft(2, '0')}/${startDate.day.toString().padLeft(2, '0')}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[400],
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}
