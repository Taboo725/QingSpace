import 'package:flutter_test/flutter_test.dart';
import 'package:qing_space/core/utils/frontmatter_parser.dart';

void main() {
  group('parseFrontmatter', () {
    test('splits metadata from body', () {
      final result = parseFrontmatter('---\ntitle: Hello\n---\n\nBody text.');
      expect(result.meta['title'], 'Hello');
      expect(result.body, 'Body text.');
    });

    test('tolerates CRLF line endings', () {
      final result = parseFrontmatter('---\r\ntitle: Hello\r\n---\r\nBody.');
      expect(result.meta['title'], 'Hello');
      expect(result.body, 'Body.');
    });

    test('returns the whole input when there is no frontmatter', () {
      final result = parseFrontmatter('Just a body.');
      expect(result.meta, isEmpty);
      expect(result.body, 'Just a body.');
    });

    test('ignores key-like lines in the body', () {
      // A body line such as "category: letters" must not leak into the meta
      // map, or category filtering would match the wrong posts.
      final result = parseFrontmatter(
        '---\ncategory: diaries\n---\n\nI wrote category: letters today.',
      );
      expect(result.meta['category'], 'diaries');
    });
  });

  group('parseYamlLines', () {
    test('reads inline lists', () {
      final meta = parseYamlLines('tags: [travel, food]');
      expect(meta['tags'], ['travel', 'food']);
    });

    test('reads block lists', () {
      final meta = parseYamlLines('tags:\n- travel\n- food\ntitle: Trip');
      expect(meta['tags'], ['travel', 'food']);
      expect(meta['title'], 'Trip');
    });

    test('strips matching quotes', () {
      final meta = parseYamlLines('title: "Quoted"\nsub: \'Single\'');
      expect(meta['title'], 'Quoted');
      expect(meta['sub'], 'Single');
    });

    test('leaves unbalanced quotes alone', () {
      expect(parseYamlLines('title: "half')['title'], '"half');
    });
  });

  group('parseStringList', () {
    test('accepts a list, an inline list, or a bare scalar', () {
      expect(
        parseStringList({
          'a': ['x', 'y'],
        }, 'a'),
        ['x', 'y'],
      );
      expect(parseStringList({'a': '[x, y]'}, 'a'), ['x', 'y']);
      expect(parseStringList({'a': 'x'}, 'a'), ['x']);
      expect(parseStringList({}, 'a'), isEmpty);
      expect(parseStringList({'a': ''}, 'a'), isEmpty);
    });
  });

  group('normaliseDate', () {
    test('normalises parseable dates', () {
      expect(normaliseDate('2025-04-29T10:30:00'), '2025-04-29');
      expect(normaliseDate('2025-04-29'), '2025-04-29');
    });

    test('pads a loose y-m-d that DateTime cannot parse', () {
      expect(normaliseDate('written 2025-4-9 at dawn'), '2025-04-09');
    });

    test('returns the input when nothing date-like is present', () {
      expect(normaliseDate('someday'), 'someday');
    });
  });
}
