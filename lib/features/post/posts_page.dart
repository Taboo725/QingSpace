import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/github_service.dart';
import '../../core/widgets/page_state_widget.dart';
import '../../models/post.dart';
import '../home/widgets/post_card.dart';
import 'post_detail_page.dart';
import 'post_editor_page.dart';

enum SortOption { dateNewest, dateOldest, titleAZ, titleZA }

class PostsPage extends StatefulWidget {
  final String? categoryFilter;

  const PostsPage({super.key, this.categoryFilter});

  @override
  State<PostsPage> createState() => _PostsPageState();
}

class _PostsPageState extends State<PostsPage> {
  late Future<List<Post>> _postsFuture;
  SortOption _currentSort = SortOption.dateNewest;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  // Need to update when category changes
  @override
  void didUpdateWidget(PostsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categoryFilter != widget.categoryFilter) {
      _refresh();
    }
  }

  void _refresh() {
    setState(() {
      _postsFuture = Provider.of<GithubService>(
        context,
        listen: false,
      ).fetchFiles(category: widget.categoryFilter);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Handled by Main layout
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PostEditorPage()),
          );
          if (result == true) _refresh();
        },
        tooltip: '新建文章',
        child: const Icon(Icons.edit_note),
      ),
      body: FutureBuilder<List<Post>>(
        future: _postsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return RefreshIndicator(
              onRefresh: () async { _refresh(); },
              child: ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.5,
                    child: Center(
                      child: PageStateWidget.error(
                        message: '加载失败，下拉可重试',
                        onRetry: _refresh,
                      ),
                    ),
                  ),
                ],
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async { _refresh(); },
              child: ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.5,
                    child: Center(
                      child: PageStateWidget.empty(
                        message: '还没有文章，快去写第一篇吧',
                        icon: Icons.article_outlined,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          final posts = List<Post>.from(snapshot.data!);

          // Sort logic
          posts.sort((a, b) {
            switch (_currentSort) {
              case SortOption.dateNewest:
                int cmp = b.date.compareTo(a.date);
                if (cmp == 0) return b.title.compareTo(a.title);
                return cmp;
              case SortOption.dateOldest:
                int cmp = a.date.compareTo(b.date);
                if (cmp == 0) return a.title.compareTo(b.title);
                return cmp;
              case SortOption.titleAZ:
                return a.title.toLowerCase().compareTo(b.title.toLowerCase());
              case SortOption.titleZA:
                return b.title.toLowerCase().compareTo(a.title.toLowerCase());
            }
          });

          final isMobile = MediaQuery.sizeOf(context).width < 600;
          return Column(
            children: [
              // Beautiful Header with Sort
              Padding(
                padding: EdgeInsets.fromLTRB(
                    24, isMobile ? 6 : 16, 24, isMobile ? 2 : 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${posts.length} entries',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        letterSpacing: 0.5,
                      ),
                    ),
                    PopupMenuButton<SortOption>(
                      initialValue: _currentSort,
                      onSelected: (SortOption item) {
                        setState(() {
                          _currentSort = item;
                        });
                      },
                      icon: Icon(
                        Icons.sort_rounded,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      tooltip: 'Sort by',
                      itemBuilder: (BuildContext context) =>
                          <PopupMenuEntry<SortOption>>[
                            const PopupMenuItem<SortOption>(
                              value: SortOption.dateNewest,
                              child: Text('Date (Newest first)'),
                            ),
                            const PopupMenuItem<SortOption>(
                              value: SortOption.dateOldest,
                              child: Text('Date (Oldest first)'),
                            ),
                            const PopupMenuItem<SortOption>(
                              value: SortOption.titleAZ,
                              child: Text('Title (A-Z)'),
                            ),
                            const PopupMenuItem<SortOption>(
                              value: SortOption.titleZA,
                              child: Text('Title (Z-A)'),
                            ),
                          ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    _refresh();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
                      final post = posts[index];
                      return PostCard(
                        post: post,
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PostDetailPage(
                                fileName: post.path,
                                sha: post.sha,
                              ),
                            ),
                          );
                          if (result == true) _refresh();
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
