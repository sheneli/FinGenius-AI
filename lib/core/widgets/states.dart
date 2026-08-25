import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import 'mascot.dart';

/// Standardised loading / empty / error rendering so every screen has real
/// states without re-implementing them.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.skeleton,
    this.onRetry,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final Widget? skeleton;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => value.when(
        data: data,
        loading: () => skeleton ?? const SkeletonList(),
        error: (e, _) => ErrorState(onRetry: onRetry),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.showMascot = true,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  /// Show the friendly mascot instead of the plain icon badge.
  final bool showMascot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(FgTokens.s8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showMascot)
              const Mascot(size: 132, mood: MascotMood.searching)
            else
              Container(
                padding: const EdgeInsets.all(FgTokens.s5),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: FgTokens.iconLg, color: theme.colorScheme.primary),
              ),
            const SizedBox(height: FgTokens.s4),
            Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: FgTokens.s2),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: FgTokens.s5),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, this.message, this.onRetry});
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => EmptyState(
        showMascot: false,
        icon: Icons.error_outline,
        title: 'Something went wrong',
        message: message ?? "We couldn't load this right now. Your data is safe.",
        actionLabel: onRetry == null ? null : 'Try again',
        onAction: onRetry,
      );
}

/// Shimmer-free skeleton (respects reduced motion by being static).
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.rows = 6});
  final int rows;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06);
    return Semantics(
      label: 'Loading',
      child: ListView.separated(
        padding: const EdgeInsets.all(FgTokens.s4),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: rows,
        separatorBuilder: (_, __) => const SizedBox(height: FgTokens.s3),
        itemBuilder: (_, __) => Container(
          height: 64,
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(FgTokens.rMd),
          ),
        ),
      ),
    );
  }
}
