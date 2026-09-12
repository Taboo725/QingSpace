import '../core/utils/frontmatter_parser.dart';

/// A Markdown post stored at `data/posts/<name>.md`.
class Post {
  final String title;

  /// `yyyy-MM-dd`, or empty when the post carries no usable date.
  final String date;
  final String content;
  final String path;

  /// Blob SHA from the repo listing; required for updates and deletes.
  final String? sha;
  final String? abstract;

  const Post({
    required this.title,
    required this.date,
    required this.content,
    required this.path,
    this.sha,
    this.abstract,
  });

  /// Builds a post from a repo directory entry, optionally with its body.
  ///
  /// The filename prefix (`2025-04-29-title.md`) is the primary source for the
  /// date and a fallback for the title; frontmatter overrides the title and
  /// fills the date when the filename has no prefix.
  factory Post.fromFile(Map<String, dynamic> entry, {String? content}) {
    final path = entry['path']?.toString() ?? '';
    final fileName = entry['name']?.toString() ?? path.split('/').last;

    var title = fileName.replaceAll(RegExp(r'\.md$', caseSensitive: false), '');
    var date = '';

    final prefixed = _datePrefix.firstMatch(title);
    if (prefixed != null) {
      date = prefixed.group(1)!;
      title = prefixed.group(2)!.trim();
    }

    String? abstract;
    if (content != null && content.isNotEmpty) {
      final (:meta, body: _) = parseFrontmatter(content);

      final metaTitle = meta['title']?.toString().trim();
      if (metaTitle != null && metaTitle.isNotEmpty) title = metaTitle;

      final metaAbstract = meta['abstract']?.toString().trim();
      if (metaAbstract != null &&
          metaAbstract.isNotEmpty &&
          metaAbstract != '---' &&
          metaAbstract != '...') {
        abstract = metaAbstract;
      }

      if (date.isEmpty) {
        final rawDate = meta['date']?.toString().trim() ?? '';
        if (rawDate.isNotEmpty) date = normaliseDate(rawDate);
      }
    }

    return Post(
      title: title,
      date: date,
      content: content ?? '',
      path: path,
      sha: entry['sha']?.toString(),
      abstract: abstract,
    );
  }

  /// Categories declared in frontmatter, lower-cased.
  ///
  /// Accepts the singular `category:` key as well as the plural `categories:`
  /// form (inline `[a, b]` or a block list).
  static Set<String> categoriesOf(String content) {
    final meta = parseFrontmatter(content).meta;
    return {
      ...parseStringList(meta, 'category'),
      ...parseStringList(meta, 'categories'),
    }.map((e) => e.toLowerCase()).where((e) => e.isNotEmpty).toSet();
  }

  Post copyWith({
    String? content,
    String? title,
    String? date,
    String? abstract,
  }) => Post(
    title: title ?? this.title,
    date: date ?? this.date,
    content: content ?? this.content,
    path: path,
    sha: sha,
    abstract: abstract ?? this.abstract,
  );

  static final RegExp _datePrefix = RegExp(r'^(\d{4}-\d{2}-\d{2})-(.*)');
}
