import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:provider/provider.dart';

import '../../core/services/data_source_manager.dart';
import '../../core/services/github_service.dart';
import '../../core/utils/frontmatter_parser.dart';
import '../../core/widgets/fullscreen_photo_page.dart';
import '../../core/widgets/net_image.dart';
import 'post_editor_page.dart';

class _HrBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    return Container(
      height: 1,
      width: double.infinity,
      color: const Color(0xFFF5F5F5),
      margin: const EdgeInsets.symmetric(vertical: 64.0),
    );
  }
}

class PostDetailPage extends StatefulWidget {
  final String fileName;
  final String initialContent;

  const PostDetailPage({
    super.key,
    required this.fileName,
    this.initialContent = '',
  });

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  String _rawContent = '';
  String _bodyContent = '';
  String _processedBody = '';

  String _title = '';
  String _date = '';
  String _category = '';
  String _id = '';
  List<String> _tags = [];
  List<String> _authors = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialContent.isNotEmpty) {
      _parse(widget.initialContent);
    } else {
      _loadContent();
    }
  }

  void _parse(String raw) {
    _rawContent = raw;
    final (:meta, :body) = parseFrontmatter(raw);
    _bodyContent = body;

    _title = meta['title']?.toString() ?? '';
    _id = meta['id']?.toString() ?? '';
    _category = meta['category']?.toString() ?? '';
    _tags = parseStringList(meta, 'tags');
    _authors = parseAuthors(meta);

    final rawDate = meta['date']?.toString() ?? '';
    _date = rawDate.isNotEmpty ? normaliseDate(rawDate) : '';

    if (_title.isEmpty) {
      _title = widget.fileName.split('/').last.replaceAll('.md', '');
      final m = RegExp(r'^\d{4}-\d{2}-\d{2}-(.*)').firstMatch(_title);
      if (m != null) _title = m.group(1)!;
    }

    _processImages();
  }

  // Hoisted so re-parsing a post does not recompile them each time.
  static final RegExp _divTag = RegExp(
    r'<div[^>]*>|</div>',
    caseSensitive: false,
  );
  static final RegExp _imgTag = RegExp(
    r'<img\s+[^>]*src\s*=\s*["\x27]?([^"\x27\s>]+)["\x27\s]?[^>]*>',
    caseSensitive: false,
  );
  static final RegExp _markdownImage = RegExp(r'!\[(.*?)\]\((.*?)\)');

  void _processImages() {
    // Strip HTML div wrappers that interfere with Markdown rendering,
    // then fold <img src="..."> into Markdown image syntax.
    final temp = _bodyContent
        .replaceAll(_divTag, '\n')
        .replaceAllMapped(_imgTag, (m) => '\n![](${m.group(1)!})\n');

    _processedBody = temp.replaceAllMapped(
      _markdownImage,
      (m) => '![${m.group(1) ?? ''}](${_resolveImageSrc(m.group(2) ?? '')})',
    );
  }

  /// Expands a post-relative image reference into an absolute raw URL.
  static String _resolveImageSrc(String raw) {
    if (raw.startsWith('http')) return raw;
    final src = raw.startsWith('/') ? raw.substring(1) : raw;
    final rawUrl = DataSourceManager.instance.rawUrl;

    if (src.startsWith('images/')) return rawUrl(src);
    if (src.startsWith('source/assets/') || src.startsWith('assets/')) {
      return rawUrl('images/posts/${src.split('/').last}');
    }
    if (!src.contains('/')) return rawUrl('images/posts/$src');
    return src;
  }

  Future<void> _loadContent() async {
    setState(() => _isLoading = true);
    try {
      final content = await context.read<GithubService>().fetchFileContent(
        widget.fileName,
      );
      if (mounted) setState(() => _parse(content));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('加载失败，请重试')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deletePost() async {
    final service = context.read<GithubService>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除这篇文章？'),
        content: const Text('删除后无法恢复'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await service.deleteFile(widget.fileName);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('删除失败，请重试')));
        setState(() => _isLoading = false);
      }
    }
  }

  void _editPost() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostEditorPage(
          existingFileName: widget.fileName,
          existingContent: _rawContent,
        ),
      ),
    ).then((result) {
      if (result == true) _loadContent();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isWide = MediaQuery.sizeOf(context).width > 900;
    final wordCount = _bodyContent.length;
    final readTime = (wordCount / 400).ceil();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          '$wordCount 字   ·   $readTime 分钟',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
            letterSpacing: 1,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: _editPost,
            tooltip: 'Edit',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _deletePost,
            tooltip: 'Delete',
          ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 850),
          margin: isWide ? const EdgeInsets.symmetric(vertical: 24) : null,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: isWide ? BorderRadius.circular(8) : null,
            boxShadow: isWide
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48.0,
                    vertical: 32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _title,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2C3E50),
                          fontFamily: 'Source Han Serif CN',
                          height: 1.3,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildMeta(),
                      const SizedBox(height: 16),
                      if (_tags.isNotEmpty) _buildTags(),
                      const SizedBox(height: 32),
                      const Divider(height: 1, thickness: 1),
                      const SizedBox(height: 48),
                      MarkdownBody(
                        data: _processedBody,
                        selectable: true,
                        builders: {'hr': _HrBuilder()},
                        // ignore: deprecated_member_use
                        imageBuilder: (uri, title, alt) =>
                            _MarkdownImage(imageUrl: uri.toString()),
                        styleSheet: _markdownStyle(context),
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMeta() {
    final items = <Widget>[];
    void addMeta(IconData icon, String text) {
      items.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_id.isNotEmpty) addMeta(Icons.tag, _id);
    if (_date.isNotEmpty) addMeta(Icons.calendar_today, _date);
    if (_category.isNotEmpty) addMeta(Icons.folder_open, _category);
    if (_authors.isNotEmpty) {
      addMeta(Icons.person_outline, _authors.join(' & '));
    }

    return Wrap(spacing: 16, runSpacing: 6, children: items);
  }

  Widget _buildTags() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _tags
          .map(
            (t) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                t,
                style: TextStyle(color: Colors.grey[700], fontSize: 12),
              ),
            ),
          )
          .toList(),
    );
  }

  MarkdownStyleSheet _markdownStyle(BuildContext context) {
    return MarkdownStyleSheet(
      p: const TextStyle(
        fontSize: 17,
        height: 1.8,
        color: Color(0xFF37474F),
        fontFamily: 'Source Han Serif CN',
      ),
      h1: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        height: 1.5,
        color: Colors.black87,
        fontFamily: 'Source Han Serif CN',
      ),
      h2: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        height: 1.5,
        color: Colors.black87,
        fontFamily: 'Source Han Serif CN',
      ),
      h3: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        height: 1.5,
        color: Colors.black87,
        fontFamily: 'Source Han Serif CN',
      ),
      blockquote: TextStyle(
        color: Colors.grey[600],
        fontStyle: FontStyle.italic,
        fontSize: 16,
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: Theme.of(context).primaryColor, width: 4),
        ),
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(4),
      ),
      blockquotePadding: const EdgeInsets.only(
        left: 24,
        top: 12,
        bottom: 12,
        right: 16,
      ),
      code: const TextStyle(
        backgroundColor: Color(0xFFEEEEEE),
        fontFamily: 'monospace',
      ),
      codeblockDecoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

