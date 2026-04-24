import 'package:lunar/lunar.dart';
import '../config/app_config.dart';
import 'couple_config.dart';

class AnniversaryEvent {
  final String title;
  final DateTime date;
  final String description;
  final bool isToday;

  AnniversaryEvent({
    required this.title,
    required this.date,
    required this.description,
    this.isToday = false,
  });

  int get daysUntil {
    if (isToday) return 0;
    final now = AppConfig.effectiveNow;
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    return d.difference(today).inDays;
  }
}

class CountdownService {
  List<AnniversaryEvent> getUpcomingEvents() {
    final startDate = CoupleConfig.startDate;
    if (startDate == null) return [];

    final now = AppConfig.effectiveNow;
    final today = _dateOnly(now);

    final p1 = CoupleConfig.person1Name;
    final p2 = CoupleConfig.person2Name;

    final events = <AnniversaryEvent>[
      if (CoupleConfig.hasP1Birthday)
        _gregorianEvent(
          p1.isNotEmpty ? "$p1's Birthday" : 'Your Birthday',
          CoupleConfig.p1BdMonth,
          CoupleConfig.p1BdDay,
          '${CoupleConfig.p1BdMonth.toString().padLeft(2, '0')}/${CoupleConfig.p1BdDay.toString().padLeft(2, '0')}',
          today,
        ),
      if (CoupleConfig.hasP2Birthday)
        _gregorianEvent(
          p2.isNotEmpty ? "$p2's Birthday" : "Partner's Birthday",
          CoupleConfig.p2BdMonth,
          CoupleConfig.p2BdDay,
          '${CoupleConfig.p2BdMonth.toString().padLeft(2, '0')}/${CoupleConfig.p2BdDay.toString().padLeft(2, '0')}',
          today,
        ),
      if (CoupleConfig.hasP1LunarBirthday)
        _lunarEvent(
          p1.isNotEmpty ? "$p1's Birthday (Lunar)" : 'Your Birthday (Lunar)',
          CoupleConfig.p1LunarBdMonth,
          CoupleConfig.p1LunarBdDay,
          '农历${_lunarMonthLabel(CoupleConfig.p1LunarBdMonth)}${_lunarDayLabel(CoupleConfig.p1LunarBdDay)}',
          today,
          now,
        ),
      if (CoupleConfig.hasP2LunarBirthday)
        _lunarEvent(
          p2.isNotEmpty ? "$p2's Birthday (Lunar)" : "Partner's Birthday (Lunar)",
          CoupleConfig.p2LunarBdMonth,
          CoupleConfig.p2LunarBdDay,
          '农历${_lunarMonthLabel(CoupleConfig.p2LunarBdMonth)}${_lunarDayLabel(CoupleConfig.p2LunarBdDay)}',
          today,
          now,
        ),
      _gregorianEvent("Valentine's Day", 2, 14, '02/14', today),
      _lunarEvent('七夕', 7, 7, '农历七月初七', today, now),
      _hundredDayEvent(today, startDate),
      _gregorianEvent(
        'Yearly Anniversary',
        startDate.month,
        startDate.day,
        '${startDate.month.toString().padLeft(2, '0')}/${startDate.day.toString().padLeft(2, '0')}',
        today,
      ),
    ];

    events.sort((a, b) => a.daysUntil.compareTo(b.daysUntil));
    return events;
  }

  AnniversaryEvent _gregorianEvent(
    String title,
    int month,
    int day,
    String description,
    DateTime today,
  ) {
    var date = DateTime(today.year, month, day);
    if (date.isBefore(today) && !_sameDay(date, today)) {
      date = DateTime(today.year + 1, month, day);
    }
    return AnniversaryEvent(
      title: title,
      date: date,
      description: description,
      isToday: _sameDay(date, today),
    );
  }

  AnniversaryEvent _lunarEvent(
    String title,
    int lunarMonth,
    int lunarDay,
    String description,
    DateTime today,
    DateTime now,
  ) {
    final lunarYear = Lunar.fromDate(now).getYear();
    DateTime date = _lunarToSolar(lunarYear, lunarMonth, lunarDay);
    if (date.isBefore(today) && !_sameDay(date, today)) {
      date = _lunarToSolar(lunarYear + 1, lunarMonth, lunarDay);
    }
    return AnniversaryEvent(
      title: title,
      date: date,
      description: description,
      isToday: _sameDay(date, today),
    );
  }

  AnniversaryEvent _hundredDayEvent(DateTime today, DateTime startDate) {
    final dayCount = today.difference(_dateOnly(startDate)).inDays + 1;
    final nextFactor = (dayCount / 100).ceil().clamp(1, 9999);
    final targetDay = nextFactor * 100;
    final date = startDate.add(Duration(days: targetDay - 1));
    return AnniversaryEvent(
      title: '$targetDay-Day Anniversary',
      date: date,
      description: 'Celebrating $targetDay days',
      isToday: _sameDay(date, today),
    );
  }

  DateTime _lunarToSolar(int year, int month, int day) {
    final solar = Lunar.fromYmd(year, month, day).getSolar();
    return DateTime(solar.getYear(), solar.getMonth(), solar.getDay());
  }

  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static const _lunarMonths = ['', '正', '二', '三', '四', '五', '六', '七', '八', '九', '十', '冬', '腊'];
  static const _lunarDays = ['', '初一', '初二', '初三', '初四', '初五', '初六', '初七', '初八', '初九', '初十',
    '十一', '十二', '十三', '十四', '十五', '十六', '十七', '十八', '十九', '二十',
    '廿一', '廿二', '廿三', '廿四', '廿五', '廿六', '廿七', '廿八', '廿九', '三十'];

  static String _lunarMonthLabel(int m) =>
      (m >= 1 && m <= 12) ? '${_lunarMonths[m]}月' : '$m月';
  static String _lunarDayLabel(int d) =>
      (d >= 1 && d <= 30) ? _lunarDays[d] : '$d日';
}
