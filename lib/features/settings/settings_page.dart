import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/config/app_config.dart';
import '../../core/config/version.dart';
import '../../core/services/couple_config.dart';
import '../../core/services/data_source_manager.dart';
import '../../core/services/gitee_client.dart';
import '../../core/services/github_client.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/theme/theme_config.dart';
import '../onboarding/onboarding_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // GitHub
  final _ghTokenController = TextEditingController();
  final _ghUserController = TextEditingController();
  final _ghRepoController = TextEditingController();
  final _ghBranchController = TextEditingController();
  bool _obscureGhToken = true;

  // Gitee
  final _giteeTokenController = TextEditingController();
  final _giteeUserController = TextEditingController();
  final _giteeRepoController = TextEditingController();
  final _giteeBranchController = TextEditingController();
  bool _obscureGiteeToken = true;

  // Sync status
  SyncStatus? _syncStatus;
  String? _syncGithubSha;
  String? _syncGiteeSha;
  String? _syncError;
  bool _syncChecking = false;
  DateTime? _syncLastChecked;

  @override
  void initState() {
    super.initState();
    _ghTokenController.text = GitHubClient.currentToken;
    _ghUserController.text = GitHubClient.user;
    _ghRepoController.text = GitHubClient.repo;
    _ghBranchController.text = GitHubClient.branch;

    _giteeTokenController.text = GiteeClient.currentToken;
    _giteeUserController.text = GiteeClient.user;
    _giteeRepoController.text = GiteeClient.repo;
    _giteeBranchController.text = GiteeClient.branch;
  }

  @override
  void dispose() {
    _ghTokenController.dispose();
    _ghUserController.dispose();
    _ghRepoController.dispose();
    _ghBranchController.dispose();
    _giteeTokenController.dispose();
    _giteeUserController.dispose();
    _giteeRepoController.dispose();
    _giteeBranchController.dispose();
    super.dispose();
  }

  Future<void> _checkSyncStatus() async {
    if (_syncChecking) return;
    setState(() {
      _syncChecking = true;
      _syncError = null;
    });
    final result = await DataSourceManager.instance.checkSyncStatus();
    if (mounted) {
      setState(() {
        _syncStatus = result.status;
        _syncGithubSha = result.githubSha;
        _syncGiteeSha = result.giteeSha;
        _syncError = result.error;
        _syncLastChecked = DateTime.now();
        _syncChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionHeader('Profile'),
              _buildProfileSection(context),
              const SizedBox(height: 24),
              _buildSectionHeader('Data Sources'),
              _buildDataSourcesSection(context),
              const SizedBox(height: 24),
              _buildSectionHeader('Appearance'),
              _buildThemeSection(context),
              const SizedBox(height: 24),
              _buildSectionHeader('Development'),
              _buildDebugSection(context),
              const SizedBox(height: 24),
              _buildSectionHeader('About'),
              _buildAboutSection(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context) {
    final startDate = CoupleConfig.startDate;
    final p1 = CoupleConfig.person1Name;
    final p2 = CoupleConfig.person2Name;
    final subtitle = (p1.isNotEmpty && p2.isNotEmpty)
        ? '$p1  ·  $p2'
        : startDate != null
            ? 'Since ${startDate.year}/${startDate.month.toString().padLeft(2, '0')}/${startDate.day.toString().padLeft(2, '0')}'
            : 'Tap to set up your profile';
    return _buildCard(
      ListTile(
        leading: Icon(
          Icons.favorite_outline_rounded,
          color: Theme.of(context).primaryColor,
        ),
        title: const Text('Couple Profile'),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => const OnboardingPage(isEditing: true),
            ),
          );
          setState(() {}); // refresh subtitle
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  Widget _buildDataSourcesSection(BuildContext context) {
    return _buildCard(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildRepoCardContent(
            title: 'GitHub',
            subtitle: 'github.com repository',
            icon: FaIcon(FontAwesomeIcons.github, size: 20, color: Theme.of(context).primaryColor),
            tokenController: _ghTokenController,
            userController: _ghUserController,
            repoController: _ghRepoController,
            branchController: _ghBranchController,
            obscureToken: _obscureGhToken,
            onToggleObscure: () => setState(() => _obscureGhToken = !_obscureGhToken),
            tokenHint: 'ghp_...',
            onSave: () async {
              final messenger = ScaffoldMessenger.of(context);
              await GitHubClient.saveConfig(
                token: _ghTokenController.text.trim(),
                user: _ghUserController.text.trim(),
                repo: _ghRepoController.text.trim(),
                branch: _ghBranchController.text.trim(),
              );
              await DataSourceManager.instance.setPreference(DataSourceManager.instance.preference);
              messenger.showSnackBar(const SnackBar(content: Text('GitHub config saved')));
            },
            onClear: () async {
              final messenger = ScaffoldMessenger.of(context);
              await GitHubClient.clearConfig();
              _ghTokenController.clear();
              _ghUserController.text = GitHubClient.user;
              _ghRepoController.text = GitHubClient.repo;
              _ghBranchController.text = GitHubClient.branch;
              messenger.showSnackBar(const SnackBar(content: Text('GitHub config cleared')));
            },
          ),
          const Divider(height: 1),
          _buildRepoCardContent(
            title: 'Gitee',
            subtitle: 'gitee.com mirror repository',
            icon: _GiteeIcon(size: 20, color: Theme.of(context).primaryColor),
            tokenController: _giteeTokenController,
            userController: _giteeUserController,
            repoController: _giteeRepoController,
            branchController: _giteeBranchController,
            obscureToken: _obscureGiteeToken,
            onToggleObscure: () => setState(() => _obscureGiteeToken = !_obscureGiteeToken),
            tokenHint: 'your_gitee_token',
            onSave: () async {
              final messenger = ScaffoldMessenger.of(context);
              await GiteeClient.saveConfig(
                token: _giteeTokenController.text.trim(),
                user: _giteeUserController.text.trim(),
                repo: _giteeRepoController.text.trim(),
                branch: _giteeBranchController.text.trim().isEmpty
                    ? 'main'
                    : _giteeBranchController.text.trim(),
              );
              await DataSourceManager.instance.setPreference(DataSourceManager.instance.preference);
              messenger.showSnackBar(const SnackBar(content: Text('Gitee config saved')));
            },
            onClear: () async {
              final messenger = ScaffoldMessenger.of(context);
              await GiteeClient.clearConfig();
              _giteeTokenController.clear();
              _giteeUserController.clear();
              _giteeRepoController.clear();
              _giteeBranchController.text = 'main';
              messenger.showSnackBar(const SnackBar(content: Text('Gitee config cleared')));
            },
          ),
          const Divider(height: 1),
          _buildSourceSelectorContent(context),
          ValueListenableBuilder<DataSource>(
            valueListenable: DataSourceManager.instance.resolvedNotifier,
            builder: (context, resolved, child) {
              if (!GiteeClient.isConfigured) return const SizedBox.shrink();
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Divider(height: 1),
                  _buildSyncStatusContent(),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRepoCardContent({
    required String title,
    required String subtitle,
    required Widget icon,
    required TextEditingController tokenController,
    required TextEditingController userController,
    required TextEditingController repoController,
    required TextEditingController branchController,
    required bool obscureToken,
    required VoidCallback onToggleObscure,
    required String tokenHint,
    required VoidCallback onSave,
    required VoidCallback onClear,
  }) {
    return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                icon,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500)),
                      Text(subtitle,
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: tokenController,
              obscureText: obscureToken,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Access Token',
                hintText: tokenHint,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                suffixIcon: IconButton(
                  icon: Icon(
                      obscureToken ? Icons.visibility_off : Icons.visibility),
                  onPressed: onToggleObscure,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: userController,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Username',
                hintText: 'e.g. your_username',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: repoController,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Repository Name',
                hintText: 'e.g. MyRepoName',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: branchController,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Branch',
                hintText: 'main',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onClear,
                  child: const Text('Clear',
                      style: TextStyle(color: Colors.grey)),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: onSave,
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      );
  }

  Widget _buildSourceSelectorContent(BuildContext context) {
    return ValueListenableBuilder<DataSource>(
      valueListenable: DataSourceManager.instance.resolvedNotifier,
      builder: (context, resolved, _) {
        final pref = DataSourceManager.instance.preference;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.swap_horiz,
                      size: 20, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Active Source',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500)),
                      Text(
                        resolved.name,
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).primaryColor),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: SegmentedButton<DataSource>(
                  segments: [
                    const ButtonSegment(
                        value: DataSource.github,
                        label: Text('GitHub'),
                        icon: FaIcon(FontAwesomeIcons.github, size: 14)),
                    const ButtonSegment(
                        value: DataSource.auto,
                        label: Text('Auto'),
                        icon: Icon(Icons.auto_awesome)),
                    ButtonSegment(
                        value: DataSource.gitee,
                        label: const Text('Gitee'),
                        icon: _GiteeIcon(size: 14)),
                  ],
                  selected: {pref},
                  onSelectionChanged: (selection) async {
                    await DataSourceManager.instance
                        .setPreference(selection.first);
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Auto selects the faster source at startup.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSyncStatusContent() {
    final Color statusColor;
    final IconData statusIcon;
    final String statusLabel;

    if (_syncChecking) {
      statusColor = Colors.grey;
      statusIcon = Icons.hourglass_top_outlined;
      statusLabel = 'Checking…';
    } else {
      switch (_syncStatus) {
        case SyncStatus.synced:
          statusColor = Colors.green;
          statusIcon = Icons.check_circle_outline;
          statusLabel = 'In sync';
        case SyncStatus.outOfSync:
          statusColor = Colors.orange;
          statusIcon = Icons.sync_problem_outlined;
          statusLabel = 'Gitee pending sync';
        case SyncStatus.unknown:
          statusColor = Colors.red.shade400;
          statusIcon = Icons.error_outline;
          statusLabel = 'Check failed';
        case null:
          statusColor = Colors.grey;
          statusIcon = Icons.help_outline;
          statusLabel = 'Not checked';
      }
    }

    final lastCheckedText = _syncLastChecked == null
        ? null
        : () {
            final diff = DateTime.now().difference(_syncLastChecked!);
            if (diff.inSeconds < 60) return 'Just now';
            if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
            return '${diff.inHours}h ago';
          }();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.compare_arrows,
                  size: 20, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Mirror Sync Status',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500)),
                      Text('GitHub → Gitee (writes always to GitHub)',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                _syncChecking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: const Icon(Icons.refresh, size: 20),
                        tooltip: 'Check sync status',
                        onPressed: _checkSyncStatus,
                      ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(statusIcon, size: 18, color: statusColor),
                const SizedBox(width: 8),
                Text(statusLabel,
                    style: TextStyle(
                        color: statusColor, fontWeight: FontWeight.w500)),
                if (lastCheckedText != null) ...[
                  const Spacer(),
                  Text(lastCheckedText,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ],
            ),
            if (_syncGithubSha != null || _syncGiteeSha != null) ...[
              const SizedBox(height: 8),
              DefaultTextStyle(
                style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.grey),
                child: Row(
                  children: [
                    if (_syncGithubSha != null) ...[
                      const Text('GitHub '),
                      Text(_syncGithubSha!,
                          style: const TextStyle(color: Colors.black87)),
                    ],
                    if (_syncGithubSha != null && _syncGiteeSha != null)
                      const Text('  ·  '),
                    if (_syncGiteeSha != null) ...[
                      const Text('Gitee '),
                      Text(
                        _syncGiteeSha!,
                        style: TextStyle(
                            color: _syncStatus == SyncStatus.synced
                                ? Colors.black87
                                : Colors.orange),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (_syncError != null && _syncStatus == SyncStatus.unknown) ...[
              const SizedBox(height: 6),
              Text(
                _syncError!,
                style: TextStyle(fontSize: 12, color: Colors.red.shade300),
              ),
            ],
            if (_syncStatus == SyncStatus.outOfSync) ...[
              const SizedBox(height: 8),
              const Text(
                'Gitee will catch up automatically. You can also trigger a manual sync from the Gitee web console.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
      );
  }

  Widget _buildThemeSection(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return _buildCard(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.palette_outlined,
                      size: 20,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Theme Color',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'Personalize your app appearance',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: AppColorMode.values.map((mode) {
                    final config = ThemeConfig.themes[mode]!;
                    final isSelected = themeProvider.currentMode == mode;

                    return Padding(
                      padding: const EdgeInsets.only(right: 16, bottom: 20),
                      child: GestureDetector(
                        onTap: () => themeProvider.setTheme(mode),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          child: Column(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: config.primaryColor,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      config.primaryColor.withValues(
                                        alpha: 0.8,
                                      ),
                                      config.primaryColor,
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: config.primaryColor.withValues(
                                        alpha: 0.4,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: isSelected
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 24,
                                      )
                                    : null,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                config.name.split(' ').first,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isSelected
                                      ? Theme.of(context).primaryColor
                                      : Colors.grey,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCard(Widget child) {
    return Card(
      elevation: 0,
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: child,
    );
  }

  Widget _buildDebugSection(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppConfig.debugModeNotifier,
      builder: (context, isDebug, _) {
        return _buildCard(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Debug Mode'),
                subtitle: const Text('Enable additional features and logs'),
                secondary: Icon(
                  Icons.bug_report,
                  color: Theme.of(context).primaryColor,
                ),
                value: isDebug,
                activeTrackColor: Theme.of(context).primaryColor,
                onChanged: (value) {
                  AppConfig.debugMode = value;
                },
              ),
              if (isDebug) ...[
                const Divider(height: 1, indent: 16, endIndent: 16),
                ValueListenableBuilder<DateTime?>(
                  valueListenable: AppConfig.debugDateNotifier,
                  builder: (context, debugDate, _) {
                    return ListTile(
                      leading: Icon(
                        Icons.date_range,
                        color: Theme.of(context).primaryColor,
                      ),
                      title: const Text('Debug Date'),
                      subtitle: Text(
                        debugDate != null
                            ? '${debugDate.year}-${debugDate.month.toString().padLeft(2, '0')}-${debugDate.day.toString().padLeft(2, '0')}'
                            : 'Current date (Real-time)',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (debugDate != null)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              tooltip: 'Reset to today',
                              onPressed: () => AppConfig.debugDate = null,
                            ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      onTap: () async {
                        final now = DateTime.now();
                        final initial = debugDate ?? now;
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: initial,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          AppConfig.debugDate = picked;
                        }
                      },
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    return _buildCard(
      ListTile(
        leading: Icon(
          Icons.info_outline,
          color: Theme.of(context).primaryColor,
        ),
        title: const Text('Version'),
        subtitle: const Text(AppVersion.currentVersion),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showChangelog(context),
      ),
    );
  }

  void _showChangelog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Changelog'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
            child: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: AppVersion.changelog.length,
                itemBuilder: (context, index) {
                  final change = AppVersion.changelog[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'v${change['version']} (${change['date']})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(change['changes'] ?? ''),
                    ),
                  );
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

/// Gitee logo mark rendered via [CustomPaint].
/// Draws the official Gitee "G" bracket mark from its Simple Icons SVG path,
/// scaled to [size] × [size] logical pixels.
class _GiteeIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const _GiteeIcon({this.size = 20, this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GiteePainter(
          color: color ?? Theme.of(context).primaryColor,
        ),
      ),
    );
  }
}

class _GiteePainter extends CustomPainter {
  final Color color;
  const _GiteePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    final paint = Paint()..isAntiAlias = true;

    // Red circle background
    paint.color = const Color(0xFFC71D23);
    canvas.drawCircle(Offset(12 * s, 12 * s), 12 * s, paint);

    // White Gitee G-mark:
    // Outer filled rect covers the whole mark area, then inner rect is punched
    // out, leaving a bracket shape. The inner arm is added back as a crossbar.
    paint.color = Colors.white;

    // Outer bracket block (top bar + left column + bottom bar)
    final outer = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(4.76 * s, 5.33 * s, 13.32 * s, 13.59 * s),
        Radius.circular(0.6 * s),
      ));

    // Hollow interior (punched out to create the G opening)
    final hollow = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(7.0 * s, 7.6 * s, 11.0 * s, 9.3 * s),
        Radius.circular(0.4 * s),
      ));

    // Crossbar (inner arm of the G)
    final arm = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(12.0 * s, 11.0 * s, 6.0 * s, 2.3 * s),
        Radius.circular(0.4 * s),
      ));

    // bracket = outer − hollow, then ∪ arm
    final bracket = Path.combine(PathOperation.difference, outer, hollow);
    final mark = Path.combine(PathOperation.union, bracket, arm);

    canvas.drawPath(mark, paint);
  }

  @override
  bool shouldRepaint(_GiteePainter old) => old.color != color;
}
