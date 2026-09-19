import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/cloud_sync_service.dart';
import 'package:provider/provider.dart';
import '../providers/media_provider.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool loading = false;
  String? error;

  Future<void> _google() async {
    setState(() { loading = true; error = null; });
    try {
      await AuthService.instance.signInWithGoogle();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('حساب CineVerse')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: user == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.account_circle, size: 86),
                      const SizedBox(height: 20),
                      const Text('احفظ مكتبتك وملاحظاتك بأمان',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 10),
                      const Text('سجّل الدخول بحساب Google لمزامنة مكتبتك بين أجهزتك.'),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: loading ? null : _google,
                        icon: const Icon(Icons.login),
                        label: Text(loading ? 'جاري تسجيل الدخول...' : 'المتابعة باستخدام Google'),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 16),
                        Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error),
                            textAlign: TextAlign.center),
                      ],
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(radius: 36, backgroundImage: user.photoURL == null ? null : NetworkImage(user.photoURL!)),
                      const SizedBox(height: 12),
                      Text(user.displayName ?? 'حساب Google', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text(user.email ?? ''),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: loading ? null : () async {
                          setState(() => loading = true);
                          try { await CloudSyncService.instance.syncLibrary(context.read<MediaProvider>().library); } finally { if (mounted) setState(() => loading = false); }
                        },
                        icon: const Icon(Icons.cloud_sync),
                        label: const Text('مزامنة المكتبة الآن'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: loading ? null : () async { await AuthService.instance.signOut(); if (mounted) setState(() {}); },
                        icon: const Icon(Icons.logout),
                        label: const Text('تسجيل الخروج'),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
