import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _google = GoogleSignIn.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<void> initialize() async {
    if (!kIsWeb) await _google.initialize();
  }

  Future<UserCredential?> signInWithGoogle() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      provider.addScope('email');
      provider.addScope('profile');
      return _auth.signInWithPopup(provider);
    }
    final googleUser = await _google.authenticate();
    final idToken = (await googleUser.authentication).idToken;
    if (idToken == null) throw StateError('Google لم يعطِ رمز تسجيل الدخول.');
    return _auth.signInWithCredential(GoogleAuthProvider.credential(idToken: idToken));
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      try { await _google.signOut(); } catch (_) {}
    }
    await _auth.signOut();
  }
}
