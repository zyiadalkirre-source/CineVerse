import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/firebase_bootstrap.dart';

abstract interface class AuthClient {
  Stream<User?> get authStateChanges;
  User? get currentUser;
  Future<UserCredential?> signInWithGoogle();
  Future<void> signOut();
}

class AuthException implements Exception {
  AuthException(this.message, [this.code]);

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class AuthService implements AuthClient {
  AuthService._();

  static final instance = AuthService._();

  FirebaseAuth get _auth => FirebaseAuth.instance;
  GoogleSignIn get _google => GoogleSignIn.instance;

  bool _initialized = false;
  Future<void>? _initialization;

  static bool get isReady => FirebaseBootstrap.configured;

  @override
  Stream<User?> get authStateChanges {
    _requireFirebase();
    return _auth.authStateChanges();
  }

  @override
  User? get currentUser {
    if (!isReady) return null;
    return _auth.currentUser;
  }

  Future<void> initialize() {
    if (!isReady || _initialized) return Future<void>.value();

    final inFlight = _initialization;
    if (inFlight != null) return inFlight;

    final future = _doInitialize();
    _initialization = future;
    return future.whenComplete(() => _initialization = null);
  }

  Future<void> _doInitialize() async {
    if (!isReady || _initialized) return;

    if (!kIsWeb) {
      await _google.initialize();
    }

    _initialized = true;
    debugPrint('✅ AuthService initialized');
  }

  @override
  Future<UserCredential?> signInWithGoogle() async {
    _requireFirebase();
    await initialize();

    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider()
          ..addScope('email')
          ..addScope('profile');
        return await _auth.signInWithPopup(provider);
      }

      if (!_google.supportsAuthenticate()) {
        throw const AuthException(
          'تسجيل الدخول باستخدام Google غير مدعوم على هذه المنصة.',
          'google-auth-unsupported',
        );
      }

      final googleUser = await _google.authenticate(
        scopeHint: const ['email', 'profile'],
      );
      final idToken = googleUser.authentication.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw const AuthException(
          'لم يتم استلام رمز Google. تحقق من إعداد OAuth وFirebase.',
          'missing-google-id-token',
        );
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_firebaseMessage(e.code), e.code);
    } on GoogleSignInException catch (e) {
      throw AuthException(_googleMessage(e.code), e.code.toString());
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(
        'تعذر تسجيل الدخول باستخدام Google: $e',
        'google-sign-in-failed',
      );
    }
  }

  String _firebaseMessage(String code) {
    switch (code) {
      case 'account-exists-with-different-credential':
        return 'هذا البريد مرتبط بطريقة تسجيل دخول مختلفة في Firebase.';
      case 'invalid-credential':
        return 'بيانات تسجيل الدخول من Google غير صالحة أو انتهت صلاحيتها.';
      case 'network-request-failed':
        return 'تعذر الاتصال بالإنترنت. تحقق من الاتصال وحاول مرة أخرى.';
      case 'operation-not-allowed':
        return 'تسجيل الدخول باستخدام Google غير مفعّل في Firebase Authentication.';
      case 'invalid-api-key':
      case 'app-not-authorized':
        return 'إعداد Firebase لهذا التطبيق غير صحيح.';
      default:
        return 'تعذر تسجيل الدخول باستخدام Google. رمز الخطأ: $code';
    }
  }

  String _googleMessage(GoogleSignInExceptionCode code) {
    switch (code) {
      case GoogleSignInExceptionCode.canceled:
        return 'تم إلغاء تسجيل الدخول.';
      case GoogleSignInExceptionCode.clientConfigurationError:
        return 'إعداد Google Sign-In غير مكتمل. تحقق من package name وSHA وgoogle-services.json وOAuth.';
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'إعداد مزود Google غير صحيح في المشروع.';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'تعذر فتح نافذة تسجيل الدخول. أعد المحاولة من داخل التطبيق.';
      case GoogleSignInExceptionCode.interrupted:
        return 'تمت مقاطعة تسجيل الدخول. أعد المحاولة.';
      default:
        return 'تعذر تسجيل الدخول باستخدام Google. رمز الخطأ: $code';
    }
  }

  void _requireFirebase() {
    if (!isReady) {
      final details = FirebaseBootstrap.error;
      throw AuthException(
        details == null || details.isEmpty
            ? 'Firebase غير مهيأ في هذه النسخة من التطبيق.'
            : 'Firebase غير مهيأ: $details',
        'firebase-not-ready',
      );
    }
  }

  @override
  Future<void> signOut() async {
    _requireFirebase();

    if (!kIsWeb) {
      try {
        await _google.signOut();
      } catch (_) {}
    }

    await _auth.signOut();
  }
}
