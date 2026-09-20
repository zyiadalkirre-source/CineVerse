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
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        provider.addScope('email');
        provider.addScope('profile');
        return await _auth.signInWithPopup(provider);
      }

      final googleUser = await _google.authenticate(
        scopeHint: const ['email', 'profile'],
      );
      final idToken = (await googleUser.authentication).idToken;
      if (idToken == null || idToken.isEmpty) {
        throw StateError('لم يتم استلام رمز Google. تحقق من إعداد OAuth وgoogle-services.json.');
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_firebaseMessage(e.code), e.code);
    } on GoogleSignInException catch (e) {
      throw AuthException(_googleMessage(e.code), e.code.toString());
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
      default:
        return 'تعذر تسجيل الدخول باستخدام Google. رمز الخطأ: $code';
    }
  }

  String _googleMessage(GoogleSignInExceptionCode code) {
    switch (code) {
      case GoogleSignInExceptionCode.canceled:
        return 'تم إلغاء تسجيل الدخول.';
      case GoogleSignInExceptionCode.clientConfigurationError:
        return 'إعداد Google Sign-In غير مكتمل. تحقق من google-services.json وOAuth.';
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

  Future<void> signOut() async {
    if (!kIsWeb) {
      try { await _google.signOut(); } catch (_) {}
    }
    await _auth.signOut();
  }
}
