import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/cache_service.dart';
import '../services/notification_service.dart';
import '../core/api_config.dart';
import '../core/firebase_bootstrap.dart';
import '../services/auth_service.dart';
import '../services/cloud_sync_service.dart';

class BootstrapReport {
  const BootstrapReport({required this.statuses});

  final Map<String, bool> statuses;

  bool get allOptionalServicesOk => statuses.values.every((value) => value);

  String get summary => statuses.entries
      .map((entry) => entry.key + '=' + (entry.value ? 'OK' : 'FAILED'))
      .join(', ');
}

class AppBootstrap {
  AppBootstrap._();

  static final ValueNotifier<BootstrapReport> report =
      ValueNotifier<BootstrapReport>(
    const BootstrapReport(statuses: <String, bool>{}),
  );

  static Future<BootstrapReport> initAll() async {
    final statuses = <String, bool>{};

    await _run('Firebase', statuses, () async {
      await FirebaseBootstrap.initialize().timeout(const Duration(seconds: 5));
      if (!_firebaseConfigurationPresent) return;
      if (!FirebaseBootstrap.configured) {
        throw StateError('Firebase configuration is present but initialization failed.');
      }
    });

    await _run('API config', statuses, () async {
      await ApiConfig.init().timeout(const Duration(seconds: 3));
    });

    await _run('Cache', statuses, () async {
      await CacheService.init().timeout(const Duration(seconds: 5));
    });

    await _run('Notifications', statuses, () async {
      await NotificationService.init().timeout(const Duration(seconds: 5));
    });

    if (FirebaseBootstrap.configured) {
      await _run('Auth', statuses, () async {
        await AuthService.instance.initialize().timeout(const Duration(seconds: 5));
      });

      await _run('Cloud sync', statuses, () async {
        CloudSyncService.instance.start();
      });
    } else {
      statuses['Auth'] = false;
      statuses['Cloud sync'] = false;
      debugPrint('ℹ️ Auth/Cloud sync skipped: Firebase is not configured.');
    }

    final result = BootstrapReport(
      statuses: Map<String, bool>.unmodifiable(statuses),
    );
    report.value = result;
    debugPrint('BOOTSTRAP REPORT: ' + result.summary);
    return result;
  }

  static Future<void> _run(
    String name,
    Map<String, bool> statuses,
    Future<void> Function() action,
  ) async {
    try {
      await action();
      statuses[name] = true;
      debugPrint('✅ ' + name + ' OK');
    } catch (error, stackTrace) {
      statuses[name] = false;
      debugPrint('❌ ' + name + ' FAILED: ' + error.toString());
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static bool get _firebaseConfigurationPresent => const [
        String.fromEnvironment('FIREBASE_API_KEY'),
        String.fromEnvironment('FIREBASE_APP_ID'),
        String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
        String.fromEnvironment('FIREBASE_PROJECT_ID'),
      ].every((value) => value.isNotEmpty);
}