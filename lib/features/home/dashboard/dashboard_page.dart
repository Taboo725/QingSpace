import 'package:flutter/material.dart';
import '../../../core/services/couple_config.dart';
import '../widgets/days_counter.dart';
import '../widgets/countdown_card.dart';
import '../widgets/memory_card.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final startDate = CoupleConfig.startDate;
    return SingleChildScrollView(
      child: Column(
        children: [
          if (startDate != null) DaysCounter(startDate: startDate),
          const SizedBox(height: 16),
          const CountdownCard(),
          const SizedBox(height: 16),
          const MemoryCard(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
