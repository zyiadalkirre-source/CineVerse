import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/cloud_sync_service.dart';
import '../core/firebase_bootstrap.dart';
import '../providers/media_provider.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool loading = false;
  String? error;
  DateTime? lastSync;

  Future<void> _google() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      await AuthService.instance.signInWithGoogle();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _sync() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final provider = context.read<MediaProvider>();
      await CloudSyncService.instance.syncLibrary(provider.library);
      final remote = await CloudSyncService.instance.downloadLibrary();
      await provider.mergeCloudLibrary(remote);

      if (mounted) {
        setState(() => lastSync = DateTime.now());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تمت مزامنة مكتبتك بنجاح.')),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'تعذر إكمال المزامنة. تحقق من الاتصال وحاول مرة أخرى.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => loading = true);
    try {
      await AuthService.instance.signOut();
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
          error = null;
        });
      }
    }
  }

  Widget _statCard(String title, String value, IconData icon) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          child: Column(
            children: [
              Icon(icon, size: 24),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MediaProvider>();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: StreamBuilder<User?>(
        stream: AuthService.instance.authStateChanges,
        builder: (context, snapshot) {
          final user = snapshot.data ?? FirebaseAuth.instance.currentUser;

          if (!FirebaseBootstrap.configured) {
            return Scaffold(
              appBar: AppBar(title: const Text('حساب CineVerse')),
              body: const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'تم تجهيز Google Sign-In والمزامنة، لكن إعداد Firebase الخاص بالتطبيق غير متاح في هذه النسخة.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }

          return Scaffold(
            appBar: AppBar(title: const Text('حساب CineVerse')),
            body: user == null ? _signInBody() : _accountBody(user, provider),
          );
        },
      ),
    );
  }

  Widget _signInBody() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 48,
                child: Icon(Icons.person_outline_rounded, size: 50),
              ),
              const SizedBox(height: 18),
              const Text(
                'احفظ مكتبتك وملاحظاتك بأمان',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              const Text(
                'سجّل الدخول بحساب Google لربط مكتبتك ومزامنتها بين أجهزتك.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: loading ? null : _google,
                icon: const Icon(Icons.login),
                label: Text(
                  loading ? 'جاري تسجيل الدخول...' : 'المتابعة باستخدام Google',
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 16),
                Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _accountBody(User user, MediaProvider provider) {
    final library = provider.library;
    final favoriteCount = library.where((x) => x.isFavorite).length;
    final watchedCount = library.where((x) => x.watchStatus == 'watched').length;
    final watchingCount = library.where((x) => x.watchStatus == 'watching').length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 46,
                  backgroundImage: user.photoURL == null
                      ? null
                      : NetworkImage(user.photoURL!),
                  child: user.photoURL == null
                      ? const Icon(Icons.person, size: 45)
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  user.displayName ?? 'حساب Google',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(user.email ?? '', textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  'حساب Firebase مرتبط بنجاح',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _statCard('المكتبة', '${library.length}', Icons.video_library_outlined),
            _statCard('المفضلة', '$favoriteCount', Icons.favorite_outline),
          ],
        ),
        Row(
          children: [
            _statCard('تمت المشاهدة', '$watchedCount', Icons.done_all_rounded),
            _statCard('قيد المشاهدة', '$watchingCount', Icons.play_circle_outline),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: loading ? null : _sync,
          icon: const Icon(Icons.cloud_sync_rounded),
          label: Text(lastSync == null ? 'مزامنة المكتبة الآن' : 'مزامنة مرة أخرى'),
        ),
        if (lastSync != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'آخر مزامنة: ${lastSync!.hour.toString().padLeft(2, '0')}:${lastSync!.minute.toString().padLeft(2, '0')}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(
            error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: loading ? null : _signOut,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('تسجيل الخروج'),
        ),
      ],
    );
  }
}
