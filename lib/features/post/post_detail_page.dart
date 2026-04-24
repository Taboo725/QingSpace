import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import '../../core/services/github_service.dart';
import '../../core/services/data_source_manager.dart';
import '../../core/utils/frontmatter_parser.dart';
import '../../core/widgets/cdn_image.dart';
import '../../core/widgets/fullscreen_photo_page.dart';
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
  final String? sha;

  const PostDetailPage({
    super.key,
    required this.fileName,
    this.initialContent = '',
    this.sha,
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

  String? _currentSha;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentSha = widget.sha;
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
    _tags = (meta['tags'] is List)
        ? (meta['tags'] as List).map((e) => e.toString()).toList()
        : (meta['tags'] != null ? [meta['tags'].toString()] : []);
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

  void _processImages() {
    // Strip HTML div wrappers that interfere with Markdown rendering
    String temp = _bodyContent.replaceAll(
      RegExp(r'<div[^>]*>|</div>', caseSensitive: false),
      '\n',
    );

    // Convert <img src="..."> → ![]()
    temp = temp.replaceAllMapped(
      RegExp(r'<img\s+[^>]*src\s*=\s*["\x27]?([^"\x27\s>]+)["\x27\s]?[^>]*>',
          caseSensitive: false),
      (m) => '\n![](${m.group(1)!})\n',
    );

    // Resolve relative image paths
    _processedBody = temp.replaceAllMapped(
      RegExp(r'!\[(.*?)\]\((.*?)\)'),
      (m) {
        final alt = m.group(1) ?? '';
        String src = m.group(2) ?? '';
        if (!src.startsWith('http')) {
          if (src.startsWith('/')) src = src.substring(1);
          if (src.startsWith('images/')) {
            src = DataSourceManager.instance.rawUrl(src);
          } else if (src.startsWith('source/assets/') ||
              src.startsWith('assets/')) {
            src = DataSourceManager.instance.rawUrl('images/posts/${src.split('/').last}');
          } else if (!src.contains('/')) {
            src = DataSourceManager.instance.rawUrl('images/posts/$src');
          }
        }
        return '![$alt]($src)';
      },
    );
  }

  Future<void> _loadContent() async {
    setState(() => _isLoading = true);
    try {
      final content =
          await context.read<GithubService>().fetchFileContent(widget.fileName);
      if (mounted) setState(() => _parse(content));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('加载失败，请重试')));
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
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('删除',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    if (_currentSha == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('删除失败，请重试')));
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      await service.deleteFile(widget.fileName, _currentSha!);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('删除失败，请重试')));
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
          existingSha: _currentSha,
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
          style: TextStyle(fontSize: 12, color: Colors.grey[500], letterSpacing: 1),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: _editPost,
              tooltip: 'Edit'),
          IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _deletePost,
              tooltip: 'Delete'),
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
                ? [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 5))]
                : null,
          ),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 48.0, vertical: 32),
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
                        imageBuilder: (uri, title, alt) => _MarkdownImage(
                          imageUrl: uri.toString(),
                          alt: alt,
                        ),
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
      items.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Flexible(
            child: Text(text,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.grey[600], fontSize: 13, height: 1.2)),
          ),
        ],
      ));
    }

    if (_id.isNotEmpty) addMeta(Icons.tag, _id);
    if (_date.isNotEmpty) addMeta(Icons.calendar_today, _date);
    if (_category.isNotEmpty) addMeta(Icons.folder_open, _category);
    if (_authors.isNotEmpty) addMeta(Icons.person_outline, _authors.join(' & '));

    return Wrap(spacing: 16, runSpacing: 6, children: items);
  }

  Widget _buildTags() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _tags
          .map((t) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(t,
                    style: TextStyle(color: Colors.grey[700], fontSize: 12)),
              ))
          .toList(),
    );
  }

  MarkdownStyleSheet _markdownStyle(BuildContext context) {
    return MarkdownStyleSheet(
      p: const TextStyle(
          fontSize: 17, height: 1.8, color: Color(0xFF37474F),
          fontFamily: 'Source Han Serif CN'),
      h1: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.5,
          color: Colors.black87, fontFamily: 'Source Han Serif CN'),
      h2: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, height: 1.5,
          color: Colors.black87, fontFamily: 'Source Han Serif CN'),
      h3: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 1.5,
          color: Colors.black87, fontFamily: 'Source Han Serif CN'),
      blockquote: TextStyle(
          color: Colors.grey[600], fontStyle: FontStyle.italic, fontSize: 16),
      blockquoteDecoration: BoxDecoration(
        border: Border(
            left: BorderSide(color: Theme.of(context).primaryColor, width: 4)),
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(4),
      ),
      blockquotePadding: const EdgeInsets.only(
          left: 24, top: 12, bottom: 12, right: 16),
      code: const TextStyle(
          backgroundColor: Color(0xFFEEEEEE), fontFamily: 'monospace'),
      codeblockDecoration: BoxDecoration(
          color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
    );
  }
}

// ── Markdown image node ───────────────────────────────────────────────────────

class _MarkdownImage extends StatefulWidget {
  final String imageUrl;
  final String? alt;

  const _MarkdownImage({required this.imageUrl, this.alt});

  @override
  State<_MarkdownImage> createState() => _MarkdownImageState();
}

class _MarkdownImageState extends State<_MarkdownImage>
    with AutomaticKeepAliveClientMixin {
  static final Map<String, double> _heightCache = {};

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cached = _heightCache[widget.imageUrl];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FullscreenPhotoPage(imageUrl: widget.imageUrl),
          ),
        ),
        child: Hero(
          tag: widget.imageUrl,
          child: _MeasureSize(
            onChange: (size) {
              if (size.height > 0 && _heightCache[widget.imageUrl] != size.height) {
                _heightCache[widget.imageUrl] = size.height;
              }
            },
            child: NetImage(
              imageUrl: widget.imageUrl,
              fadeInDuration:
                  cached != null ? Duration.zero : const Duration(milliseconds: 500),
              placeholder: (context, url) => Container(
                height: cached ?? 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                alignment: Alignment.center,
                child: cached == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                          const SizedBox(height: 12),
                          Text('Loading image...',
                              style: TextStyle(
                                  color: Colors.grey[400], fontSize: 12)),
                        ],
                      )
                    : const SizedBox(),
              ),
              errorWidget: (context, url, err) => Container(
                height: 100,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.broken_image_outlined, color: Colors.grey),
                    const SizedBox(height: 8),
                    Text('Image Load Failed',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ],
                ),
              ),
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
