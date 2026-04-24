class Moment {
  final DateTime date;
  final String content;
  final String? image;
  final String? mood;

  Moment({required this.date, required this.content, this.image, this.mood});

  factory Moment.fromYaml(Map<dynamic, dynamic> yaml) {
    // rawDate might be string "2025-03-23 14:02:50" or a Date object from yaml parser
    // If yaml parser parses it as string, we parse it.
    dynamic rawDate = yaml['date'];
    DateTime parsedDate;
    if (rawDate is String) {
      parsedDate = DateTime.parse(rawDate);
    } else if (rawDate is DateTime) {
      parsedDate = rawDate;
    } else {
      parsedDate = DateTime.now(); // Fallback
    }

    return Moment(
      date: parsedDate,
      content: yaml['content']?.toString() ?? '',
      image: yaml['image']?.toString(),
      mood: yaml['mood']?.toString(),
    );
  }
}
