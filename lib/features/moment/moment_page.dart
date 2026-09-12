import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/moment_service.dart';
import '../../core/widgets/fullscreen_photo_page.dart';
import '../../core/widgets/net_image.dart';
import '../../core/widgets/page_state_widget.dart';
import '../../models/moment.dart';
import 'moment_editor_page.dart';

/// One `yyyy年MM月` section of the timeline.
typedef _MonthGroup = ({String label, List<Moment> moments});

class MomentsPage extends StatefulWidget {
  const MomentsPage({super.key});

  @override
  State<MomentsPage> createState() => _MomentsPageState();
}

class _MomentsPageState extends State<MomentsPage> {
  final MomentsService _service = MomentsService();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _scrollViewKey = GlobalKey();

  /// Per-month render keys and "is this header currently pinned" flags, kept in
  /// step with [_groups] so they never accumulate entries for filtered-out
  /// months.
  final Map<String, GlobalKey> _headerKeys = {};
  final Map<String, ValueNotifier<bool>> _headerPinned = {};

  List<Moment> _allMoments = const [];
  List<_MonthGroup> _groups = const [];
  int _visibleCount = 0;

  bool _isLoading = true;
  bool _hasError = false;
  bool _isAscending = false; // Default: newest first
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _loadMoments();
    _scrollController.addListener(_updatePinnedHeaders);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (final notifier in _headerPinned.values) {
      notifier.dispose();
    }
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<void> _loadMoments() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final moments = await _service.fetchMoments();
      if (!mounted) return;
      setState(() {
        _allMoments = moments;
        _rebuildGroups();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  /// Applies the date filter and sort order, then regroups by month.
  void _rebuildGroups() {
    final selected = _selectedDate;
    final filtered = selected == null
        ? _allMoments.toList()
        : _allMoments
              .where(
                (m) =>
                    m.date.year == selected.year &&
                    m.date.month == selected.month &&
                    m.date.day == selected.day,
              )
              .toList();

    filtered.sort(
      (a, b) =>
          _isAscending ? a.date.compareTo(b.date) : b.date.compareTo(a.date),
    );

    final byMonth = <String, List<Moment>>{};
    for (final moment in filtered) {
      byMonth
          .putIfAbsent(_monthFormat.format(moment.date), () => [])
          .add(moment);
    }

    _visibleCount = filtered.length;
    _groups = [
      for (final entry in byMonth.entries)
        (label: entry.key, moments: entry.value),
    ];
    _syncHeaderState();
  }

  /// Adds keys/notifiers for new months and disposes those no longer shown.
  void _syncHeaderState() {
    final labels = {for (final group in _groups) group.label};

    for (final label in labels) {
      _headerKeys.putIfAbsent(label, GlobalKey.new);
      _headerPinned.putIfAbsent(label, () => ValueNotifier(false));
    }
    for (final stale in _headerPinned.keys.toSet().difference(labels)) {
      _headerPinned.remove(stale)?.dispose();
      _headerKeys.remove(stale);
    }
  }

  /// Marks the header whose top edge sits flush with the viewport top, which is
  /// what lets it fade the content scrolling beneath it.
  void _updatePinnedHeaders() {
    if (!mounted || _headerPinned.length < 2) return;
    final scrollBox =
        _scrollViewKey.currentContext?.findRenderObject() as RenderBox?;
    if (scrollBox == null) return;

    final viewportTop = scrollBox.localToGlobal(Offset.zero).dy;
    final scrolled = _scrollController.offset > 1.0;

    for (final entry in _headerPinned.entries) {
      final headerBox =
          _headerKeys[entry.key]?.currentContext?.findRenderObject()
              as RenderBox?;
      if (headerBox == null || !headerBox.attached) continue;
      final delta = headerBox.localToGlobal(Offset.zero).dy - viewportTop;
      entry.value.value = scrolled && delta.abs() <= 2.0;
    }
  }

  // ── Filters ───────────────────────────────────────────────────────────────

  void _toggleSort() => setState(() {
    _isAscending = !_isAscending;
    _rebuildGroups();
  });

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = picked;
      _rebuildGroups();
    });
  }

  void _clearFilter() => setState(() {
    _selectedDate = null;
    _rebuildGroups();
  });

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _openEditor([Moment? moment]) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => MomentsEditorPage(editMoment: moment)),
    );
    if (result == true) await _loadMoments();
  }

  Future<void> _confirmDelete(Moment moment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Moment?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final imageRemoved = await _service.deleteMoment(moment);
      if (!mounted) return;
      // Update locally rather than refetching: the CDN needs a moment to catch
      // up, so an immediate reload would resurrect the deleted entry.
      setState(() {
        _allMoments = _allMoments
            .where((m) => !m.date.isAtSameMomentAs(moment.date))
            .toList();
        _rebuildGroups();
        _isLoading = false;
      });
      if (!imageRemoved) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('随记已删除，但配图未能移除')));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('操作失败，请重试')));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return Scaffold(
      // Transparent so the home background shows through.
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: _openEditor,
        tooltip: '发布动态',
        child: const Icon(Icons.add_comment),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  children: [
                    if (!_hasError) _buildToolbar(isMobile),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadMoments,
                        child: _hasError
                            ? PageStateWidget.pullToRefreshBody(
                                context,
                                PageStateWidget.error(onRetry: _loadMoments),
                              )
                            : _buildTimeline(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildToolbar(bool isMobile) {
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, isMobile ? 6 : 16, 24, isMobile ? 2 : 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$_visibleCount moments',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
          Row(
            children: [
              if (_selectedDate != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InputChip(
                    label: Text(_dayFormat.format(_selectedDate!)),
                    onPressed: _pickDate,
                    onDeleted: _clearFilter,
                    deleteIcon: const Icon(Icons.close, size: 16),
                    avatar: const Icon(Icons.calendar_today, size: 16),
                  ),
                )
              else
                IconButton(
                  icon: Icon(Icons.calendar_today, color: onSurfaceVariant),
                  tooltip: 'Filter by date',
                  onPressed: _pickDate,
                ),
              IconButton(
                icon: Icon(
                  _isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  color: onSurfaceVariant,
                ),
                tooltip: _isAscending ? 'Oldest first' : 'Newest first',
                onPressed: _toggleSort,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    return CustomScrollView(
      key: _scrollViewKey,
      controller: _scrollController,
      // Left at the framework default: CustomScrollView.cacheExtent was
      // deprecated in Flutter 3.41 in favour of scrollCacheExtent, and the
      // tuning is not worth a version-dependent API. Tiles are cheap to build
      // now that _MomentTile is its own widget and images decode downscaled.
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: _groups.isEmpty
          ? [
              SliverFillRemaining(
                child: Center(
                  child: PageStateWidget.empty(
                    message: '暂无随记',
                    icon: Icons.comment_outlined,
                  ),
                ),
              ),
            ]
          : [
              for (final group in _groups)
                SliverMainAxisGroup(
                  slivers: [
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _MonthHeaderDelegate(
                        title: group.label,
                        color: Theme.of(context).primaryColor,
                        isPinned: _headerPinned[group.label]!,
                        contentKey: _headerKeys[group.label]!,
                      ),
                    ),
                    SliverList.builder(
                      itemCount: group.moments.length,
                      itemBuilder: (context, index) => _MomentTile(
                        moment: group.moments[index],
                        onEdit: _openEditor,
                        onDelete: _confirmDelete,
                      ),
                    ),
                  ],
                ),
            ],
    );
  }
}

final DateFormat _monthFormat = DateFormat('yyyy年MM月');
final DateFormat _dayFormat = DateFormat('yyyy-MM-dd');
final DateFormat _dayOfMonthFormat = DateFormat('dd');
final DateFormat _weekdayFormat = DateFormat('EEE');
final DateFormat _timeFormat = DateFormat('HH:mm');

// ── Timeline entry ──────────────────────────────────────────────────────────

class _MomentTile extends StatelessWidget {
  final Moment moment;
  final ValueChanged<Moment> onEdit;
  final ValueChanged<Moment> onDelete;

  const _MomentTile({
    required this.moment,
    required this.onEdit,
    required this.onDelete,
  });

  String get _heroTag => '${moment.date}_${moment.image}';

  void _openPhoto(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          FullscreenPhotoPage(imageUrl: moment.image!, heroTag: _heroTag),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final image = moment.image;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 50,
            child: Column(
              children: [
                Text(
                  _dayOfMonthFormat.format(moment.date),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: theme.primaryColor,
                  ),
                ),
                Text(
                  _weekdayFormat.format(moment.date).toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.primaryColor.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (image != null && image.isNotEmpty)
                      GestureDetector(
                        onTap: () => _openPhoto(context),
                        child: Hero(
                          tag: _heroTag,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 300),
                            child: NetImage(
                              imageUrl: image,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              // Timeline images are at most 300 px tall; decoding
                              // the original would cost tens of MB per photo.
                              memCacheWidth: 900,
                              placeholder: (_, _) => const ImageLoadingBox(),
                              errorWidget: (_, _, _) => const ImageErrorBox(
                                height: 200,
                                compact: true,
                              ),
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            moment.content,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.6,
                              color: Colors.grey[800],
                              fontFamily: 'Source Han Serif CN',
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildFooter(context, theme),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, ThemeData theme) {
    final mood = moment.mood;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.access_time, size: 14, color: Colors.grey[400]),
            const SizedBox(width: 4),
            Text(
              _timeFormat.format(moment.date),
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            if (mood != null && mood.isNotEmpty) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  mood,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.primaryColor,
                  ),
                ),
              ),
            ],
          ],
        ),
        PopupMenuButton<String>(
          onSelected: (value) =>
              value == 'edit' ? onEdit(moment) : onDelete(moment),
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 18, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete'),
                ],
              ),
            ),
          ],
          child: const Icon(Icons.more_horiz, size: 18, color: Colors.grey),
        ),
      ],
    );
  }
}

