import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cineverse/providers/auth_provider.dart';
import 'package:cineverse/services/auth_service.dart';

class FakeAuthClient implements AuthClient {
  FakeAuthClient({
    this.signInError,
    this.signOutError,
    this.signInGate,
  });

  final Object? signInError;
  final Object? signOutError;
  final Completer<void>? signInGate;
  final StreamController<User?> controller =
      StreamController<User?>.broadcast();

  int signInCalls = 0;
  int signOutCalls = 0;

  @override
  Stream<User?> get authStateChanges => controller.stream;

  @override
  User? get currentUser => null;

  @override
  Future<UserCredential?> signInWithGoogle() async {
    signInCalls++;
    if (signInGate != null) {
      await signInGate!.future;
    }
    if (signInError != null) throw signInError!;
    return null;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (signOutError != null) throw signOutError!;
  }

  Future<void> dispose() => controller.close();
}

void main() {
  test('starts unauthenticated and subscribes to auth state changes', () async {
    final client = FakeAuthClient();
    final provider = AuthProvider(authClient: client);

    expect(provider.currentUser, isNull);
    expect(provider.isAuthenticated, isFalse);
    expect(provider.isLoading, isFalse);
    expect(provider.errorMessage, isNull);

    client.controller.add(null);
    await Future<void>.delayed(Duration.zero);

    expect(provider.isAuthenticated, isFalse);

    provider.dispose();
    await client.dispose();
  });

  test('signInWithGoogle exposes loading state and calls the auth client',
      () async {
    final gate = Completer<void>();
    final client = FakeAuthClient(signInGate: gate);
    final provider = AuthProvider(authClient: client);

    final signInFuture = provider.signInWithGoogle();
    await Future<void>.delayed(Duration.zero);

    expect(client.signInCalls, 1);
    expect(provider.isLoading, isTrue);
    expect(provider.errorMessage, isNull);

    gate.complete();
    await signInFuture;

    expect(provider.isLoading, isFalse);
    expect(provider.errorMessage, isNull);

    provider.dispose();
    await client.dispose();
  });

  test('signInWithGoogle exposes AuthException message', () async {
    final client = FakeAuthClient(
      signInError: AuthException('فشل تسجيل الدخول.', 'test-error'),
    );
    final provider = AuthProvider(authClient: client);

    await provider.signInWithGoogle();

    expect(provider.isLoading, isFalse);
    expect(provider.errorMessage, 'فشل تسجيل الدخول.');

    provider.dispose();
    await client.dispose();
  });

  test('signOut clears the local user state and reports errors', () async {
    final client = FakeAuthClient(
      signOutError: AuthException('تعذر تسجيل الخروج.', 'test-error'),
    );
    final provider = AuthProvider(authClient: client);

    await provider.signOut();

    expect(client.signOutCalls, 1);
    expect(provider.isLoading, isFalse);
    expect(provider.currentUser, isNull);
    expect(provider.errorMessage, 'تعذر تسجيل الخروج.');

    provider.dispose();
    await client.dispose();
  });
}
