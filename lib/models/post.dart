class Post {
  final String title;
  final String date;
  final String content;
  final String path;
  final String? sha; // GitHub SHA for updates
  final String? abstract;

  Post({
    required this.title,
    required this.date,
    required this.content,
    required this.path,
    this.sha,
    this.abstract,
  });

  // Factory to create from GitHub API name/path
  factory Post.fromFile(Map<String, dynamic> json, {String? content}) {
    String filename = json['name'].toString();
    String title = filename.replaceAll('.md', '');
    String date = '';
    String? abstract;

    // 1. Try date from filename
    final regex = RegExp(r'^(\d{4}-\d{2}-\d{2})-(.*)');
    final match = regex.firstMatch(title);
    if (match != null) {
      date = match.group(1)!;
      title = match.group(2)!.trim();
    }

    // 2. If content is available, try parsing Frontmatter for Title/Date
    if (content != null && content.isNotEmpty) {
      // Parse Title
      final titleRegex = RegExp(
        r'^title:\s*(.+)$',
        multiLine: true,
        caseSensitive: false,
      );
      final titleMatch = titleRegex.firstMatch(content);
      if (titleMatch != null) {
        title = titleMatch.group(1)!.trim();
      }

      // Parse Abstract
      // Match "abstract: value" but stop before "---" separator or next key
      final abstractRegex = RegExp(
        r'^abstract:\s*(.+)$',
        multiLine: true,
        caseSensitive: false,
      );
      final abstractMatch = abstractRegex.firstMatch(content);
      if (abstractMatch != null) {
        String rawAbstract = abstractMatch.group(1)!.trim();
        // Clean up common issues (like accidentally capturing separator or quotes)
        if (rawAbstract == '---' || rawAbstract == '...') {
          rawAbstract = '';
        }
        if (rawAbstract.startsWith('"') && rawAbstract.endsWith('"')) {
          rawAbstract = rawAbstract.substring(1, rawAbstract.length - 1);
        }
        if (rawAbstract.isNotEmpty) {
          abstract = rawAbstract;
        }
      }

      // Parse Date (if filename parse failed or we want to override)
      if (date.isEmpty) {
        final dateRegex = RegExp(
          r'^date:\s*(.+)$',
          multiLine: true,
          caseSensitive: false,
        );
        final dateMatch = dateRegex.firstMatch(content);
        if (dateMatch != null) {
          final rawDate = dateMatch.group(1)!.trim();
          try {
            // Handle format "2025-04-29 0:0:00"
            // DateTime.parse works with "2025-04-29 00:00:00" or space separated usually.
            // Let's ensure standard format or substring.
            date = DateTime.parse(rawDate).toIso8601String().split('T')[0];
          } catch (e) {
            // Fallback for non-standard formats like "2025-04-29 0:0:00" if parse failed
            // Try to grab just first 10 chars "YYYY-MM-DD"
            final ymdRegex = RegExp(r'(\d{4}-\d{1,2}-\d{1,2})');
            final ymdMatch = ymdRegex.firstMatch(rawDate);
            if (ymdMatch != null) {
              // Pad month/day with 0
              final parts = ymdMatch.group(1)!.split('-');
              final y = parts[0];
              final m = parts[1].padLeft(2, '0');
              final d = parts[2].padLeft(2, '0');
              date = "$y-$m-$d";
            }
          }
        }
      }
    }

    return Post(
      title: title,
      date: date,
      content: content ?? '',
      path: json['path'],
      sha: json['sha'],
      abstract: abstract,
    );
  }

  // Create copy with new content
  Post copyWith({
    String? content,
    String? title,
    String? date,
    String? abstract,
  }) {
    return Post(
      title: title ?? this.title,
      date: date ?? this.date,
      content: content ?? this.content,
      path: path,
      sha: sha,
      abstract: abstract ?? this.abstract,
    );
  }
}
