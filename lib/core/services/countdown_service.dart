import 'package:lunar/lunar.dart';
import '../config/app_config.dart';
import '../utils/lunar_labels.dart';
import 'couple_config.dart';

/// What an upcoming event represents, so the UI can pick an icon and greeting
/// without pattern-matching on the display title.
enum AnniversaryKind { birthday, valentines, qixi, hundredDay, yearly }

class AnniversaryEvent {
  final AnniversaryKind kind;
  final String title;
  final DateTime date;
  final String description;
  final bool isToday;

  const AnniversaryEvent({
    required this.kind,
    required this.title,
    required this.date,
    required this.description,
    this.isToday = false,
  });

  int get daysUntil {
    if (isToday) return 0;
    final today = _dateOnly(AppConfig.effectiveNow);
    return _dateOnly(date).difference(today).inDays;
  }
}

/// Builds the couple's upcoming anniversaries, birthdays and festivals,
/// soonest first. Returns an empty list until a start date has been set.
class CountdownService {
  const CountdownService();

  List<AnniversaryEvent> getUpcomingEvents() {
    final startDate = CoupleConfig.startDate;
    if (startDate == null) return const [];

    final now = AppConfig.effectiveNow;
    final today = _dateOnly(now);

    final p1 = CoupleConfig.person1Name;
    final p2 = CoupleConfig.person2Name;

    final events = <AnniversaryEvent>[
      if (CoupleConfig.hasP1Birthday)
        _gregorian(
          kind: AnniversaryKind.birthday,
          title: p1.isNotEmpty ? "$p1's Birthday" : 'Your Birthday',
          month: CoupleConfig.p1BdMonth,
          day: CoupleConfig.p1BdDay,
          description: _mmdd(CoupleConfig.p1BdMonth, CoupleConfig.p1BdDay),
          today: today,
        ),
      if (CoupleConfig.hasP2Birthday)
        _gregorian(
          kind: AnniversaryKind.birthday,
          title: p2.isNotEmpty ? "$p2's Birthday" : "Partner's Birthday",
          month: CoupleConfig.p2BdMonth,
          day: CoupleConfig.p2BdDay,
          description: _mmdd(CoupleConfig.p2BdMonth, CoupleConfig.p2BdDay),
          today: today,
        ),
      if (CoupleConfig.hasP1LunarBirthday)
        _lunar(
          kind: AnniversaryKind.birthday,
          title: p1.isNotEmpty
              ? "$p1's Birthday (Lunar)"
              : 'Your Birthday (Lunar)',
          lunarMonth: CoupleConfig.p1LunarBdMonth,
          lunarDay: CoupleConfig.p1LunarBdDay,
          description: LunarLabels.full(
            CoupleConfig.p1LunarBdMonth,
            CoupleConfig.p1LunarBdDay,
          ),
          today: today,
          now: now,
        ),
      if (CoupleConfig.hasP2LunarBirthday)
        _lunar(
          kind: AnniversaryKind.birthday,
          title: p2.isNotEmpty
              ? "$p2's Birthday (Lunar)"
              : "Partner's Birthday (Lunar)",
          lunarMonth: CoupleConfig.p2LunarBdMonth,
          lunarDay: CoupleConfig.p2LunarBdDay,
          description: LunarLabels.full(
            CoupleConfig.p2LunarBdMonth,
            CoupleConfig.p2LunarBdDay,
          ),
          today: today,
          now: now,
        ),
      _gregorian(
        kind: AnniversaryKind.valentines,
        title: "Valentine's Day",
        month: 2,
        day: 14,
        description: '02/14',
        today: today,
      ),
      _lunar(
        kind: AnniversaryKind.qixi,
        title: '七夕',
        lunarMonth: 7,
        lunarDay: 7,
        description: '农历七月初七',
        today: today,
        now: now,
      ),
      _hundredDay(today, startDate),
      _gregorian(
        kind: AnniversaryKind.yearly,
        title: 'Yearly Anniversary',
        month: startDate.month,
        day: startDate.day,
        description: _mmdd(startDate.month, startDate.day),
        today: today,
      ),
    ];

    events.sort((a, b) => a.daysUntil.compareTo(b.daysUntil));
    return events;
  }

  AnniversaryEvent _gregorian({
    required AnniversaryKind kind,
    required String title,
    required int month,
    required int day,
    required String description,
    required DateTime today,
  }) {
    var date = DateTime(today.year, month, day);
    if (date.isBefore(today)) date = DateTime(today.year + 1, month, day);
    return AnniversaryEvent(
      kind: kind,
      title: title,
      date: date,
      description: description,
      isToday: date == today,
    );
  }

  AnniversaryEvent _lunar({
    required AnniversaryKind kind,
    required String title,
    required int lunarMonth,
    required int lunarDay,
    required String description,
    required DateTime today,
    required DateTime now,
  }) {
    final lunarYear = Lunar.fromDate(now).getYear();
    var date = _lunarToSolar(lunarYear, lunarMonth, lunarDay);
    if (date.isBefore(today)) {
      date = _lunarToSolar(lunarYear + 1, lunarMonth, lunarDay);
    }
    return AnniversaryEvent(
      kind: kind,
      title: title,
      date: date,
      description: description,
      isToday: date == today,
    );
  }

  /// The next round-hundred day count since [startDate], counting day one as
  /// the start date itself.
  AnniversaryEvent _hundredDay(DateTime today, DateTime startDate) {
    final dayCount = today.difference(_dateOnly(startDate)).inDays + 1;
    final targetDay = (dayCount / 100).ceil().clamp(1, 9999) * 100;
    // Calendar arithmetic rather than Duration, so a DST boundary cannot
    // shift the result back by an hour and land on the previous day.
    final date = DateTime(
      startDate.year,
      startDate.month,
      startDate.day + targetDay - 1,
    );
    return AnniversaryEvent(
      kind: AnniversaryKind.hundredDay,
      title: '$targetDay-Day Anniversary',
      date: date,
      description: 'Celebrating $targetDay days',
      isToday: date == today,
    );
  }

  static DateTime _lunarToSolar(int year, int month, int day) {
    final solar = Lunar.fromYmd(year, month, day).getSolar();
    return DateTime(solar.getYear(), solar.getMonth(), solar.getDay());
  }

  static String _mmdd(int month, int day) =>
      '${month.toString().padLeft(2, '0')}/${day.toString().padLeft(2, '0')}';
}

DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
