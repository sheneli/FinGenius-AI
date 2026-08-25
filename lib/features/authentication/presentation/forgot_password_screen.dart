import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/config/session_providers.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/utils/validators.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final result = await ref.read(authRepositoryProvider).sendPasswordReset(_email.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _sent = result.isOk;
    });
    result.when(
      ok: (_) {},
      err: (f) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(f.message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(FgTokens.s6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _sent
                  ? Column(children: [
                      Icon(Icons.mark_email_read_outlined, size: 64, color: theme.colorScheme.primary),
                      const SizedBox(height: FgTokens.s4),
                      Text('Check your inbox', style: theme.textTheme.titleLarge),
                      const SizedBox(height: FgTokens.s2),
                      Text(
                        'If an account exists for that email, a reset link is on its way.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: FgTokens.s6),
                      FilledButton(onPressed: () => context.go('/signin'), child: const Text('Back to sign in')),
                    ])
                  : Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text("Enter your account email and we'll send a reset link.",
                              style: theme.textTheme.bodyMedium),
                          const SizedBox(height: FgTokens.s5),
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                            validator: Validators.email,
                            onFieldSubmitted: (_) => _submit(),
                          ),
                          const SizedBox(height: FgTokens.s5),
                          FilledButton(
                            onPressed: _busy ? null : _submit,
                            child: _busy
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text('Send reset link'),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
