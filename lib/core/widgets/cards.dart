import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

/// Gradient hero card (used sparingly — dashboard hero, goal celebration).
class GradientCard extends StatelessWidget {
  const GradientCard({super.key, required this.child, this.gradient});
  final Widget child;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(FgTokens.s5),
        decoration: BoxDecoration(
          gradient: gradient ?? FgTokens.cardGradientDark,
          borderRadius: BorderRadius.circular(FgTokens.rXl),
          border: Border.all(color: Colors.white.withValues(alpha: FgTokens.oGlassBorder)),
        ),
        child: child,
      );
}

/// Compact metric (label + value + optional delta) for dashboard rows.
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color,
    this.semanticHint,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? color;
  final String? semanticHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$label: $value. ${semanticHint ?? ''}',
      container: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(FgTokens.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                if (icon != null) ...[
                  Icon(icon, size: FgTokens.iconSm, color: color ?? theme.colorScheme.primary),
                  const SizedBox(width: FgTokens.s2),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
              const SizedBox(height: FgTokens.s2),
              ExcludeSemantics(
                child: Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.actionLabel, this.onAction});
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(FgTokens.s1, FgTokens.s6, FgTokens.s1, FgTokens.s3),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

/// Confirmation bottom sheet for destructive/consequential actions.
Future<bool> showConfirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    // Without this the sheet is capped at 9/16 of the screen and its contents
    // are clipped rather than fitted. The AI-consent copy is the longest of the
    // callers and overflowed by 40px on a 720x1600 device, painting the striped
    // overflow banner across the "Turn on" button. Scroll-controlled lets the
    // sheet take the height it needs, up to the cap applied below.
    isScrollControlled: true,
    builder: (context) {
      final theme = Theme.of(context);
      final media = MediaQuery.of(context);
      return SafeArea(
        child: ConstrainedBox(
          // Never taller than most of the screen; beyond that the body scrolls
          // so the actions stay reachable at any text scale.
          constraints: BoxConstraints(maxHeight: media.size.height * 0.85),
          child: Padding(
            padding: EdgeInsets.only(
              left: FgTokens.s6,
              right: FgTokens.s6,
              top: FgTokens.s6,
              // Keeps the buttons clear of the keyboard if one is open behind.
              bottom: FgTokens.s6 + media.viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Only the prose scrolls; the actions stay pinned and visible,
                // which is what makes a long message safe on a small screen.
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(title, style: theme.textTheme.titleLarge),
                        const SizedBox(height: FgTokens.s3),
                        Text(
                          message,
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: FgTokens.s6),
                FilledButton(
                  style: destructive
                      ? FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.error)
                      : null,
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(confirmLabel),
                ),
                const SizedBox(height: FgTokens.s2),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  return result ?? false;
}
