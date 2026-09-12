import 'package:flutter_test/flutter_test.dart';
import 'package:qing_space/core/services/moment_service.dart';
import 'package:qing_space/core/services/yaml_helper.dart';
import 'package:qing_space/models/moment.dart';
import 'package:yaml/yaml.dart';

List<Moment> parse(String yaml) => (loadYaml(yaml) as YamlList)
    .map((e) => Moment.tryFromYaml(e as Map)!)
    .toList();

void main() {
  group('yamlScalar', () {
    test('escapes quotes, backslashes and newlines', () {
      expect(loadYaml('v: ${yamlScalar('he said "hi"')}')['v'], 'he said "hi"');
      expect(loadYaml('v: ${yamlScalar(r'a\b')}')['v'], r'a\b');
      expect(loadYaml('v: ${yamlScalar('line1\nline2')}')['v'], 'line1\nline2');
    });

    test('keeps emoji intact', () {
      expect(loadYaml('v: ${yamlScalar('😊')}')['v'], '😊');
    });
  });

  group('yamlTimestamp', () {
    test('zero-pads every component', () {
      expect(
        yamlTimestamp(DateTime(2025, 4, 9, 8, 5, 3)),
        '2025-04-09 08:05:03',
      );
    });
  });

  group('momentsToYamlString', () {
    test('round-trips content, image and mood', () {
      final moments = [
        Moment(
          date: DateTime(2025, 4, 29, 14, 2, 50),
          content: 'A day out',
          image: 'images/moments/2025.04.29_140250.jpg',
          mood: '😊',
        ),
        Moment(date: DateTime(2025, 5, 1, 9), content: 'No image or mood'),
      ];

      final parsed = parse(momentsToYamlString(moments));

      expect(parsed, hasLength(2));
      expect(parsed[0].date, DateTime(2025, 4, 29, 14, 2, 50));
      expect(parsed[0].content, 'A day out');
      expect(parsed[0].image, 'images/moments/2025.04.29_140250.jpg');
      expect(parsed[0].mood, '😊');
      expect(parsed[1].image, isNull);
      expect(parsed[1].mood, isNull);
    });

    test('round-trips content that would break naive quoting', () {
      final moments = [
        Moment(
          date: DateTime(2025, 4, 29),
          content: 'She said: "it\'s fine" — C:\\path\nnew line',
          mood: '"',
        ),
      ];

      final parsed = parse(momentsToYamlString(moments));
      expect(parsed.single.content, moments.single.content);
      expect(parsed.single.mood, '"');
    });

    test('produces an empty document for an empty list', () {
      expect(momentsToYamlString(const []), isEmpty);
    });
  });
}
