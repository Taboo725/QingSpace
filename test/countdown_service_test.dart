import 'package:flutter_test/flutter_test.dart';
import 'package:qing_space/core/config/app_config.dart';
import 'package:qing_space/core/services/countdown_service.dart';
import 'package:qing_space/core/services/couple_config.dart';
import 'package:qing_space/core/utils/lunar_labels.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const service = CountdownService();

  /// Pins "today" via the debug-date override so the expectations are stable.
  void setToday(DateTime date) {
    AppConfig.debugMode = true;
    AppConfig.debugDate = date;
  }

  Future<void> configureCouple({
    DateTime? startDate,
    int p1BdMonth = 0,
    int p1BdDay = 0,
  }) async {
    SharedPreferences.setMockInitialValues({});
    await CoupleConfig.init();
    if (startDate == null) return;
    await CoupleConfig.save(
      person1Name: 'Ada',
      person2Name: 'Grace',
      startDate: startDate,
      p1BdMonth: p1BdMonth,
      p1BdDay: p1BdDay,
    );
  }

  tearDown(() {
    AppConfig.debugMode = false;
    AppConfig.debugDate = null;
  });

  test('returns nothing until a start date is configured', () async {
    await configureCouple();
    expect(service.getUpcomingEvents(), isEmpty);
  });

  test('sorts events soonest first', () async {
    await configureCouple(startDate: DateTime(2020, 6, 1));
    setToday(DateTime(2026, 1, 10));

    final events = service.getUpcomingEvents();
    expect(events, isNotEmpty);
    final days = events.map((e) => e.daysUntil).toList();
    expect(days, orderedEquals([...days]..sort()));
    expect(days.first, greaterThanOrEqualTo(0));
  });

  test('rolls a passed birthday over to next year', () async {
    await configureCouple(
      startDate: DateTime(2020, 6, 1),
      p1BdMonth: 3,
      p1BdDay: 15,
    );
    setToday(DateTime(2026, 6, 10));

    final birthday = service.getUpcomingEvents().firstWhere(
      (e) => e.title.contains('Ada'),
    );
    expect(birthday.date, DateTime(2027, 3, 15));
    expect(birthday.isToday, isFalse);
  });

  test('flags a birthday falling today', () async {
    await configureCouple(
      startDate: DateTime(2020, 6, 1),
      p1BdMonth: 3,
      p1BdDay: 15,
    );
    setToday(DateTime(2026, 3, 15));

    final birthday = service.getUpcomingEvents().firstWhere(
      (e) => e.title.contains('Ada'),
    );
    expect(birthday.isToday, isTrue);
    expect(birthday.daysUntil, 0);
    expect(birthday.kind, AnniversaryKind.birthday);
  });

  group('hundred-day anniversary', () {
    Future<AnniversaryEvent> nextHundred(DateTime start, DateTime today) async {
      await configureCouple(startDate: start);
      setToday(today);
      return service.getUpcomingEvents().firstWhere(
        (e) => e.kind == AnniversaryKind.hundredDay,
      );
    }

    test('counts the start date as day one', () async {
      // Day 1 is 2026-01-01, so day 100 is 2026-04-10.
      final event = await nextHundred(
        DateTime(2026, 1, 1),
        DateTime(2026, 1, 1),
      );
      expect(event.title, '100-Day Anniversary');
      expect(event.date, DateTime(2026, 4, 10));
    });

    test('lands on today when today is the milestone', () async {
      final event = await nextHundred(
        DateTime(2026, 1, 1),
        DateTime(2026, 4, 10),
      );
      expect(event.title, '100-Day Anniversary');
      expect(event.isToday, isTrue);
    });

    test('advances to the next hundred once one passes', () async {
      final event = await nextHundred(
        DateTime(2026, 1, 1),
        DateTime(2026, 4, 11),
      );
      expect(event.title, '200-Day Anniversary');
    });
  });

  group('LunarLabels', () {
    test('renders a full lunar date', () {
      expect(LunarLabels.full(7, 7), '农历七月初七');
      expect(LunarLabels.full(12, 23), '农历腊月廿三');
    });

    test('falls back to digits for out-of-range values', () {
      expect(LunarLabels.month(13), '13月');
      expect(LunarLabels.day(31), '31日');
    });

    test('compact returns null when unset', () {
      expect(LunarLabels.compact(0, 0), isNull);
      expect(LunarLabels.compact(1, 1), '正月 · 初一');
    });
  });
}
