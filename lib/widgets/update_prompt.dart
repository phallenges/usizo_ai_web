import 'package:flutter/material.dart';

import '../l10n/localized.dart';
import '../models/app_update.dart';
import '../services/app_updater.dart';

/// Shows the update prompt and drives the download when the person accepts.
Future<void> showUpdatePrompt({
  required BuildContext context,
  required AppUpdater updater,
  required AppUpdate update,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: !update.updateRequired,
    builder: (context) => UpdatePromptDialog(updater: updater, update: update),
  );
}

/// Asks the person to install a newer APK, then downloads it on request.
class UpdatePromptDialog extends StatefulWidget {
  const UpdatePromptDialog({
    required this.updater,
    required this.update,
    super.key,
  });

  final AppUpdater updater;
  final AppUpdate update;

  @override
  State<UpdatePromptDialog> createState() => _UpdatePromptDialogState();
}

class _UpdatePromptDialogState extends State<UpdatePromptDialog> {
  var _progress = 0.0;
  var _busy = false;
  String? _message;

  Future<void> _startUpdate() async {
    setState(() {
      _busy = true;
      _message = null;
      _progress = 0;
    });
    final result = await widget.updater.downloadAndInstall(
      widget.update,
      onProgress: (value) {
        if (mounted) setState(() => _progress = value);
      },
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = switch (result) {
        UpdateInstallResult.installerOpened =>
          context.tr('update.installPrompt'),
        UpdateInstallResult.permissionRequired =>
          context.tr('update.permissionNeeded'),
        UpdateInstallResult.downloadFailed =>
          context.tr('update.downloadFailed'),
        UpdateInstallResult.invalidUrl => context.tr('update.unavailable'),
        UpdateInstallResult.installFailed => context.tr('update.installFailed'),
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final update = widget.update;
    final notes = update.notes.trim();
    final size = update.sizeLabel;
    return AlertDialog(
      title: Text(context.tr('update.title')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${context.tr('update.latestVersion')} ${update.latestVersion}'
              '${size.isEmpty ? '' : ' · $size'}',
            ),
            if (update.updateRequired) ...[
              const SizedBox(height: 8),
              Text(context.tr('update.required')),
            ],
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                context.tr('update.whatsNew'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(notes, maxLines: 6, overflow: TextOverflow.ellipsis),
            ],
            if (_busy) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progress <= 0 ? null : _progress),
              const SizedBox(height: 8),
              Text(
                '${context.tr('update.downloading')} '
                '${(_progress * 100).round()}%',
              ),
            ],
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(_message!),
            ],
          ],
        ),
      ),
      actions: [
        if (!_busy && !update.updateRequired)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('update.later')),
          ),
        if (!_busy)
          FilledButton(
            onPressed: _startUpdate,
            child: Text(context.tr('update.updateNow')),
          ),
      ],
    );
  }
}
