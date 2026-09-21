import 'package:firebase_core/firebase_core.dart';

class FirebaseBootstrap {
  static bool configured = false;

  static Future<void> initialize() async {
    if (configured) return;
    if (Firebase.apps.isNotEmpty) {
      configured = true;
      return;
    }

    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const appId = String.fromEnvironment('FIREBASE_APP_ID');
    const messagingSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
    const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
    const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
    if ([apiKey, appId, messagingSenderId, projectId].any((v) => v.isEmpty)) return;

    final options = FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      authDomain: authDomain.isEmpty ? null : authDomain,
      storageBucket: const String.fromEnvironment('FIREBASE_STORAGE_BUCKET').isEmpty
          ? null
          : const String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
    );
    try {
      await Firebase.initializeApp(options: options);
      configured = true;
    } catch (_) {
      configured = false;
    }
  }
}
