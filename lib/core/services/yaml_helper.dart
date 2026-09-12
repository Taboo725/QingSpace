import 'dart:convert';

/// Encodes [value] as a YAML scalar that round-trips through any YAML parser.
///
/// JSON string syntax is a subset of YAML's double-quoted style, so delegating
/// to [jsonEncode] gives correct escaping for quotes, backslashes, newlines and
/// emoji without hand-rolling an escaper.
String yamlScalar(String value) => jsonEncode(value);

/// Formats [date] as an unquoted `yyyy-MM-dd HH:mm:ss` YAML timestamp.
String yamlTimestamp(DateTime date) =>
    '${_pad(date.year, 4)}-${_pad(date.month)}-${_pad(date.day)} '
    '${_pad(date.hour)}:${_pad(date.minute)}:${_pad(date.second)}';

/// Formats [date] as an unquoted `yyyy-MM-dd` YAML date.
String yamlDate(DateTime date) =>
    '${_pad(date.year, 4)}-${_pad(date.month)}-${_pad(date.day)}';

String _pad(int value, [int width = 2]) => value.toString().padLeft(width, '0');
