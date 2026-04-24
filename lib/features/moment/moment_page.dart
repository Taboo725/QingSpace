import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/widgets/cdn_image.dart';
import '../../core/widgets/fullscreen_photo_page.dart';
import '../../core/widgets/page_state_widget.dart';
import '../../core/services/moment_service.dart';
import '../../models/moment.dart';
import 'moment_editor_page.dart';

class MomentsPage extends StatefulWidget {
  const MomentsPage({super.key});

  @override
  State<MomentsPage> createState() => _MomentsPageState();
}

class _MomentsPageState extends State<MomentsPage> {
  final MomentsService _service = MomentsService();
  List<Moment> _allMoments = [];
  List<Moment> _filteredMoments = [];
  bool _isLoading = true;
  bool _hasError = false;
  bool _isAscending = false; // Default desc (newest first)
  DateTime? _selectedDate;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _scrollViewKey = GlobalKey();
  final Map<String, GlobalKey> _headerKeys = {};
  final Map<String, ValueNotifier<bool>> _headerOverlapping = {};

  @override
  void initState() {
    super.initState();
    _loadMoments();
    _scrollController.addListener(_updateHeaderOverlap);
  }

  void _updateHeaderOverlap() {
    if (!mounted) return;
    final svBox = _scrollViewKey.currentContext?.findRenderObject() as RenderBox?;
    if (svBox == null) return;
    final svTopGlobal = svBox.localToGlobal(Offset.zero).dy;
    for (final entry in _headerOverlapping.entries) {
      final hBox = _headerKeys[entry.key]?.currentContext?.findRenderObject() as RenderBox?;
      if (hBox == null || !hBox.attached) continue;
      final diff = hBox.localToGlobal(Offset.zero).dy - svTopGlobal;
      // Pinned = header's top aligns with scroll view's top, and list has scrolled
      entry.value.value = diff.abs() <= 2.0 && _scrollController.offset > 1.0;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (final n in _headerOverlapping.values) n.dispose();
    super.dispose();
  }

  Future<void> _loadMoments() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final moments = await _service.fetchMoments();
      if (mounted) {
        setState(() {
          _allMoments = moments;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
    }
  }

  void _applyFilters() {
    List<Moment> temp = List.from(_allMoments);

    // Filter by date if selected
    if (_selectedDate != null) {
      temp = temp
          .where(
            (m) =>
                m.date.year == _selectedDate!.year &&
                m.date.month == _selectedDate!.month &&
                m.date.day == _selectedDate!.day,
          )
          .toList();
    }

    // Sort
    temp.sort((a, b) {
      return _isAscending ? a.date.compareTo(b.date) : b.date.compareTo(a.date);
    });

    _filteredMoments = temp;
  }

  void _toggleSort() {
    setState(() {
      _isAscending = !_isAscending;
      _applyFilters();
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _applyFilters();
      });
    }
  }

  void _clearFilter() {
    setState(() {
      _selectedDate = null;
      _applyFilters();
    });
  }

  // Helper to group moments by Year-Month
  Map<String, List<Moment>> _groupMoments() {
    final Map<String, List<Moment>> grouped = {};
    for (var m in _filteredMoments) {
      final key = DateFormat('yyyy年MM月').format(m.date);
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(m);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    // Move layout building inside Scaffold to keep FAB visible
    // and consistent with other pages
    final groupedMap = _groupMoments();
    final keys = groupedMap.keys.toList();

    final isMobile = MediaQuery.sizeOf(context).width < 600;
    return Scaffold(
      backgroundColor:
          Colors.transparent, // Allow Home background to show through
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MomentsEditorPage()),
          );
          if (result == true) {
            _loadMoments();
          }
        },
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
                    if (!_hasError)
                      // Header Row (Sort & Filter)
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                            24, isMobile ? 6 : 16, 24, isMobile ? 2 : 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_filteredMoments.length} moments',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Row(
                              children: [
                                // Date Filter
                                if (_selectedDate != null)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: InputChip(
                                      label: Text(
                                        DateFormat(
                                          'yyyy-MM-dd',
                                        ).format(_selectedDate!),
                                      ),
                                      onPressed: _pickDate,
                                      onDeleted: _clearFilter,
                                      deleteIcon: const Icon(
                                        Icons.close,
                                        size: 16,
                                      ),
                                      avatar: const Icon(
                                        Icons.calendar_today,
                                        size: 16,
                                      ),
                                    ),
                                  )
                                else
                                  IconButton(
                                    icon: Icon(
                                      Icons.calendar_today,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                    tooltip: "Filter by date",
                                    onPressed: _pickDate,
                                  ),

                                // Sort
                                IconButton(
                                  icon: Icon(
                                    _isAscending
                                        ? Icons.arrow_upward
                                        : Icons.arrow_downward,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                  tooltip: _isAscending
                                      ? "Oldest first"
                                      : "Newest first",
                                  onPressed: _toggleSort,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadMoments,
                        child: _hasError
                            ? ListView(
                                children: [
                                  SizedBox(
                                    height:
                                        MediaQuery.sizeOf(context).height * 0.5,
                                    child: Center(
                                      child: PageStateWidget.error(
                                        message: '加载失败',
                                        onRetry: _loadMoments,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : CustomScrollView(
                                key: _scrollViewKey,
                                controller: _scrollController,
                                cacheExtent: 500,
                                physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                ),
                                slivers: keys.isEmpty
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
                                    : keys.map((monthKey) {
                                        final monthMoments =
                                            groupedMap[monthKey]!;
                                        _headerKeys.putIfAbsent(
                                            monthKey, () => GlobalKey());
                                        _headerOverlapping.putIfAbsent(
                                            monthKey,
                                            () => ValueNotifier(false));
                                        return SliverMainAxisGroup(
                                          slivers: [
                                            SliverPersistentHeader(
                                              pinned: true,
                                              delegate: _MonthHeaderDelegate(
                                                title: monthKey,
                                                color: Theme.of(context)
                                                    .primaryColor,
                                                isOverlapping:
                                                    _headerOverlapping[
                                                        monthKey]!,
                                                contentKey:
                                                    _headerKeys[monthKey]!,
                                              ),
                                            ),
                                            SliverList(
                                              delegate:
                                                  SliverChildBuilderDelegate((
                                                context,
                                                index,
                                              ) {
                                                return _buildMomentItem(
                                                  monthMoments[index],
                                                );
                                              },
                                                  childCount:
                                                      monthMoments.length),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMomentItem(Moment moment) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0, left: 16, right: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date Column
          SizedBox(
            width: 50,
            child: Column(
              children: [
                Text(
                  DateFormat('dd').format(moment.date),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                Text(
                  DateFormat(
                    'EEE',
                  ).format(moment.date).toUpperCase(), // MON, TUE
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Content Bubble
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4), // Slightly softer corner
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.06), // Tinted shadow
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.hardEdge,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image Section
                  if (moment.image != null)
                    GestureDetector(
                      // Wrap image with gesture for full view
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FullscreenPhotoPage(
                              imageUrl: moment.image!,
                              heroTag: '${moment.date}_${moment.image}',
                            ),
                          ),
                        );
                      },
                      child: Hero(
                        tag: '${moment.date}_${moment.image}',
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 300),
                          child: NetImage(
                            imageUrl: moment.image!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              height: 200,
                              color: Colors.grey[50],
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Theme.of(context).colorScheme.secondary
                                      .withValues(alpha: 0.5),
                                ), // Custom loader color
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              height: 200,
                              color: Colors.grey[50],
                              child: Icon(
                                Icons.broken_image,
                                color: Colors.grey[300],
                              ),
                            ),
                            width: double.infinity,
                          ),
                        ),
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.all(16), // More padding
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat('HH:mm').format(moment.date),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                if (moment.mood != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondaryContainer, // Accent bg
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      moment.mood!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(
                                          context,
                                        ).primaryColor, // Contrast text
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'edit') {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          MomentsEditorPage(editMoment: moment),
                                    ),
                                  );
                                  if (result == true) _loadMoments();
                                } else if (value == 'delete') {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text("Delete Moment?"),
                                      content: const Text(
                                        "This action cannot be undone.",
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text("Cancel"),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text(
                                            "Delete",
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    setState(() => _isLoading = true);
                                    try {
                                      await _service.deleteMoment(moment);
                                      // Update local list directly instead of fetching from remote (which needs cache time)
                                      setState(() {
                                        _allMoments.removeWhere(
                                          (m) => m.date.isAtSameMomentAs(
                                            moment.date,
                                          ),
                                        );
                                        _applyFilters();
                                        _isLoading = false;
                                      });
                                    } catch (e) {
                                      if (mounted) {
                                        setState(() => _isLoading = false);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text("操作失败，请重试")),
                                        );
                                      }
                                    }
                                  }
                                }
                              },
                              itemBuilder: (BuildContext context) =>
                                  <PopupMenuEntry<String>>[
                                    const PopupMenuItem<String>(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.edit,
                                            size: 18,
                                            color: Colors.blue,
                                          ),
                                          SizedBox(width: 8),
                                          Text('Edit'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem<String>(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.delete,
                                            size: 18,
                                            color: Colors.red,
                                          ),
                                          SizedBox(width: 8),
                                          Text('Delete'),
                                        ],
                                      ),
                                    ),
                                  ],
                              child: const Icon(
                                Icons.more_horiz,
                                size: 18,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  final Color color;
  final ValueNotifier<bool> isOverlapping;
  final GlobalKey contentKey;

  _MonthHeaderDelegate({
    required this.title,
    required this.color,
    required this.isOverlapping,
    required this.contentKey,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final pillColor = Color.lerp(color, Colors.white, 0.2) ?? color;

    return ValueListenableBuilder<bool>(
      valueListenable: isOverlapping,
      builder: (context, overlapping, _) {
        return SizedBox(
          key: contentKey,
          height: 60,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Gradient mask: only shown when THIS header is pinned at the
              // viewport top and content is scrolling beneath it.
              if (overlapping)
                Positioned(
                  left: 78,
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Theme.of(context).scaffoldBackgroundColor.withValues(
                            alpha: 0.95,
                          ),
                          Theme.of(context).scaffoldBackgroundColor.withValues(
                            alpha: 0.0,
                          ),
                        ],
                        stops: const [0.5, 1.0],
                      ),
                    ),
                  ),
                ),

              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
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
                    child: Container(
                      margin: const EdgeInsets.only(left: 12),
                      padding: const EdgeInsets.only(right: 16),
                      child: Divider(
                        color: Colors.grey.withValues(alpha: 0.3),
                        indent: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  double get maxExtent => 60.0;

  @override
  double get minExtent => 60.0;

  @override
  bool shouldRebuild(covariant _MonthHeaderDelegate old) =>
      old.title != title || old.color != color;
}

