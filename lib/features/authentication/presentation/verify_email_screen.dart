import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/config/session_providers.dart';
import '../../../app/theme/tokens.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  Timer? _poll;
  bool _resent = false;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) async {
      final verified = await ref.read(authRepositoryProvider).reloadAndCheckVerified();
      if (verified && mounted) {
        // Force the router to re-evaluate by refreshing auth-dependent state.
        ref.invalidate(authStateProvider);
        if (mounted) context.go('/home');
      }
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final email = ref.watch(authStateProvider).valueOrNull?.email ?? 'your email';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(FgTokens.s8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mark_email_unread_outlined, size: 64, color: theme.colorScheme.primary),
                const SizedBox(height: FgTokens.s5),
                Text('Verify your email', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: FgTokens.s3),
                Text(
                  'We sent a verification link to $email.\nThis screen refreshes automatically once you verify.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: FgTokens.s6),
                OutlinedButton(
                  onPressed: _resent
                      ? null
                      : () async {
                          await ref.read(authRepositoryProvider).resendVerification();
                          if (mounted) setState(() => _resent = true);
                        },
                  child: Text(_resent ? 'Email sent again' : 'Resend email'),
                ),
                TextButton(
                  onPressed: () async {
                    await ref.read(authRepositoryProvider).signOut();
                    if (context.mounted) context.go('/signin');
                  },
                  child: const Text('Use a different account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
