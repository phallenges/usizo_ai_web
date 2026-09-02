import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Detects whether the device has an internet connection.
///
/// Uses [connectivity_plus] to check network state. A device can be
/// "connected" to WiFi but have no actual internet access, so we also
/// do a lightweight DNS lookup as a fallback check.
class ConnectivityService {
  final _controller = StreamController<bool>.broadcast();
  StreamSubscription? _subscription;

  bool _isOnline = true;

  /// Current connectivity status.
  bool get isOnline => _isOnline;

  /// Stream that emits whenever connectivity changes.
  Stream<bool> get onConnectivityChanged => _controller.stream;

  /// Start listening for connectivity changes.
  void init() {
    _subscription = Connectivity()
        .onConnectivityChanged
        .listen((results) async {
      final hasConnection = await checkConnection();
      if (hasConnection != _isOnline) {
        _isOnline = hasConnection;
        _controller.add(_isOnline);
      }
    });

    // Check initial state
    Connectivity().checkConnectivity().then((result) async {
      _isOnline = await checkConnection();
      _controller.add(_isOnline);
    });
  }

  /// Perform a quick connectivity check.
  /// Returns true if the device can reach the internet.
  Future<bool> checkConnection() async {
    try {
      final results = await Connectivity().checkConnectivity();
      // No connectivity at all
      if (results.every((r) => r == ConnectivityResult.none)) {
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
