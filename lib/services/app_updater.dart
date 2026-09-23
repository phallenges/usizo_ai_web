import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../models/app_update.dart';
import 'backend_api.dart';

/// Outcome of an attempted in-app update.
enum UpdateInstallResult {
  installerOpened,
  permissionRequired,
  downloadFailed,
  invalidUrl,
  installFailed,
}

/// Checks the published Android release and installs it from inside the app.
///
/// Android always asks the person to confirm an install, so this replaces the
/// "find the website and download the APK again" steps with a single tap. It
/// cannot install silently, and it only works on Android.
class AppUpdater {
  AppUpdater({BackendApi? backendApi, http.Client? client})
      : _backendApi = backendApi ?? BackendApi(),
        _client = client ?? http.Client();

  static const _channel = MethodChannel('usizoai/updater');
  static const _assetName = 'UsizoAI.apk';
  static const _downloadTimeout = Duration(minutes: 15);

  final BackendApi _backendApi;
  final http.Client _client;

  /// Version name of the installed build, for example `1.1.0`.
  ///
  /// Returns an empty string on any platform without the native bridge.
  Future<String> installedVersion() async {
    try {
      final info = await _channel
          .invokeMapMethod<String, Object?>('getInstalledVersion');
      return info?['versionName']?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Never throws: offline, unconfigured and older backends all return null.
  Future<AppUpdate?> check() async {
    final version = await installedVersion();
    if (version.isEmpty) return null;
    final payload = await _backendApi.fetchAppVersion(currentVersion: version);
    if (payload == null) return null;
    return AppUpdate.fromJson(payload);
  }

  Future<bool> canInstallPackages() async {
    try {
      return await _channel.invokeMethod<bool>('canInstallPackages') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> openInstallPermissionSettings() async {
    try {
      return await _channel
              .invokeMethod<bool>('openInstallPermissionSettings') ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Downloads the APK into the app cache and hands it to the installer.
  Future<UpdateInstallResult> downloadAndInstall(
    AppUpdate update, {
    void Function(double progress)? onProgress,
  }) async {
    final uri = Uri.tryParse(update.downloadUrl);
    if (uri == null || uri.scheme != 'https') {
      return UpdateInstallResult.invalidUrl;
    }
    final File file;
    try {
      file = await _download(uri, onProgress: onProgress);
    } catch (_) {
      return UpdateInstallResult.downloadFailed;
    }
    if (!await canInstallPackages()) {
      await openInstallPermissionSettings();
      return UpdateInstallResult.permissionRequired;
    }
    final started = await _channel.invokeMethod<bool>(
          'installApk',
          {'path': file.path},
        ) ??
        false;
    return started
        ? UpdateInstallResult.installerOpened
        : UpdateInstallResult.installFailed;
  }

  Future<File> _download(
    Uri uri, {
    void Function(double progress)? onProgress,
  }) async {
    final response =
        await _client.send(http.Request('GET', uri)).timeout(_downloadTimeout);
    if (response.statusCode != 200) {
      throw HttpException('Download failed with ${response.statusCode}.');
    }
    final total = response.contentLength ?? 0;
    final directory = Directory('${await _cacheDirectory()}/updates');
    await directory.create(recursive: true);
    final file = File('${directory.path}/$_assetName');
    final sink = file.openWrite();
    var received = 0;
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call(received / total);
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
    return file;
  }

  Future<String> _cacheDirectory() async {
    try {
      return await _channel.invokeMethod<String>('cacheDir') ??
          Directory.systemTemp.path;
    } catch (_) {
      return Directory.systemTemp.path;
    }
  }
}