// ── Pinned month header ─────────────────────────────────────────────────────

class _MonthHeaderDelegate extends SliverPersistentHeaderDelegate {
  static const double _height = 60;

  final String title;
  final Color color;

  /// True while this header is the one stuck to the viewport top.
  final ValueNotifier<bool> isPinned;
  final GlobalKey contentKey;

  const _MonthHeaderDelegate({
    required this.title,
    required this.color,
    required this.isPinned,
    required this.contentKey,
  });

  @override
  double get maxExtent => _height;

  @override
  double get minExtent => _height;

  @override
  bool shouldRebuild(covariant _MonthHeaderDelegate old) =>
      old.title != title ||
      old.color != color ||
      old.isPinned != isPinned ||
      old.contentKey != contentKey;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final pillColor = Color.lerp(color, Colors.white, 0.2) ?? color;
    final background = Theme.of(context).scaffoldBackgroundColor;

    return ValueListenableBuilder<bool>(
      valueListenable: isPinned,
      builder: (context, pinned, _) => SizedBox(
        key: contentKey,
        height: _height,
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            // Fades out the content sliding beneath a stuck header.
            if (pinned)
              Positioned(
                left: 78,
                right: 0,
                top: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        background.withValues(alpha: 0.95),
                        background.withValues(alpha: 0),
                      ],
                      stops: const [0.5, 1.0],
                    ),
                  ),
                ),
              ),
            Row(
              children: [
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: pillColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12, right: 16),
                    child: Divider(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
