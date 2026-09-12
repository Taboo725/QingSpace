import 'package:flutter_test/flutter_test.dart';
import 'package:qing_space/models/gallery_item.dart';
import 'package:qing_space/models/moment.dart';
import 'package:qing_space/models/post.dart';

void main() {
  group('Post.fromFile', () {
    Map<String, dynamic> entry(String name) => {
      'name': name,
      'path': 'data/posts/$name',
      'sha': 'abc123',
    };

    test('reads date and title from the filename prefix', () {
      final post = Post.fromFile(entry('2025-04-29-Spring Trip.md'));
      expect(post.date, '2025-04-29');
      expect(post.title, 'Spring Trip');
      expect(post.sha, 'abc123');
    });

    test('frontmatter title wins over the filename', () {
      final post = Post.fromFile(
        entry('2025-04-29-slug.md'),
        content: '---\ntitle: A Better Title\n---\n\nBody',
      );
      expect(post.title, 'A Better Title');
      expect(post.date, '2025-04-29');
    });

    test('falls back to the frontmatter date when the filename has none', () {
      final post = Post.fromFile(
        entry('untitled.md'),
        content: '---\ndate: 2025-04-29 0:0:00\n---\n\nBody',
      );
      expect(post.date, '2025-04-29');
    });

    test('picks up the abstract, ignoring separators', () {
      expect(
        Post.fromFile(
          entry('a.md'),
          content: '---\nabstract: A short summary\n---\n\nBody',
        ).abstract,
        'A short summary',
      );
      expect(
        Post.fromFile(
          entry('a.md'),
          content: '---\nabstract: ---\n---\n\nB',
        ).abstract,
        isNull,
      );
    });

    test('survives a directory entry with missing fields', () {
      final post = Post.fromFile({'name': 'x.md'});
      expect(post.path, '');
      expect(post.sha, isNull);
      expect(post.title, 'x');
    });
  });

  group('Post.categoriesOf', () {
    test('reads the singular key', () {
      expect(Post.categoriesOf('---\ncategory: Diaries\n---\n\nBody'), {
        'diaries',
      });
    });

    test('reads the plural key in both inline and block form', () {
      expect(
        Post.categoriesOf('---\ncategories: [Diaries, Letters]\n---\n\nBody'),
        {'diaries', 'letters'},
      );
      expect(Post.categoriesOf('---\ncategories:\n- diaries\n---\n\nBody'), {
        'diaries',
      });
    });

    test('does not match a category mentioned in the body', () {
      expect(Post.categoriesOf('No frontmatter. category: letters'), isEmpty);
    });
  });

  group('Moment.tryFromYaml', () {
    test('accepts a DateTime or a parseable string', () {
      expect(
        Moment.tryFromYaml({
          'date': DateTime(2025, 4, 29),
          'content': 'a',
        })!.date,
        DateTime(2025, 4, 29),
      );
      expect(
        Moment.tryFromYaml({'date': '2025-04-29 14:02:50'})!.date,
        DateTime(2025, 4, 29, 14, 2, 50),
      );
    });

    test('rejects entries without a usable date', () {
      expect(Moment.tryFromYaml({'content': 'orphan'}), isNull);
      expect(Moment.tryFromYaml({'date': 'not a date'}), isNull);
    });
  });

  group('Moment.copyWith', () {
    final base = Moment(
      date: DateTime(2025, 1, 1),
      content: 'hi',
      image: 'images/moments/a.jpg',
      mood: '😊',
    );

    test('replaces the image explicitly, including clearing it', () {
      expect(base.copyWith(image: 'b.jpg').image, 'b.jpg');
      expect(base.copyWith(image: null).image, isNull);
      expect(base.copyWith(image: base.image).mood, '😊');
    });
  });

  group('GalleryItem.fromMap', () {
    test('parses an optional date from either a string or a DateTime', () {
      expect(
        GalleryItem.fromMap({'url': '/a.jpg', 'date': '2025-04-29'}).date,
        DateTime(2025, 4, 29),
      );
      expect(
        GalleryItem.fromMap({
          'url': '/a.jpg',
          'date': DateTime(2025, 4, 29),
        }).date,
        DateTime(2025, 4, 29),
      );
      expect(GalleryItem.fromMap({'url': '/a.jpg'}).date, isNull);
      expect(
        GalleryItem.fromMap({'url': '/a.jpg', 'date': 'nope'}).date,
        isNull,
      );
    });

    test('defaults missing fields to empty strings', () {
      final item = GalleryItem.fromMap({});
      expect(item.url, '');
      expect(item.caption, '');
    });
  });
}
