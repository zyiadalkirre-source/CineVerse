import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Centralized, idempotent Firebase initialization.
class FirebaseBootstrap {
  FirebaseBootstrap._();

  static bool configured = false;
  static String? error;
  static Future<void>? _initialization;

  static Future<void> initialize() {
    if (configured) return Future<void>.value();

    final inFlight = _initialization;
    if (inFlight != null) return inFlight;

    final future = _doInitialize();
    _initialization = future;
    return future.whenComplete(() => _initialization = null);
  }

  static Future<void> _doInitialize() async {
    if (configured) return;

    if (Firebase.apps.isNotEmpty) {
      configured = true;
      error = null;
      debugPrint('✅ Firebase already initialized');
      return;
    }

    final apiKey = const String.fromEnvironment('FIREBASE_API_KEY');
    final appId = const String.fromEnvironment('FIREBASE_APP_ID');
    final messagingSenderId =
        const String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
    final projectId = const String.fromEnvironment('FIREBASE_PROJECT_ID');
    final authDomain = const String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
    final storageBucket =
        const String.fromEnvironment('FIREBASE_STORAGE_BUCKET');

    final hasDartOptions = <String>[
      apiKey,
      appId,
      messagingSenderId,
      projectId,
    ].every((value) => value.isNotEmpty);

    try {
      if (hasDartOptions) {
        await Firebase.initializeApp(
          options: FirebaseOptions(
            apiKey: apiKey,
            appId: appId,
            messagingSenderId: messagingSenderId,
            projectId: projectId,
            authDomain: authDomain.isEmpty ? null : authDomain,
            storageBucket: storageBucket.isEmpty ? null : storageBucket,
          ),
        );
        debugPrint('✅ Firebase initialized from explicit build options');
      } else {
        // Android/iOS native configuration remains a valid fallback.
        // On Android it is supplied by google-services.json at build time.
        await Firebase.initializeApp();
        debugPrint('✅ Firebase initialized from native configuration');
      }

      configured = Firebase.apps.isNotEmpty;
      error = configured ? null : 'Firebase.initializeApp() returned no app.';
    } catch (e, st) {
      configured = false;
      error = e.toString();
      debugPrint('❌ Firebase initialization failed: $e');
      debugPrintStack(stackTrace: st);
    }
  }
}
