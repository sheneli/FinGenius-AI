import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/config/session_providers.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/data/demo_data_seeder.dart';
import '../../../core/security/app_lock_controller.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/design_system.dart';
import '../../accounts/domain/account.dart';
import '../../goals/presentation/goal_providers.dart';
import '../../transactions/presentation/transaction_providers.dart';
import 'edit_profile_screen.dart';
import 'profile_avatar.dart';

/// Premium, Figma-inspired Profile page: gradient hero with avatar + identity,
/// financial statistic cards, and grouped premium action rows.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final email = ref.watch(authStateProvider).valueOrNull?.email ?? profile?.email ?? '';
    final currency = profile?.prefs.currency ?? 'LKR';

    final accounts = ref.watch(accountsStreamProvider).valueOrNull ?? const <Account>[];
    final totals = ref.watch(monthTotalsProvider);
    final health = ref.watch(healthScoreProvider);
    final goals = ref.watch(goalsStreamProvider).valueOrNull ?? const [];

    final netWorth = accounts.fold<int>(0, (s, a) => s + a.balanceMinor);
    final savedMinor = goals.fold<int>(0, (s, g) => s + g.savedMinor);

    final display = (profile?.displayName ?? '').trim();
    final name = display.isNotEmpty ? display : (email.isNotEmpty ? email.split('@').first : 'Your account');
    final initial = (display.isNotEmpty ? display : (email.isEmpty ? '?' : email))
        .substring(0, 1)
        .toUpperCase();

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ---- Gradient hero ----
          FadeSlideIn(
            child: GradientHero(
              padding: const EdgeInsets.fromLTRB(FgTokens.s5, FgTokens.s10, FgTokens.s5, FgTokens.s6),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Profile',
                          style: TextStyle(
                              color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Preferences',
                        icon: const Icon(Icons.settings_outlined, color: Colors.white),
                        onPressed: () => context.go('/profile/preferences'),
                      ),
                    ],
                  ),
                  const SizedBox(height: FgTokens.s2),
                  ProfileAvatar(photoUrl: profile?.photoUrl, initial: initial, size: 104),
                  const SizedBox(height: FgTokens.s4),
                  Text(name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(email,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14)),
                  const SizedBox(height: FgTokens.s3),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: FgTokens.s2,
                    runSpacing: FgTokens.s1,
                    children: [
                      _heroChip(Icons.favorite_outline, 'Health ${health.score}/100'),
                      if (profile?.createdAt != null)
                        _heroChip(Icons.event_outlined,
                            'Since ${DateFormat.yMMM().format(profile!.createdAt!)}'),
                      if ((profile?.phone ?? '').isNotEmpty)
                        _heroChip(Icons.phone_outlined, profile!.phone),
                    ],
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(FgTokens.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---- Statistics ----
                // Two intrinsic-height rows rather than a GridView: a fixed
                // childAspectRatio cannot hold at every system font scale, and
                // on devices with larger display size it clipped the labels.
                // Paired rows keep the 2×2 look while sizing to content.
                FadeSlideIn(
                  delayMs: 60,
                  child: StatGrid(
                    children: [
                      StatCard(
                        label: 'Net worth',
                        value: Money(netWorth, currency).format(compact: true),
                        icon: Icons.account_balance_wallet_outlined,
                        accent: FgTokens.cyan,
                      ),
                      StatCard(
                        label: 'Spent this month',
                        value: Money(totals.expenseMinor, currency).format(compact: true),
                        icon: Icons.trending_down,
                        accent: FgTokens.warning,
                      ),
                      StatCard(
                        label: 'Total saved',
                        value: Money(savedMinor, currency).format(compact: true),
                        icon: Icons.savings_outlined,
                        accent: FgTokens.success,
                      ),
                      StatCard(
                        label: 'Health score',
                        value: '${health.score}',
                        icon: Icons.monitor_heart_outlined,
                        accent: FgTokens.gold,
                        onTap: () => context.go('/plans/reports'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: FgTokens.s5),

                // ---- Account section ----
                Text('Account', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: FgTokens.s2),
                FadeSlideIn(
                  delayMs: 120,
                  child: GroupedCard(children: [
                    ActionRow(
                      icon: Icons.edit_outlined,
                      title: 'Edit profile',
                      subtitle: 'Name, phone and photo',
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => const EditProfileScreen())),
                    ),
                    ActionRow(
                      icon: Icons.dataset_outlined,
                      title: 'Demo sample data',
                      subtitle: 'Realistic sample finances for testing & preview',
                      onTap: () => _toggleDemoData(context, ref, currency),
                    ),
                    ActionRow(
                      icon: Icons.tune,
                      title: 'Preferences',
                      subtitle: 'Currency, theme, payday, quiet hours',
                      onTap: () => context.go('/profile/preferences'),
                    ),
                  ]),
                ),
                const SizedBox(height: FgTokens.s5),

                // ---- Security & privacy ----
                Text('Security & privacy',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: FgTokens.s2),
                FadeSlideIn(
                  delayMs: 160,
                  child: GroupedCard(children: [
                    ActionRow(
                      icon: Icons.security_outlined,
                      title: 'Security',
                      subtitle: 'Biometric lock, password',
                      onTap: () => context.go('/profile/security'),
                    ),
                    ActionRow(
                      icon: Icons.notifications_outlined,
                      title: 'Notifications & consent',
                      onTap: () => context.go('/profile/preferences'),
                    ),
                    ActionRow(
                      icon: Icons.download_outlined,
                      title: 'Export my data',
                      onTap: () => context.go('/profile/export'),
                    ),
                    ActionRow(
                      icon: Icons.info_outline,
                      title: 'About & legal',
                      onTap: () => context.go('/profile/about'),
                    ),
                  ]),
                ),
                const SizedBox(height: FgTokens.s5),

                // ---- Session ----
                FadeSlideIn(
                  delayMs: 200,
                  child: GroupedCard(children: [
                    ActionRow(
                      icon: Icons.logout,
                      title: 'Sign out',
                      onTap: () => _signOut(context, ref),
                    ),
                    ActionRow(
                      icon: Icons.delete_forever_outlined,
                      title: 'Delete account',
                      destructive: true,
                      onTap: () => context.go('/profile/delete-account'),
                    ),
                  ]),
                ),
                const SizedBox(height: FgTokens.s6),
                Center(
                  child: Text('FinGenius AI · v1.0.0',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ),
                const SizedBox(height: FgTokens.s8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroChip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: FgTokens.s3, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(FgTokens.rPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Future<void> _toggleDemoData(BuildContext context, WidgetRef ref, String currency) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final seeder = DemoDataSeeder(ref.read(firestoreProvider));
    final hasDemo = await seeder.hasDemoData(uid);
    if (!context.mounted) return;

    if (hasDemo) {
      final confirmed = await showConfirmSheet(
        context,
        title: 'Turn off demo data?',
        message: 'This will remove all sample demo transactions, demo accounts, budgets, '
            'and bills from your account. Your personal real transactions will remain untouched.',
        confirmLabel: 'Turn off & clear',
        destructive: true,
      );
      if (!confirmed || !context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(const SnackBar(content: Text('Clearing demo data…')));
      try {
        final removed = await seeder.clearDemoData(uid);
        messenger.showSnackBar(SnackBar(content: Text('Demo data turned off — $removed sample records removed.')));
      } catch (_) {
        messenger.showSnackBar(
            const SnackBar(content: Text('Could not clear demo data. Check your connection.')));
      }
    } else {
      final confirmed = await showConfirmSheet(
        context,
        title: 'Turn on demo data?',
        message: 'Adds ~3 months of sample accounts, transactions, budgets, goals, bills '
            'and notifications to preview features. You can turn it off anytime right here.',
        confirmLabel: 'Turn on demo data',
      );
      if (!confirmed || !context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(const SnackBar(content: Text('Loading demo data…')));
      try {
        final count = await seeder.seed(uid, currency: currency);
        messenger.showSnackBar(SnackBar(content: Text('Demo data turned on — $count sample records loaded.')));
      } catch (_) {
        messenger.showSnackBar(
            const SnackBar(content: Text('Could not load demo data. Check your connection.')));
      }
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmSheet(
      context,
      title: 'Sign out?',
      message: 'Local data on this device will be removed. Anything not yet synced will be lost.',
      confirmLabel: 'Sign out',
    );
    if (!confirmed) return;
    final uid = ref.read(currentUidProvider);
    // Drop any pending lock so the next sign-in is not stuck behind it. The
    // stored *preference* is deliberately left alone — the user's app-lock
    // choice must survive logging out and back in.
    ref.read(appLockedProvider.notifier).resetForSignOut();
    await ref.read(authRepositoryProvider).signOut();
    if (uid != null) {
      await ref.read(sessionCleanerProvider).onLogout(uid);
    }
  }
}
