import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthClient? authClient})
      : _authClient = authClient ?? AuthService.instance {
    // Production subscribes only after Firebase has initialized.
    // Tests may inject a fake client without Firebase.
    if (authClient != null || AuthService.isReady) {
      _start();
    }
  }

  final AuthClient _authClient;
  StreamSubscription<User?>? _subscription;

  User? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get firebaseReady => AuthService.isReady;

  void _start() {
    _currentUser = _authClient.currentUser;
    _subscription = _authClient.authStateChanges.listen(
      _onAuthStateChanged,
      onError: _onAuthError,
    );
  }

  void _onAuthStateChanged(User? user) {
    _currentUser = user;
    _errorMessage = null;
    notifyListeners();
  }

  void _onAuthError(Object error, StackTrace stackTrace) {
    _errorMessage = _messageFor(error);
    notifyListeners();
  }

  Future<void> signInWithGoogle() async {
    if (_isLoading) return;

    _setLoading(true);
    _errorMessage = null;
    notifyListeners();

    try {
      final credential = await _authClient.signInWithGoogle();
      final user = credential?.user;
      if (user != null) {
        _currentUser = user;
      }
    } catch (error) {
      _errorMessage = _messageFor(error);
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    if (_isLoading) return;

    _setLoading(true);
    _errorMessage = null;
    notifyListeners();

    try {
      await _authClient.signOut();
      _currentUser = null;
    } catch (error) {
      _errorMessage = _messageFor(error);
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
  }

  String _messageFor(Object error) {
    if (error is AuthException) return error.message;
    return 'حدث خطأ في المصادقة. حاول مرة أخرى.';
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