// ── Markdown image node ───────────────────────────────────────────────────────

/// A post image: tappable to open full-screen, and height-cached so that
/// scrolling back to an already-seen image does not reflow the article.
class _MarkdownImage extends StatefulWidget {
  final String imageUrl;

  const _MarkdownImage({required this.imageUrl});

  @override
  State<_MarkdownImage> createState() => _MarkdownImageState();
}

class _MarkdownImageState extends State<_MarkdownImage>
    with AutomaticKeepAliveClientMixin {
  /// url → laid-out height, so the placeholder can reserve the right space on
  /// a revisit instead of collapsing to a default and jumping.
  static final Map<String, double> _heightCache = {};

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cachedHeight = _heightCache[widget.imageUrl];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FullscreenPhotoPage(
              imageUrl: widget.imageUrl,
              heroTag: widget.imageUrl,
            ),
          ),
        ),
        child: Hero(
          tag: widget.imageUrl,
          child: _MeasureSize(
            onChange: (size) {
              if (size.height > 0) _heightCache[widget.imageUrl] = size.height;
            },
            child: NetImage(
              imageUrl: widget.imageUrl,
              // The article column is capped at 850 px; 1700 covers 2x displays
              // without decoding multi-megapixel originals in full.
              memCacheWidth: 1700,
              fadeInDuration: cachedHeight != null
                  ? Duration.zero
                  : const Duration(milliseconds: 300),
              placeholder: (_, _) => ImageLoadingBox(
                height: cachedHeight ?? 200,
                borderRadius: BorderRadius.circular(8),
                showSpinner: cachedHeight == null,
              ),
              errorWidget: (_, _, _) =>
                  const ImageErrorBox(height: 100, compact: true),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Size measurement helper ───────────────────────────────────────────────────

class _MeasureSizeRenderObject extends RenderProxyBox {
  Size? _oldSize;
  final void Function(Size) onChange;

  _MeasureSizeRenderObject(this.onChange);

  @override
  void performLayout() {
    super.performLayout();
    final newSize = child?.size;
    if (newSize != null && newSize != _oldSize) {
      _oldSize = newSize;
      WidgetsBinding.instance.addPostFrameCallback((_) => onChange(newSize));
    }
  }
}

class _MeasureSize extends SingleChildRenderObjectWidget {
  final void Function(Size) onChange;

  const _MeasureSize({required this.onChange, required Widget child})
    : super(child: child);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _MeasureSizeRenderObject(onChange);
}
