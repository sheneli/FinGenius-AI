import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/config/session_providers.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/gold_coin.dart';
import '../../transactions/domain/category.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept the terms and disclaimer to continue.')),
      );
      return;
    }
    setState(() => _busy = true);
    final result = await ref.read(authRepositoryProvider).signUp(
          email: _email.text,
          password: _password.text,
          displayName: _name.text,
        );
    if (!mounted) return;
    await result.when(
      ok: (user) async {
        // Create the profile doc + seed categories in one batch.
        final firestore = ref.read(firestoreProvider);
        final batch = firestore.batch();
        batch.set(firestore.doc('users/${user.uid}'), {
          'email': user.email,
          'displayName': _name.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'schemaVersion': 1,
          'prefs': {'theme': 'dark', 'currency': 'LKR', 'hideBalances': false},
          'consent': {'analytics': false, 'aiProcessing': false, 'notifications': false},
        });
        for (final c in Category.seeds) {
          batch.set(firestore.doc('users/${user.uid}/categories/${c.id}'), c.toMap());
        }
        await batch.commit();
      },
      err: (f) async => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(f.message))),
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Stack(children: [
          // Decorative gold coins behind the form — never intercept input,
          // static under reduced motion, paused while backgrounded.
          const Positioned.fill(child: FloatingCoinsBackdrop(opacity: 0.4)),
          Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(FgTokens.s6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Create your account',
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: FgTokens.s2),
                    Text('Start understanding your money in minutes.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: FgTokens.s6),
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Display name', prefixIcon: Icon(Icons.person_outline)),
                      validator: Validators.name,
                    ),
                    const SizedBox(height: FgTokens.s4),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                      validator: Validators.email,
                    ),
                    const SizedBox(height: FgTokens.s4),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        helperText: 'At least 8 characters with a number',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _obscure ? 'Show password' : 'Hide password',
                          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: Validators.password,
                    ),
                    const SizedBox(height: FgTokens.s4),
                    CheckboxListTile(
                      value: _acceptedTerms,
                      onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'I understand FinGenius AI is an educational financial-wellness tool, '
                        'not professional financial advice.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(height: FgTokens.s4),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Create account'),
                    ),
                    TextButton(
                      onPressed: () => context.go('/signin'),
                      child: const Text('Already have an account? Sign in'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ),
        ]),
      ),
    );
  }
}
