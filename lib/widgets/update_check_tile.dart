import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/localized.dart';
import '../services/app_updater.dart';
import 'update_prompt.dart';

/// Profile entry that shows the installed version and checks for a newer one.
class UpdateCheckTile extends StatefulWidget {
  const UpdateCheckTile({this.updater, super.key});

  final AppUpdater? updater;

  @override
  State<UpdateCheckTile> createState() => _UpdateCheckTileState();
}

class _UpdateCheckTileState extends State<UpdateCheckTile> {
  late final AppUpdater _updater = widget.updater ?? AppUpdater();
  var _version = '';
  var _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadVersion());
  }

  Future<void> _loadVersion() async {
    final version = await _updater.installedVersion();
    if (!mounted) return;
    setState(() => _version = version);
  }

  Future<void> _check() async {
    setState(() => _busy = true);
    final update = await _updater.check();
    if (!mounted) return;
    setState(() => _busy = false);
    final messenger = ScaffoldMessenger.of(context);
    if (update == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.tr('update.checkFailed'))),
      );
      return;
    }
    if (!update.updateAvailable) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.tr('update.upToDate'))),
      );
      return;
    }
    await showUpdatePrompt(context: context, updater: _updater, update: update);
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _version.isEmpty
        ? context.tr('update.checkForUpdates')
        : '${context.tr('update.installedVersion')} $_version';
    return Card(
      child: ListTile(
        leading: const Icon(Icons.system_update_alt_outlined),
        title: Text(context.tr('update.checkForUpdates')),
        subtitle: Text(subtitle),
        trailing: _busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_right),
        onTap: _busy ? null : _check,
      ),
    );
  }
}
