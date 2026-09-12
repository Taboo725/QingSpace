/// A short dated note stored in `data/moments.yml`.
class Moment {
  final DateTime date;
  final String content;
  final String? image;
  final String? mood;

  const Moment({
    required this.date,
    required this.content,
    this.image,
    this.mood,
  });

  /// Builds a moment from one YAML list entry, or null when it has no usable
  /// date. `package:yaml` resolves unquoted timestamps to [DateTime] itself;
  /// quoted ones arrive as strings.
  static Moment? tryFromYaml(Map<dynamic, dynamic> yaml) {
    final raw = yaml['date'];
    final date = raw is DateTime
        ? raw
        : DateTime.tryParse(raw?.toString() ?? '');
    if (date == null) return null;

    return Moment(
      date: date,
      content: yaml['content']?.toString() ?? '',
      image: yaml['image']?.toString(),
      mood: yaml['mood']?.toString(),
    );
  }

  /// [image] is always replaced — pass the current value to keep it, or an
  /// empty string to clear it.
  Moment copyWith({
    DateTime? date,
    String? content,
    required String? image,
    String? mood,
  }) => Moment(
    date: date ?? this.date,
    content: content ?? this.content,
    image: image,
    mood: mood ?? this.mood,
  );
}
