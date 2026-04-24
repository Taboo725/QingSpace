import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/couple_config.dart';

class OnboardingPage extends StatefulWidget {
  final bool isEditing;
  const OnboardingPage({super.key, this.isEditing = false});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _formKey = GlobalKey<FormState>();

  final _p1NameController = TextEditingController();
  final _p2NameController = TextEditingController();

  DateTime? _startDate;
  DateTime? _p1Birthday;
  DateTime? _p2Birthday;

  int _p1LunarMonth = 0;
  int _p1LunarDay = 0;
  int _p2LunarMonth = 0;
  int _p2LunarDay = 0;
  bool _showLunar = false;

  bool _saving = false;

  static const _lunarMonths = ['正', '二', '三', '四', '五', '六', '七', '八', '九', '十', '冬', '腊'];
  static const _lunarDays = [
    '初一', '初二', '初三', '初四', '初五', '初六', '初七', '初八', '初九', '初十',
    '十一', '十二', '十三', '十四', '十五', '十六', '十七', '十八', '十九', '二十',
    '廿一', '廿二', '廿三', '廿四', '廿五', '廿六', '廿七', '廿八', '廿九', '三十',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.isEditing || CoupleConfig.isConfigured) {
      _p1NameController.text = CoupleConfig.person1Name;
      _p2NameController.text = CoupleConfig.person2Name;
      _startDate = CoupleConfig.startDate;
      if (CoupleConfig.hasP1Birthday) {
        final year = CoupleConfig.p1BdYear > 0 ? CoupleConfig.p1BdYear : 2000;
        _p1Birthday = DateTime(year, CoupleConfig.p1BdMonth, CoupleConfig.p1BdDay);
      }
      if (CoupleConfig.hasP2Birthday) {
        final year = CoupleConfig.p2BdYear > 0 ? CoupleConfig.p2BdYear : 2000;
        _p2Birthday = DateTime(year, CoupleConfig.p2BdMonth, CoupleConfig.p2BdDay);
      }
      if (CoupleConfig.hasP1LunarBirthday) {
        _p1LunarMonth = CoupleConfig.p1LunarBdMonth;
        _p1LunarDay = CoupleConfig.p1LunarBdDay;
        _showLunar = true;
      }
      if (CoupleConfig.hasP2LunarBirthday) {
        _p2LunarMonth = CoupleConfig.p2LunarBdMonth;
        _p2LunarDay = CoupleConfig.p2LunarBdDay;
        _showLunar = true;
      }
    }
  }

  @override
  void dispose() {
    _p1NameController.dispose();
    _p2NameController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'Select your start date',
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickBirthday({required bool isPerson1}) async {
    final existing = isPerson1 ? _p1Birthday : _p2Birthday;
    final now = DateTime.now();
    final initial = existing ?? DateTime(now.year - 25, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1920, 1, 1),
      lastDate: now,
      helpText: 'Select birthday',
    );
    if (picked != null) {
      setState(() {
        if (isPerson1) {
          _p1Birthday = picked;
        } else {
          _p2Birthday = picked;
        }
      });
    }
  }

  Future<void> _pickLunarBirthday({required bool isPerson1}) async {
    var tempMonth = isPerson1
        ? (_p1LunarMonth > 0 ? _p1LunarMonth : 1)
        : (_p2LunarMonth > 0 ? _p2LunarMonth : 1);
    var tempDay = isPerson1
        ? (_p1LunarDay > 0 ? _p1LunarDay : 1)
        : (_p2LunarDay > 0 ? _p2LunarDay : 1);

    final monthController = FixedExtentScrollController(initialItem: tempMonth - 1);
    final dayController = FixedExtentScrollController(initialItem: tempDay - 1);

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final color = Theme.of(context).primaryColor;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                children: [
                  Text(
                    '选择农历生日',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        if (isPerson1) {
                          _p1LunarMonth = tempMonth;
                          _p1LunarDay = tempDay;
                        } else {
                          _p2LunarMonth = tempMonth;
                          _p2LunarDay = tempDay;
                        }
                      });
                      Navigator.pop(ctx);
                    },
                    child: Text(
                      '确认',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            SizedBox(
              height: 220,
              child: Stack(
                children: [
                  // selection highlight
                  Center(
                    child: Container(
                      height: 44,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: ListWheelScrollView.useDelegate(
                          controller: monthController,
                          itemExtent: 44,
                          perspective: 0.003,
                          diameterRatio: 1.6,
                          physics: const FixedExtentScrollPhysics(),
                          onSelectedItemChanged: (i) => tempMonth = i + 1,
                          childDelegate: ListWheelChildBuilderDelegate(
                            childCount: 12,
                            builder: (_, i) => Center(
                              child: Text(
                                '${_lunarMonths[i]}月',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListWheelScrollView.useDelegate(
                          controller: dayController,
                          itemExtent: 44,
                          perspective: 0.003,
                          diameterRatio: 1.6,
                          physics: const FixedExtentScrollPhysics(),
                          onSelectedItemChanged: (i) => tempDay = i + 1,
                          childDelegate: ListWheelChildBuilderDelegate(
                            childCount: 30,
                            builder: (_, i) => Center(
                              child: Text(
                                _lunarDays[i],
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );

    monthController.dispose();
    dayController.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your start date')),
      );
      return;
    }
    setState(() => _saving = true);
    await CoupleConfig.save(
      person1Name: _p1NameController.text.trim(),
      person2Name: _p2NameController.text.trim(),
      startDate: _startDate!,
      p1BdYear: _p1Birthday?.year ?? 0,
      p1BdMonth: _p1Birthday?.month ?? 0,
      p1BdDay: _p1Birthday?.day ?? 0,
      p2BdYear: _p2Birthday?.year ?? 0,
      p2BdMonth: _p2Birthday?.month ?? 0,
      p2BdDay: _p2Birthday?.day ?? 0,
      p1LunarBdMonth: _p1LunarMonth,
      p1LunarBdDay: _p1LunarDay,
      p2LunarBdMonth: _p2LunarMonth,
      p2LunarBdDay: _p2LunarDay,
    );
    if (!mounted) return;
    if (widget.isEditing) {
      Navigator.pop(context, true);
    } else {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  String _formatBirthday(DateTime? d) {
    if (d == null) return 'Not set';
    return '${d.year} / ${d.month.toString().padLeft(2, '0')} / ${d.day.toString().padLeft(2, '0')}';
  }

  String _formatLunarDate(int month, int day) {
    if (month == 0 || day == 0) return 'Not set';
    return '${_lunarMonths[month - 1]}月 · ${_lunarDays[day - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
                children: [
                  // Header
                  Icon(Icons.favorite_rounded, size: 40, color: primaryColor),
                  const SizedBox(height: 16),
                  Text(
                    widget.isEditing ? 'Your Profile' : 'Welcome',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.isEditing
                        ? 'Update your couple profile'
                        : 'Let\'s begin your story',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.libreBaskerville(
                      fontSize: 14,
                      color: Colors.grey[500],
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Names
                  _sectionLabel('Your Names'),
                  const SizedBox(height: 12),
                  _nameField(_p1NameController, 'Your name', 'e.g. Alex'),
                  const SizedBox(height: 12),
                  _nameField(_p2NameController, 'Partner\'s name', 'e.g. Jordan'),
                  const SizedBox(height: 32),

                  // Start date
                  _sectionLabel('Your Start Date'),
                  const SizedBox(height: 4),
                  Text(
                    'The day your story began',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 12),
                  _dateButton(
                    label: _startDate == null
                        ? 'Select date'
                        : '${_startDate!.year} / ${_startDate!.month.toString().padLeft(2, '0')} / ${_startDate!.day.toString().padLeft(2, '0')}',
                    icon: Icons.calendar_today_rounded,
                    isSet: _startDate != null,
                    onTap: _pickStartDate,
                  ),
                  const SizedBox(height: 32),

                  // Birthdays
                  _sectionLabel('Birthdays  ·  optional'),
                  const SizedBox(height: 12),
                  _birthdayRow(
                    name: _p1NameController.text.trim().isEmpty
                        ? 'Yours'
                        : _p1NameController.text.trim(),
                    date: _p1Birthday,
                    onTap: () => _pickBirthday(isPerson1: true),
                    onClear: _p1Birthday != null
                        ? () => setState(() => _p1Birthday = null)
                        : null,
                  ),
                  const SizedBox(height: 10),
                  _birthdayRow(
                    name: _p2NameController.text.trim().isEmpty
                        ? 'Partner\'s'
                        : _p2NameController.text.trim(),
                    date: _p2Birthday,
                    onTap: () => _pickBirthday(isPerson1: false),
                    onClear: _p2Birthday != null
                        ? () => setState(() => _p2Birthday = null)
                        : null,
                  ),
                  const SizedBox(height: 24),

                  // Lunar birthdays (expandable)
                  GestureDetector(
                    onTap: () => setState(() => _showLunar = !_showLunar),
                    child: Row(
                      children: [
                        Icon(
                          _showLunar
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 16,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Lunar birthdays  ·  optional',
                          style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  ),
                  if (_showLunar) ...[
                    const SizedBox(height: 12),
                    _lunarRow(
                      name: _p1NameController.text.trim().isEmpty
                          ? 'Yours'
                          : _p1NameController.text.trim(),
                      month: _p1LunarMonth,
                      day: _p1LunarDay,
                      onTap: () => _pickLunarBirthday(isPerson1: true),
                      onClear: (_p1LunarMonth > 0 || _p1LunarDay > 0)
                          ? () => setState(() {
                                _p1LunarMonth = 0;
                                _p1LunarDay = 0;
                              })
                          : null,
                    ),
                    const SizedBox(height: 10),
                    _lunarRow(
                      name: _p2NameController.text.trim().isEmpty
                          ? 'Partner\'s'
                          : _p2NameController.text.trim(),
                      month: _p2LunarMonth,
                      day: _p2LunarDay,
                      onTap: () => _pickLunarBirthday(isPerson1: false),
                      onClear: (_p2LunarMonth > 0 || _p2LunarDay > 0)
                          ? () => setState(() {
                                _p2LunarMonth = 0;
                                _p2LunarDay = 0;
                              })
                          : null,
                    ),
                  ],
                  const SizedBox(height: 48),

                  // Submit
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            widget.isEditing ? 'Save' : 'Begin Our Story',
                            style: GoogleFonts.libreBaskerville(
                              fontSize: 15,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),

                  if (widget.isEditing) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.5,
        color: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _nameField(
    TextEditingController controller,
    String label,
    String hint,
  ) {
    return TextFormField(
      controller: controller,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _dateButton({
    required String label,
    required IconData icon,
    required bool isSet,
    required VoidCallback onTap,
  }) {
    final color = Theme.of(context).primaryColor;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: isSet ? color : Colors.grey[400]),
      label: Text(
        label,
        style: TextStyle(
          color: isSet ? color : Colors.grey[400],
          fontWeight: isSet ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        side: BorderSide(
          color: isSet ? color.withValues(alpha: 0.5) : Colors.grey.withValues(alpha: 0.3),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        alignment: Alignment.centerLeft,
      ),
    );
  }

  Widget _birthdayRow({
    required String name,
    required DateTime? date,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    final color = Theme.of(context).primaryColor;
    final isSet = date != null;
    return Row(
      children: [
        Expanded(
          child: Text(
            name,
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ),
        if (onClear != null) ...[
          GestureDetector(
            onTap: onClear,
            child: Icon(Icons.close, size: 14, color: Colors.grey[400]),
          ),
          const SizedBox(width: 4),
        ],
        OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            side: BorderSide(
              color: isSet ? color.withValues(alpha: 0.4) : Colors.grey.withValues(alpha: 0.3),
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(
            _formatBirthday(date),
            style: TextStyle(
              fontSize: 13,
              color: isSet ? color : Colors.grey[400],
              fontWeight: isSet ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _lunarRow({
    required String name,
    required int month,
    required int day,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    final color = Theme.of(context).primaryColor;
    final isSet = month > 0 && day > 0;
    return Row(
      children: [
        Expanded(
          child: Text(
            name,
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ),
        if (onClear != null) ...[
          GestureDetector(
            onTap: onClear,
            child: Icon(Icons.close, size: 14, color: Colors.grey[400]),
          ),
          const SizedBox(width: 4),
        ],
        OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            side: BorderSide(
              color: isSet ? color.withValues(alpha: 0.4) : Colors.grey.withValues(alpha: 0.3),
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(
            _formatLunarDate(month, day),
            style: TextStyle(
              fontSize: 13,
              color: isSet ? color : Colors.grey[400],
              fontWeight: isSet ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}
