import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/security/app_lock_controller.dart';
import '../../features/accounts/presentation/accounts_screen.dart';
import '../../features/ai_assistant/presentation/ai_chat_screen.dart';
import '../../features/authentication/presentation/forgot_password_screen.dart';
import '../../features/authentication/presentation/lock_screen.dart';
import '../../features/authentication/presentation/sign_in_screen.dart';
import '../../features/authentication/presentation/sign_up_screen.dart';
import '../../features/authentication/presentation/verify_email_screen.dart';
import '../../features/bills/presentation/bills_screen.dart';
import '../../features/budgets/presentation/budgets_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/goals/presentation/goals_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/onboarding/presentation/welcome_screen.dart';
import '../../features/plans/presentation/plans_screen.dart';
import '../../features/profile/presentation/about_screen.dart';
import '../../features/profile/presentation/data_export_screen.dart';
import '../../features/profile/presentation/delete_account_screen.dart';
import '../../features/profile/presentation/preferences_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/security_settings_screen.dart';
import '../../features/receipt_scanner/presentation/receipt_scan_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/subscriptions/presentation/subscriptions_screen.dart';
import '../../features/transactions/presentation/add_transaction_screen.dart';
import '../../features/transactions/presentation/transaction_detail_screen.dart';
import '../../features/transactions/presentation/transactions_screen.dart';
import '../config/session_providers.dart';
import 'shell_scaffold.dart';

/// Route table. Guards: unauthenticated → /signin; unverified → /verify-email;
/// biometric-locked → /lock. Five-tab shell: Home, Transactions, AI, Plans, Profile.
final routerProvider = Provider<GoRouter>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  final authState = ref.watch(authStateProvider);
  final locked = ref.watch(appLockedProvider);

  return GoRouter(
    initialLocation: '/welcome',
    redirect: (context, state) {
      final user = authRepo.currentUser;
      final loggingIn = {'/welcome', '/signin', '/signup', '/forgot-password', '/onboarding'}
          .contains(state.matchedLocation);

      if (user == null) return loggingIn ? null : '/welcome';
      if (locked && state.matchedLocation != '/lock') return '/lock';
      if (loggingIn || state.matchedLocation == '/verify-email') {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/signin', builder: (_, __) => const SignInScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignUpScreen()),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(path: '/verify-email', builder: (_, __) => const VerifyEmailScreen()),
      GoRoute(path: '/lock', builder: (_, __) => const LockScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => ShellScaffold(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/home',
              builder: (_, __) => const DashboardScreen(),
              routes: [
                GoRoute(path: 'notifications', builder: (_, __) => const NotificationsScreen()),
                GoRoute(path: 'accounts', builder: (_, __) => const AccountsScreen()),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/transactions',
              builder: (_, __) => const TransactionsScreen(),
              routes: [
                GoRoute(path: 'add', builder: (_, state) => AddTransactionScreen(initialType: state.uri.queryParameters['type'])),
                GoRoute(path: 'scan', builder: (_, __) => const ReceiptScanScreen()),
                GoRoute(path: ':id', builder: (_, state) => TransactionDetailScreen(txId: state.pathParameters['id']!)),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/assistant', builder: (_, __) => const AiChatScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/plans',
              builder: (_, __) => const PlansScreen(),
              routes: [
                GoRoute(path: 'budgets', builder: (_, __) => const BudgetsScreen()),
                GoRoute(path: 'goals', builder: (_, __) => const GoalsScreen()),
                GoRoute(path: 'bills', builder: (_, __) => const BillsScreen()),
                GoRoute(path: 'subscriptions', builder: (_, __) => const SubscriptionsScreen()),
                GoRoute(path: 'reports', builder: (_, __) => const ReportsScreen()),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              builder: (_, __) => const ProfileScreen(),
              routes: [
                GoRoute(path: 'preferences', builder: (_, __) => const PreferencesScreen()),
                GoRoute(path: 'security', builder: (_, __) => const SecuritySettingsScreen()),
                GoRoute(path: 'export', builder: (_, __) => const DataExportScreen()),
                GoRoute(path: 'delete-account', builder: (_, __) => const DeleteAccountScreen()),
                GoRoute(path: 'about', builder: (_, __) => const AboutScreen()),
              ],
            ),
          ]),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.uri}')),
    ),
  );
});
