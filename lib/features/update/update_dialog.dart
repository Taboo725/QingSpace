import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/config/app_info.dart';
import '../../core/services/update_service.dart';

/// Presents a newer release and, on Android, downloads and installs it.
///
/// Returns true when the installer was launched, so the caller can stop
/// nagging for this session.
Future<bool?> showUpdateDialog(
  BuildContext context, {
  required ReleaseInfo release,
  UpdateService? service,
  bool allowSkip = true,
}) => showDialog<bool>(
  context: context,
  builder: (_) => _UpdateDialog(
    release: release,
    service: service ?? UpdateService(),
    allowSkip: allowSkip,
  ),
);

class _UpdateDialog extends StatefulWidget {
  final ReleaseInfo release;
  final UpdateService service;
  final bool allowSkip;

  const _UpdateDialog({
    required this.release,
    required this.service,
    required this.allowSkip,
  });

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  /// -1 means downloading with an unknown total.
  double? _progress;
  String? _error;
  CancellationToken? _cancel;

  bool get _isDownloading => _progress != null;

  @override
  void dispose() {
    _cancel?.cancel();
    super.dispose();
  }

  Future<void> _install() async {
    final cancel = CancellationToken();
    setState(() {
      _cancel = cancel;
      _progress = -1;
      _error = null;
    });

    try {
      await widget.service.downloadAndInstall(
        widget.release,
        cancel: cancel,
        onProgress: (value) {
          if (mounted && !cancel.isCancelled) setState(() => _progress = value);
        },
      );
      if (mounted && !cancel.isCancelled) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _progress = null;
        _error = e is StateError ? e.message : '$e';
      });
    }
  }

  Future<void> _openPage() async {
    final ok = await widget.service.openReleasePage(widget.release);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, false);
    } else {
      setState(() => _error = '无法打开浏览器，请手动访问 ${AppInfo.releasesUrl}');
    }
  }

  void _skip() {
    widget.service.skipVersion(widget.release.version);
    Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final release = widget.release;
    final canInstall = release.canInstallInApp;

    return AlertDialog(
      icon: Icon(Icons.system_update_rounded, color: theme.primaryColor),
      title: Text('发现新版本 ${release.version}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _subtitleFor(release, canInstall),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Flexible(child: _buildNotes(release.notes)),
            if (!canInstall && !Platform.isAndroid) ...[
              const SizedBox(height: 16),
              Text(
                '桌面版请在 Release 页面下载安装包，覆盖安装即可保留本地设置。',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
            if (_isDownloading) ...[
              const SizedBox(height: 20),
              _buildProgress(theme),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(fontSize: 12, color: theme.colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: _isDownloading
          ? [
              TextButton(
                onPressed: () {
                  _cancel?.cancel();
                  Navigator.pop(context, false);
                },
                child: const Text('取消'),
              ),
            ]
          : [
              if (widget.allowSkip)
                TextButton(
                  onPressed: _skip,
                  child: Text(
                    '跳过此版本',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('稍后'),
              ),
              if (canInstall)
                FilledButton(onPressed: _install, child: const Text('立即更新'))
              else
                FilledButton(onPressed: _openPage, child: const Text('前往下载')),
            ],
    );
  }

  Widget _buildNotes(String notes) {
    if (notes.isEmpty) {
      return Text(
        '本次更新没有提供说明。',
        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
      );
    }
    // Release notes are Markdown, but rendering them would pull the article
    // renderer into a dialog for what is nearly always a plain bullet list.
    return SingleChildScrollView(
      child: Text(notes, style: const TextStyle(fontSize: 13, height: 1.6)),
    );
  }

  Widget _buildProgress(ThemeData theme) {
    final progress = _progress ?? 0;
    final determinate = progress >= 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: determinate ? progress : null,
            minHeight: 6,
            backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          determinate
              ? '正在下载 ${(progress * 100).toStringAsFixed(0)}%'
              : '正在下载…',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }
}

/// "current version · download size", with the size only when it is both known
/// and about to be used.
String _subtitleFor(ReleaseInfo release, bool canInstall) {
  final size = release.apk?.size ?? 0;
  final suffix = (canInstall && size > 0) ? '  ·  ${_formatBytes(size)}' : '';
  return '当前版本 ${AppInfo.version}$suffix';
}

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '$bytes B';
}
