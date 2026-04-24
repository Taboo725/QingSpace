import 'dart:convert';
import 'package:intl/intl.dart';
import '../../models/moment.dart';

// Helper to serialize moments to YAML string
String momentsToYamlString(List<Moment> moments) {
  final buffer = StringBuffer();
  for (var moment in moments) {
    buffer.writeln('-');
    // Date
    final dateStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(moment.date);
    buffer.writeln('  date: $dateStr');

    // Content - use JSON encode to handle escaping
    buffer.writeln('  content: ${jsonEncode(moment.content)}');

    // Image
    if (moment.image != null && moment.image!.isNotEmpty) {
      buffer.writeln('  image: "${moment.image}"');
    }

    // Mood
    if (moment.mood != null && moment.mood!.isNotEmpty) {
      buffer.writeln('  mood: "${moment.mood}"');
    }
  }
  return buffer.toString();
}
