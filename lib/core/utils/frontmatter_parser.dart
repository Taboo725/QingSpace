/// Frontmatter keys the editor renders with dedicated controls; everything else
/// in the block is surfaced as a free-form custom property.
const Set<String> kCoreFrontmatterKeys = {
  'title',
  'date',
  'category',
  'tags',
  'id',
  'author',
  'abstract',
};

/// Parses YAML frontmatter from Markdown content.
///
/// Returns a record with the parsed metadata map and the body (everything
/// after the closing `---`). If no frontmatter is found, [meta] is empty
/// and [body] is the full input.
({Map<String, dynamic> meta, String body}) parseFrontmatter(String content) {
  final match = _frontmatterBlock.firstMatch(content);
  if (match == null) return (meta: const {}, body: content);
  return (
    meta: parseYamlLines(match.group(1)!),
    body: content.substring(match.end).trim(),
  );
}

// Tolerates both LF and CRLF line endings.
final RegExp _frontmatterBlock = RegExp(
  r'^---\r?\n(.*?)\r?\n---[ \t]*\r?\n',
  dotAll: true,
);
final RegExp _keyValue = RegExp(r'^([\w-]+):\s*(.*)$');

/// Parses a subset of YAML key-value pairs and simple lists.
/// Deliberately avoids the `yaml` package: frontmatter here is a flat map and
/// the hand-rolled pass keeps quoting quirks (unquoted CJK, bare URLs) working.
Map<String, dynamic> parseYamlLines(String text) {
  final result = <String, dynamic>{};
  String? listKey;

  for (final line in text.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;

    if (listKey != null && trimmed.startsWith('- ')) {
      (result[listKey] as List).add(_unquote(trimmed.substring(2).trim()));
      continue;
    }

    final keyMatch = _keyValue.firstMatch(trimmed);
    if (keyMatch == null) continue;

    final key = keyMatch.group(1)!;
    final val = keyMatch.group(2)!.trim();

    if (val.isEmpty) {
      listKey = key;
      result[key] = <String>[];
    } else {
      listKey = null;
      result[key] = val.startsWith('[') && val.endsWith(']')
          ? _splitInlineList(val.substring(1, val.length - 1))
          : _unquote(val);
    }
  }
  return result;
}

/// Reads [key] from a parsed meta map as a list of strings, accepting either a
/// real list, an inline `[a, b]` string, or a lone scalar.
List<String> parseStringList(Map<String, dynamic> meta, String key) {
  final raw = meta[key];
  if (raw == null) return const [];
  if (raw is List) return raw.map((e) => e.toString()).toList();
  final str = raw.toString().trim();
  if (str.isEmpty) return const [];
  if (str.startsWith('[') && str.endsWith(']')) {
    return _splitInlineList(str.substring(1, str.length - 1));
  }
  return [str];
}

/// Extracts the `author` field as a list of strings from a parsed meta map.
List<String> parseAuthors(Map<String, dynamic> meta) =>
    parseStringList(meta, 'author');

/// Normalises a raw date string into `yyyy-MM-dd`.
String normaliseDate(String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed != null) return _ymd(parsed);
  final m = RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(raw);
  if (m == null) return raw;
  return '${m.group(1)}-${m.group(2)!.padLeft(2, '0')}-${m.group(3)!.padLeft(2, '0')}';
}

/// Formats [date] as `yyyy-MM-dd` without pulling in `intl`.
String _ymd(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

List<String> _splitInlineList(String inner) => inner
    .split(',')
    .map((e) => _unquote(e.trim()))
    .where((e) => e.isNotEmpty)
    .toList();

String _unquote(String val) {
  if (val.length < 2) return val;
  final first = val[0];
  if ((first == '"' || first == "'") && val.endsWith(first)) {
    return val.substring(1, val.length - 1);
  }
  return val;
}
