import 'package:shared_preferences/shared_preferences.dart';

/// Stores couple profile data (names, start date, birthdays) in SharedPreferences.
/// Call [CoupleConfig.init] at app startup before reading any values.
class CoupleConfig {
  static const _p1NameKey = 'couple_p1_name';
  static const _p2NameKey = 'couple_p2_name';
  static const _p1BdYearKey = 'couple_p1_bd_year';
  static const _p1BdMonthKey = 'couple_p1_bd_month';
  static const _p1BdDayKey = 'couple_p1_bd_day';
  static const _p2BdYearKey = 'couple_p2_bd_year';
  static const _p2BdMonthKey = 'couple_p2_bd_month';
  static const _p2BdDayKey = 'couple_p2_bd_day';
  static const _p1LunarBdMonthKey = 'couple_p1_lunar_bd_month';
  static const _p1LunarBdDayKey = 'couple_p1_lunar_bd_day';
  static const _p2LunarBdMonthKey = 'couple_p2_lunar_bd_month';
  static const _p2LunarBdDayKey = 'couple_p2_lunar_bd_day';
  static const _startYearKey = 'couple_start_year';
  static const _startMonthKey = 'couple_start_month';
  static const _startDayKey = 'couple_start_day';

  static String _p1Name = '';
  static String _p2Name = '';
  static int _p1BdYear = 0;
  static int _p1BdMonth = 0;
  static int _p1BdDay = 0;
  static int _p2BdYear = 0;
  static int _p2BdMonth = 0;
  static int _p2BdDay = 0;
  static int _p1LunarBdMonth = 0;
  static int _p1LunarBdDay = 0;
  static int _p2LunarBdMonth = 0;
  static int _p2LunarBdDay = 0;
  static int _startYear = 0;
  static int _startMonth = 0;
  static int _startDay = 0;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _p1Name = prefs.getString(_p1NameKey) ?? '';
    _p2Name = prefs.getString(_p2NameKey) ?? '';
    _p1BdYear = prefs.getInt(_p1BdYearKey) ?? 0;
    _p1BdMonth = prefs.getInt(_p1BdMonthKey) ?? 0;
    _p1BdDay = prefs.getInt(_p1BdDayKey) ?? 0;
    _p2BdYear = prefs.getInt(_p2BdYearKey) ?? 0;
    _p2BdMonth = prefs.getInt(_p2BdMonthKey) ?? 0;
    _p2BdDay = prefs.getInt(_p2BdDayKey) ?? 0;
    _p1LunarBdMonth = prefs.getInt(_p1LunarBdMonthKey) ?? 0;
    _p1LunarBdDay = prefs.getInt(_p1LunarBdDayKey) ?? 0;
    _p2LunarBdMonth = prefs.getInt(_p2LunarBdMonthKey) ?? 0;
    _p2LunarBdDay = prefs.getInt(_p2LunarBdDayKey) ?? 0;
    _startYear = prefs.getInt(_startYearKey) ?? 0;
    _startMonth = prefs.getInt(_startMonthKey) ?? 0;
    _startDay = prefs.getInt(_startDayKey) ?? 0;
  }

  static String get person1Name => _p1Name;
  static String get person2Name => _p2Name;

  static DateTime? get startDate =>
      _startYear > 0 ? DateTime(_startYear, _startMonth, _startDay) : null;

  static bool get hasP1Birthday => _p1BdMonth > 0 && _p1BdDay > 0;
  static bool get hasP2Birthday => _p2BdMonth > 0 && _p2BdDay > 0;
  static bool get hasP1LunarBirthday => _p1LunarBdMonth > 0 && _p1LunarBdDay > 0;
  static bool get hasP2LunarBirthday => _p2LunarBdMonth > 0 && _p2LunarBdDay > 0;

  static int get p1BdYear => _p1BdYear;
  static int get p1BdMonth => _p1BdMonth;
  static int get p1BdDay => _p1BdDay;
  static int get p2BdYear => _p2BdYear;
  static int get p2BdMonth => _p2BdMonth;
  static int get p2BdDay => _p2BdDay;
  static int get p1LunarBdMonth => _p1LunarBdMonth;
  static int get p1LunarBdDay => _p1LunarBdDay;
  static int get p2LunarBdMonth => _p2LunarBdMonth;
  static int get p2LunarBdDay => _p2LunarBdDay;

  /// True once the start date has been set — used to decide whether to show onboarding.
  static bool get isConfigured => _startYear > 0;

  static Future<void> save({
    required String person1Name,
    required String person2Name,
    required DateTime startDate,
    int p1BdYear = 0,
    int p1BdMonth = 0,
    int p1BdDay = 0,
    int p2BdYear = 0,
    int p2BdMonth = 0,
    int p2BdDay = 0,
    int p1LunarBdMonth = 0,
    int p1LunarBdDay = 0,
    int p2LunarBdMonth = 0,
    int p2LunarBdDay = 0,
  }) async {
    _p1Name = person1Name;
    _p2Name = person2Name;
    _startYear = startDate.year;
    _startMonth = startDate.month;
    _startDay = startDate.day;
    _p1BdYear = p1BdYear;
    _p1BdMonth = p1BdMonth;
    _p1BdDay = p1BdDay;
    _p2BdYear = p2BdYear;
    _p2BdMonth = p2BdMonth;
    _p2BdDay = p2BdDay;
    _p1LunarBdMonth = p1LunarBdMonth;
    _p1LunarBdDay = p1LunarBdDay;
    _p2LunarBdMonth = p2LunarBdMonth;
    _p2LunarBdDay = p2LunarBdDay;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_p1NameKey, person1Name);
    await prefs.setString(_p2NameKey, person2Name);
    await prefs.setInt(_startYearKey, startDate.year);
    await prefs.setInt(_startMonthKey, startDate.month);
    await prefs.setInt(_startDayKey, startDate.day);
    await prefs.setInt(_p1BdYearKey, p1BdYear);
    await prefs.setInt(_p1BdMonthKey, p1BdMonth);
    await prefs.setInt(_p1BdDayKey, p1BdDay);
    await prefs.setInt(_p2BdYearKey, p2BdYear);
    await prefs.setInt(_p2BdMonthKey, p2BdMonth);
    await prefs.setInt(_p2BdDayKey, p2BdDay);
    await prefs.setInt(_p1LunarBdMonthKey, p1LunarBdMonth);
    await prefs.setInt(_p1LunarBdDayKey, p1LunarBdDay);
    await prefs.setInt(_p2LunarBdMonthKey, p2LunarBdMonth);
    await prefs.setInt(_p2LunarBdDayKey, p2LunarBdDay);
  }
}
