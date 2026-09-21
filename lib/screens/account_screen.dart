import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/cloud_sync_service.dart';
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
    final auth = context.read<AuthProvider>();

    setState(() {
      loading = true;
      error = null;
    });

    await auth.signInWithGoogle();

    if (mounted) {
      setState(() {
        error = auth.errorMessage;
        loading = false;
      });
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
    final auth = context.read<AuthProvider>();

    setState(() => loading = true);
    await auth.signOut();

    if (mounted) {
      setState(() {
        loading = false;
        error = auth.errorMessage;
      });
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
    final auth = context.watch<AuthProvider>();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Builder(
        builder: (context) {
          final user = auth.currentUser;

          if (!auth.firebaseReady) {
            return Scaffold(
              appBar: AppBar(title: const Text('حساب CineVerse')),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'تسجيل الدخول والمزامنة غير متاحين حالياً. يمكنك استخدام التطبيق محلياً.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }

          return Scaffold(
            appBar: AppBar(title: const Text('حساب CineVerse')),
            body: user == null
                ? _signInBody(auth)
                : _accountBody(user, provider),
          );
        },
      ),
    );
  }

  Widget _signInBody(AuthProvider auth) {
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
                onPressed: loading || auth.isLoading ? null : _google,
                icon: const Icon(Icons.login),
                label: Text(
                  loading || auth.isLoading ? 'جاري تسجيل الدخول...' : 'المتابعة باستخدام Google',
                ),
              ),
              if (error != null || auth.errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  error ?? auth.errorMessage!,
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
