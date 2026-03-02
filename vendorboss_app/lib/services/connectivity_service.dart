import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

/// Watches network connectivity and exposes [isOnline] as a ValueNotifier.
/// Wrap the app in [ConnectivityBanner] to show the indicator automatically.
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final ValueNotifier<bool> isOnline = ValueNotifier(true);
  StreamSubscription? _subscription;

  /// Call once from main() before runApp.
  Future<void> init() async {
    final result = await Connectivity().checkConnectivity();
    isOnline.value = _isConnected(result);

    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      isOnline.value = _isConnected(results);
    });
  }

  bool _isConnected(List<ConnectivityResult> results) {
    return results.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet);
  }

  void dispose() {
    _subscription?.cancel();
    isOnline.dispose();
  }
}
