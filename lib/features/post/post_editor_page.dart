import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/services/couple_config.dart';
import '../../core/services/github_service.dart';
import '../../core/services/data_source_manager.dart';
import '../../core/utils/frontmatter_parser.dart';

class _EditorImage {
  final String id;
  final String fullPath;
  final String? originalPath;
  final bool isPending;
  final List<int>? pendingBytes;

  const _EditorImage({
    required this.id,
    required this.fullPath,
    required this.isPending,
    this.pendingBytes,
    this.originalPath,
  });

  _EditorImage copyWith({String? fullPath, String? originalPath}) => _EditorImage(
        id: id,
        fullPath: fullPath ?? this.fullPath,
        isPending: isPending,
        pendingBytes: pendingBytes,
        originalPath: originalPath ?? this.originalPath,
      );
}

class PostEditorPage extends StatefulWidget {
  final String? existingFileName;
  final String? existingContent;
  final String? existingSha;

  const PostEditorPage({
    super.key,
    this.existingFileName,
    this.existingContent,
    this.existingSha,
  });

  @override
  State<PostEditorPage> createState() => _PostEditorPageState();
}

class _PostEditorPageState extends State<PostEditorPage> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  DateTime _date = DateTime.now();
  String _category = 'posts';
  List<String> _tags = [];
  List<String> _authors = [];
  Map<String, String> _customProps = {};
  int? _id;

  final List<_EditorImage> _images = [];
  final List<String> _pendingDeletes = [];
  String? _highlightedImageId;

  bool _isSaving = false;

  bool get _isEditing => widget.existingFileName != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing && widget.existingContent != null) {
      _loadExisting(widget.existingContent!);
    } else {
      _fetchNextId();
    }
    _bodyController.addListener(_onBodyChanged);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _onBodyChanged() {
    if (_id == null) return;
    final text = _bodyController.text;
    final pos = _bodyController.selection.baseOffset;

    final pattern = RegExp(
      r'!\[.*?\]\(/images/posts/' + RegExp.escape('$_id') + r'-([a-zA-Z0-9]+)\.\w+\)',
      caseSensitive: false,
    );
    String? highlight;
    for (final m in pattern.allMatches(text)) {
      if (pos >= m.start && pos <= m.end) {
        highlight = m.group(1);
        break;
      }
    }
    if (highlight != _highlightedImageId) {
      setState(() => _highlightedImageId = highlight);
    }
    _syncImageOrder(text, pattern);
  }

  void _syncImageOrder(String text, RegExp pattern) {
    final matches = pattern.allMatches(text);
    final newOrder = <_EditorImage>[];
    final seen = <String>{};
    for (final m in matches) {
      final imgId = m.group(1)!;
      if (seen.contains(imgId)) continue;
      seen.add(imgId);
      final existing = _images.firstWhere(
        (e) => e.id == imgId,
        orElse: () => _EditorImage(
          id: imgId,
          fullPath: '/images/posts/$_id-$imgId.${m.group(0)!.split('.').last.replaceAll(')', '')}',
          isPending: false,
        ),
      );
      newOrder.add(existing);
    }
    if (newOrder.length != _images.length ||
        Iterable.generate(newOrder.length).any((i) => newOrder[i].id != _images[i].id)) {
      setState(() {
        _images
          ..clear()
          ..addAll(newOrder);
      });
    }
  }

  void _loadExisting(String content) {
    final (:meta, :body) = parseFrontmatter(content);
    _bodyController.text = body;
    _titleController.text = meta['title']?.toString() ?? '';
    _id = int.tryParse(meta['id']?.toString() ?? '');
    _category = meta['category']?.toString() ?? 'posts';
    _tags = (meta['tags'] is List)
        ? (meta['tags'] as List).map((e) => e.toString()).toList()
        : [];
    _authors = parseAuthors(meta);

    final rawDate = meta['date']?.toString() ?? '';
    if (rawDate.isNotEmpty) {
      try { _date = DateTime.parse(rawDate); } catch (_) {}
    }

    const knownKeys = {'title', 'date', 'category', 'tags', 'id', 'author'};
    _customProps = {
      for (final e in meta.entries)
        if (!knownKeys.contains(e.key.toLowerCase()))
          e.key: e.value.toString(),
    };

    if (_id == null && widget.existingFileName != null) {
      final name = widget.existingFileName!.split('/').last.replaceAll('.md', '');
      final m = RegExp(r'^(\d{4}-\d{2}-\d{2})-(.*)').firstMatch(name);
      if (m != null) {
        _titleController.text = m.group(2)!;
        try { _date = DateTime.parse(m.group(1)!); } catch (_) {}
      } else {
        _titleController.text = name;
      }
    }

    _syncImagesFromBody();
  }

  void _syncImagesFromBody() {
    if (_id == null) return;
    _images.clear();
    final pattern = RegExp(
      r'!\[.*?\]\(/images/posts/' + RegExp.escape('$_id') + r'-([a-zA-Z0-9]+)\.(\w+)\)',
      caseSensitive: false,
    );
    for (final m in pattern.allMatches(_bodyController.text)) {
      final imgId = m.group(1)!;
      final ext = m.group(2)!;
      _images.add(_EditorImage(
        id: imgId,
        fullPath: '/images/posts/$_id-$imgId.$ext',
        isPending: false,
      ));
    }
  }

  Future<void> _fetchNextId() async {
    try {
      final files = await context.read<GithubService>().fetchFiles();
      if (mounted) setState(() => _id = files.length + 1);
    } catch (_) {}
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请填写标题')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final service = context.read<GithubService>();

      // Delete removed images
      for (final path in _pendingDeletes) {
        try {
          await service.deleteFileByPath('images/posts/${path.split('/').last}');
        } catch (e) {
          debugPrint('Delete failed for $path: $e');
        }
      }

      // Upload new images
      for (final img in _images) {
        if (img.isPending && img.pendingBytes != null) {
          await service.uploadImage(img.fullPath.split('/').last, img.pendingBytes!);
        }
      }

      final content = _buildContent();
      final safeTitle = _titleController.text.trim().replaceAll(
        RegExp(r'[<>:"/\\|?*]'), '');

      if (_isEditing) {
        final oldName = widget.existingFileName!.split('/').last;
        final prefix = RegExp(r'^(\d{4}-\d{2}-\d{2}-)').firstMatch(oldName)?.group(1) ?? '';
        final newName = '$prefix$safeTitle.md';

        if (newName != oldName) {
          await service.createFile(newName, content);
          await service.deleteFile(widget.existingFileName!, widget.existingSha!);
        } else {
          await service.updateFile(widget.existingFileName!, content, widget.existingSha!);
        }
      } else {
        await service.createFile('$safeTitle.md', content);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('保存失败，请重试')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _buildContent() {
    const knownKeys = {'title', 'date', 'category', 'tags', 'id', 'author'};
    final buf = StringBuffer()
      ..writeln('---')
      ..writeln('title: ${_titleController.text.trim()}')
      ..writeln('id: $_id')
      ..writeln('date: ${_date.toIso8601String()}')
      ..writeln('category: $_category');
    if (_authors.isNotEmpty) buf.writeln('author: [${_authors.join(', ')}]');
    buf.writeln('tags: [${_tags.join(', ')}]');
    for (final e in _customProps.entries) {
      if (!knownKeys.contains(e.key.toLowerCase())) {
        buf.writeln('${e.key}: ${e.value}');
      }
    }
    buf
      ..writeln('---')
      ..writeln()
      ..writeln(_bodyController.text);
    return buf.toString();
  }

  Future<void> _pickImage() async {
    if (_id == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Wait for ID...')));
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      if (file.bytes == null) return;

      setState(() => _isSaving = true);

      final uid = DateTime.now().millisecondsSinceEpoch.toString();
      final ext = file.extension ?? 'jpg';
      final fileName = '$_id-$uid.$ext';
      final img = _EditorImage(
        id: uid,
        fullPath: '/images/posts/$fileName',
        isPending: true,
        pendingBytes: file.bytes,
      );
      _images.add(img);

      final insertText = '\n![](/images/posts/$fileName)\n';
      final pos = _bodyController.selection.base.offset;
      if (pos >= 0) {
        _bodyController.text =
            '${_bodyController.text.substring(0, pos)}$insertText${_bodyController.text.substring(pos)}';
      } else {
        _bodyController.text += insertText;
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('图片插入失败，请重试')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _removeImage(int index) {
    if (index < 0 || index >= _images.length) return;
    final img = _images[index];
    if (!img.isPending) {
      _pendingDeletes.add(img.originalPath ?? img.fullPath);
    }
    final pattern = '![](${img.fullPath})';
    _bodyController.text = _bodyController.text
        .replaceAll('\n$pattern\n', '\n')
        .replaceAll(pattern, '');
    setState(() => _images.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_id != null ? 'Post #$_id' : 'New Post',
            style: const TextStyle(color: Colors.black, fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.image_outlined, color: Colors.black87),
            tooltip: 'Insert Image',
            onPressed: _isSaving ? null : _pickImage,
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Colors.black87),
            tooltip: 'Post Settings',
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
            child: FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_rounded, size: 18),
              label: const Text('Publish'),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ),
        ],
      ),
      endDrawer: _buildSettingsDrawer(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              if (_images.isNotEmpty) _buildImageBar(),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: TextField(
                  controller: _titleController,
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.bold, height: 1.3),
                  decoration: const InputDecoration(
                    hintText: 'Enter title...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.black26),
                  ),
                  maxLines: null,
                ),
              ),
              const Divider(indent: 24, endIndent: 24, height: 30),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: TextField(
                    controller: _bodyController,
                    style: const TextStyle(
                        fontSize: 16, height: 1.6, color: Colors.black87),
                    decoration: const InputDecoration(
                      hintText: 'Start writing your story...',
                      border: InputBorder.none,
                    ),
                    maxLines: null,
                    expands: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageBar() {
    return Container(
      height: 100,
      color: Colors.grey[50],
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: _images.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final img = _images[i];
          final highlighted = img.id == _highlightedImageId;
          return Stack(
            children: [
              Container(
                width: 80,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: highlighted ? Colors.blue : Colors.grey[300]!,
                    width: highlighted ? 3 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                ),
                clipBehavior: Clip.antiAlias,
                child: img.isPending && img.pendingBytes != null
                    ? Image.memory(Uint8List.fromList(img.pendingBytes!),
                        fit: BoxFit.cover)
                    : Image.network(
                        DataSourceManager.instance.rawUrl(img.fullPath),
                        headers: DataSourceManager.instance.imageHeaders,
                        fit: BoxFit.cover,
                        errorBuilder: (context, err, stack) =>
                            const Icon(Icons.broken_image, color: Colors.grey),
                      ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: InkWell(
                  onTap: () => _removeImage(i),
                  child: Container(
                    decoration: const BoxDecoration(
                        color: Colors.black54, shape: BoxShape.circle),
                    padding: const EdgeInsets.all(4),
                    child: const Icon(Icons.close, color: Colors.white, size: 12),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.black45,
                  padding: const EdgeInsets.all(2),
                  child: Text('#${i + 1}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 10)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSettingsDrawer() {
    return Drawer(
      width: 320,
      backgroundColor: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            color: Colors.grey[50],
            child: const Row(
              children: [
                Icon(Icons.tune, size: 20),
                SizedBox(width: 12),
                Text('Post Settings',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _label('Post ID'),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Post ID',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                  ),
                  keyboardType: TextInputType.number,
                  controller: TextEditingController(text: _id?.toString() ?? ''),
                  onChanged: (val) {
                    final newId = int.tryParse(val);
                    if (newId != null && _id != null && newId != _id) {
                      final oldPattern = '/images/posts/$_id-';
                      final newPattern = '/images/posts/$newId-';
                      if (_bodyController.text.contains(oldPattern)) {
                        _bodyController.text = _bodyController.text
                            .replaceAll(oldPattern, newPattern);
                      }
                      for (var i = 0; i < _images.length; i++) {
                        final img = _images[i];
                        final suffix = img.fullPath.split('-').last;
                        _images[i] = img.copyWith(
                            fullPath: '/images/posts/$newId-$suffix');
                      }
                    }
                    setState(() => _id = newId);
                  },
                ),
                const SizedBox(height: 32),

                _label('Date'),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const Icon(Icons.calendar_today_rounded,
                            size: 16, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                _label('Category'),
                Wrap(
                  spacing: 8,
                  children: ['Diaries', 'Letters'].map((cat) {
                    final selected =
                        _category.toLowerCase() == cat.toLowerCase();
                    return ChoiceChip(
                      label: Text(cat),
                      selected: selected,
                      onSelected: (s) {
                        if (s) setState(() => _category = cat);
                      },
                      selectedColor: Colors.black,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : Colors.black87,
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      backgroundColor: Colors.grey[100],
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      side: BorderSide.none,
                      checkmarkColor: Colors.white,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),

                _label('Author'),
                Wrap(
                  spacing: 8,
                  children: [CoupleConfig.person1Name, CoupleConfig.person2Name]
                      .where((n) => n.isNotEmpty)
                      .toList()
                      .map((author) {
                    final selected = _authors.contains(author);
                    return FilterChip(
                      label: Text(author),
                      selected: selected,
                      onSelected: (s) => setState(() {
                        if (s) {
                          if (!_authors.contains(author)) _authors.add(author);
                        } else {
                          _authors.remove(author);
                        }
                      }),
                      selectedColor: Colors.black,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : Colors.black87,
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      backgroundColor: Colors.grey[100],
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      side: BorderSide.none,
                      checkmarkColor: Colors.white,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),

                _label('Tags'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._tags.map((tag) => Chip(
                          label: Text(tag,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Source Han Serif CN',
                                  fontWeight: FontWeight.normal)),
                          deleteIcon: const Icon(Icons.close, size: 14),
                          onDeleted: () => setState(() => _tags.remove(tag)),
                          backgroundColor: Colors.grey[100],
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          side: BorderSide.none,
                        )),
                    ActionChip(
                      label: const Icon(Icons.add, size: 16),
                      onPressed: _showAddTagDialog,
                      backgroundColor: Colors.white,
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                _label('Custom Properties'),
                ..._customProps.entries.map((e) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        children: [
                          Text(e.key,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                          const Text(': ',
                              style: TextStyle(color: Colors.grey)),
                          Expanded(
                            child: Text(e.value,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13)),
                          ),
                          InkWell(
                            onTap: () =>
                                setState(() => _customProps.remove(e.key)),
                            child: const Icon(Icons.close,
                                size: 16, color: Colors.red),
                          ),
                        ],
                      ),
                    )),
                TextButton.icon(
                  onPressed: _showAddPropertyDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Field'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.black54,
                    alignment: Alignment.centerLeft,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              _isEditing ? 'Editing existing file.' : 'Creating new file.',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0),
        ),
      );

  void _showAddTagDialog() {
    String tag = '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Tag'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Tag name'),
          onChanged: (v) => tag = v,
          onSubmitted: (_) {
            if (tag.isNotEmpty) setState(() => _tags.add(tag));
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (tag.isNotEmpty) setState(() => _tags.add(tag));
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddPropertyDialog() {
    final keyCtrl = TextEditingController();
    final valCtrl = TextEditingController();
    const reserved = {'title', 'date', 'category', 'tags', 'id', 'author'};

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Custom Field'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: keyCtrl,
                decoration:
                    const InputDecoration(labelText: 'Key (e.g. abstract)')),
            const SizedBox(height: 12),
            TextField(controller: valCtrl,
                decoration: const InputDecoration(labelText: 'Value')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final k = keyCtrl.text.trim();
              final v = valCtrl.text.trim();
              if (k.isNotEmpty && v.isNotEmpty) {
                if (reserved.contains(k.toLowerCase())) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Use standard controls for core fields.')),
                  );
                } else {
                  setState(() => _customProps[k] = v);
                }
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
