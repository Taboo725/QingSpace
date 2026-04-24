/// Parses YAML frontmatter from Markdown content.
///
/// Returns a record with the parsed metadata map and the body (everything
/// after the closing `---`).  If no frontmatter is found, [meta] is empty
/// and [body] is the full input.
({Map<String, dynamic> meta, String body}) parseFrontmatter(String content) {
  final regex = RegExp(r'^---\n(.*?)\n---\n', dotAll: true);
  final match = regex.firstMatch(content);
  if (match == null) return (meta: {}, body: content);
  return (
    meta: parseYamlLines(match.group(1)!),
    body: content.substring(match.end).trim(),
  );
}

/// Parses a subset of YAML key-value pairs and simple lists.
/// Does not use the `yaml` package to avoid a dependency for this small task.
Map<String, dynamic> parseYamlLines(String text) {
  final result = <String, dynamic>{};
  String? listKey;

  for (final line in text.split('\n')) {
    if (line.trim().isEmpty) continue;

    if (listKey != null && line.trim().startsWith('- ')) {
      final val = line.trim().substring(2).trim();
      (result[listKey] as List).add(val);
      continue;
    }

    final keyMatch = RegExp(r'^([\w-]+):\s*(.*)$').firstMatch(line.trim());
    if (keyMatch == null) continue;

    final key = keyMatch.group(1)!;
    String val = keyMatch.group(2)?.trim() ?? '';

    if (val.isEmpty) {
      listKey = key;
      result[key] = <String>[];
    } else {
      listKey = null;
      if (val.startsWith('[') && val.endsWith(']')) {
        final inner = val.substring(1, val.length - 1);
        result[key] = inner
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      } else {
        if ((val.startsWith('"') && val.endsWith('"')) ||
            (val.startsWith("'") && val.endsWith("'"))) {
          val = val.substring(1, val.length - 1);
        }
        result[key] = val;
      }
    }
  }
  return result;
}

/// Extracts the `author` field as a list of strings from a parsed meta map.
List<String> parseAuthors(Map<String, dynamic> meta) {
  final raw = meta['author'];
  if (raw == null) return [];
  if (raw is List) return raw.map((e) => e.toString()).toList();
  final str = raw.toString();
  if (str.startsWith('[') && str.endsWith(']')) {
    return str
        .substring(1, str.length - 1)
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  return [str];
}

/// Normalises a raw date string into `yyyy-MM-dd`.
String normaliseDate(String raw) {
  try {
    return DateTime.parse(raw).toIso8601String().split('T')[0];
  } catch (_) {
    final m = RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(raw);
    if (m != null) {
      return '${m.group(1)}-${m.group(2)!.padLeft(2, '0')}-${m.group(3)!.padLeft(2, '0')}';
    }
    return raw;
  }
}
