/// Chinese names for lunar months and days, shared by the birthday picker and
/// the countdown descriptions so the two can never disagree.
class LunarLabels {
  const LunarLabels._();

  static const int monthCount = 12;
  static const int dayCount = 30;

  /// 1-based month names: `months[1] == '正'`.
  // dart format off
  static const List<String> months = [
    '', '正', '二', '三', '四', '五', '六', '七', '八', '九', '十', '冬', '腊'
  ];

  /// 1-based day names: `days[1] == '初一'`.
  static const List<String> days = [
    '', '初一', '初二', '初三', '初四', '初五', '初六', '初七', '初八', '初九', '初十',
    '十一', '十二', '十三', '十四', '十五', '十六', '十七', '十八', '十九', '二十',
    '廿一', '廿二', '廿三', '廿四', '廿五', '廿六', '廿七', '廿八', '廿九', '三十'
  ];
  // dart format on

  static String month(int m) =>
      (m >= 1 && m <= monthCount) ? '${months[m]}月' : '$m月';

  static String day(int d) => (d >= 1 && d <= dayCount) ? days[d] : '$d日';

  /// `农历腊月廿三`
  static String full(int m, int d) => '农历${month(m)}${day(d)}';

  /// `腊月 · 廿三`, or null when either component is unset.
  static String? compact(int m, int d) =>
      (m >= 1 && d >= 1) ? '${month(m)} · ${day(d)}' : null;
}
