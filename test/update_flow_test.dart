import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:usizo_ai/l10n/localized.dart';
import 'package:usizo_ai/models/app_update.dart';
import 'package:usizo_ai/services/app_updater.dart';
import 'package:usizo_ai/services/backend_api.dart';
import 'package:usizo_ai/widgets/update_check_tile.dart';
import 'package:usizo_ai/widgets/update_prompt.dart';

const _channel = MethodChannel('usizoai/updater');

Widget _wrap(Widget child) => MaterialApp(
      home: Localized(
        languageCode: 'en',
        child: Scaffold(body: child),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      switch (call.method) {
        case 'getInstalledVersion':
          return <String, Object?>{'versionName': '1.1.0', 'versionCode': 2};
        case 'cacheDir':
          return Directory.systemTemp.path;
        case 'canInstallPackages':
          return true;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  test('the updater reports the published update for the installed build',
      () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/app/version');
      expect(request.url.queryParameters['currentVersion'], '1.1.0');
      return http.Response(
        jsonEncode(<String, Object?>{
          'ok': true,
          'latestVersion': '1.2.0',
          'latestTag': 'v1.2.0',
          'updateAvailable': true,
          'updateRequired': false,
          'notes': 'In-app updates',
          'sizeBytes': 129306624,
          'downloadUrl': 'https://example.test/UsizoAI.apk',
          'source': 'github',
        }),
        200,
      );
    });
    final updater = AppUpdater(
      backendApi: BackendApi(client: client),
      client: client,
    );

    final update = await updater.check();

    expect(update, isNotNull);
    expect(update!.latestVersion, '1.2.0');
    expect(update.updateAvailable, isTrue);
    expect(update.updateRequired, isFalse);
    expect(update.sizeLabel, '123.3 MB');
  });

  test('an unreachable backend never offers an update', () async {
    final client = MockClient((request) async => http.Response('nope', 503));
    final updater = AppUpdater(
      backendApi: BackendApi(client: client),
      client: client,
    );

    expect(await updater.check(), isNull);
  });

  test('an empty download URL is refused before downloading', () async {
    final updater = AppUpdater();
    const update = AppUpdate(
      latestVersion: '1.2.0',
      downloadUrl: 'http://insecure.example/UsizoAI.apk',
      updateAvailable: true,
    );

    expect(
      await updater.downloadAndInstall(update),
      UpdateInstallResult.invalidUrl,
    );
  });

  testWidgets('the prompt shows the version, size and notes', (tester) async {
    final update = AppUpdate(
      latestVersion: '1.2.0',
      downloadUrl: 'https://example.test/UsizoAI.apk',
      updateAvailable: true,
      notes: 'In-app updates',
      sizeBytes: 129306624,
    );

    await tester.pumpWidget(
      _wrap(UpdatePromptDialog(updater: AppUpdater(), update: update)),
    );

    expect(find.textContaining('1.2.0'), findsOneWidget);
    expect(find.textContaining('123.3 MB'), findsOneWidget);
    expect(find.textContaining('In-app updates'), findsOneWidget);
    expect(find.text('Update now'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
  });

  testWidgets('a required update cannot be postponed', (tester) async {
    final update = AppUpdate(
      latestVersion: '2.0.0',
      downloadUrl: 'https://example.test/UsizoAI.apk',
      updateAvailable: true,
      updateRequired: true,
    );

    await tester.pumpWidget(
      _wrap(UpdatePromptDialog(updater: AppUpdater(), update: update)),
    );

    expect(find.text('Later'), findsNothing);
    expect(find.text('Update now'), findsOneWidget);
  });

  testWidgets('the profile tile renders without the native bridge',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);

    await tester.pumpWidget(_wrap(const UpdateCheckTile()));
    await tester.pumpAndSettle();

    expect(find.text('Check for updates'), findsWidgets);
  });
}
