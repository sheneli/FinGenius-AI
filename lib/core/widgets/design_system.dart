import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

/// FinGenius premium design-system components, adapted from the "Spendly"
/// Figma reference into the FinGenius brand (navy base, green→cyan growth
/// gradient, gold accent). Reused across screens for a consistent, modern feel.

/// Frosted-glass surface: subtle blur + translucent fill + hairline border.
/// Falls back gracefully on low-end devices (blur sigma kept modest).
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(FgTokens.s4),
    this.radius = FgTokens.rXl,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = (isDark ? Colors.white : FgTokens.navy)
        .withValues(alpha: isDark ? FgTokens.oGlassFill : 0.04);
    final border = (isDark ? Colors.white : FgTokens.navy)
        .withValues(alpha: FgTokens.oGlassBorder);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: fill,
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: border),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Large gradient hero used at the top of primary screens (dashboard,
/// profile). Optional rounded bottom for a "sheet peeking under" effect.
class GradientHero extends StatelessWidget {
  const GradientHero({
    super.key,
    required this.child,
    this.height,
    this.padding = const EdgeInsets.fromLTRB(FgTokens.s5, FgTokens.s6, FgTokens.s5, FgTokens.s6),
  });

  final Widget child;
  final double? height;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      padding: padding,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF16240C), Color(0xFF3E6B22), FgTokens.greenDeep],
          stops: [0.0, 0.6, 1.0],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(FgTokens.rXl)),
      ),
      child: child,
    );
  }
}

/// Compact statistic card (label, value, optional icon + trend chip).
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.accent,
    this.trend,
    this.trendUp,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? accent;
  final String? trend;
  final bool? trendUp;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accent ?? theme.colorScheme.primary;
    return Semantics(
      label: '$label: $value${trend != null ? ', trend $trend' : ''}',
      container: true,
      child: Material(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(FgTokens.rLg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(FgTokens.rLg),
          child: Padding(
            padding: const EdgeInsets.all(FgTokens.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (icon != null)
                      Container(
                        padding: const EdgeInsets.all(FgTokens.s2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(FgTokens.rSm),
                        ),
                        child: Icon(icon, size: FgTokens.iconSm, color: color),
                      ),
                    const Spacer(),
                    if (trend != null)
                      Row(
                        children: [
                          Icon(
                            (trendUp ?? true) ? Icons.trending_up : Icons.trending_down,
                            size: 14,
                            color: (trendUp ?? true) ? FgTokens.success : FgTokens.warning,
                          ),
                          const SizedBox(width: 2),
                          Text(trend!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                  color: (trendUp ?? true) ? FgTokens.success : FgTokens.warning)),
                        ],
                      ),
                  ],
                ),
                // A fixed gap, not a Spacer. The card is laid out inside an
                // IntrinsicHeight row, and a flex child there contributes
                // nothing to the intrinsic height — which is how the value and
                // label ended up clipped at larger font scales.
                const SizedBox(height: FgTokens.s5),
                // Scale the figure down rather than clip it: "Rs 4…" is
                // useless, whereas a slightly smaller "Rs 477K" still answers
                // the question. Only ever shrinks — never enlarges.
                ExcludeSemantics(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(value,
                          maxLines: 1,
                          softWrap: false,
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                ExcludeSemantics(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pairs [StatCard]s into rows of two that share the tallest card's height.
///
/// [IntrinsicHeight] is what makes this overflow-proof: each row asks its
/// children how tall they want to be instead of imposing a ratio, so the tiles
/// grow when the system font scale does. The previous `GridView.count` with a
/// fixed `childAspectRatio` could not do that, and clipped the value and label
/// on devices set to a larger display size.
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      final left = children[i];
      final right = i + 1 < children.length ? children[i + 1] : null;
      if (rows.isNotEmpty) rows.add(const SizedBox(height: FgTokens.s3));
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: left),
            const SizedBox(width: FgTokens.s3),
            // Keeps a lone final tile at half width instead of stretching it.
            Expanded(child: right ?? const SizedBox.shrink()),
          ],
        ),
      ));
    }
    return Column(children: rows);
  }
}

/// Premium settings/action row with a tinted leading icon, used in grouped
/// cards. Large touch target, chevron, optional destructive colour.
class ActionRow extends StatelessWidget {
  const ActionRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.destructive = false,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool destructive;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = destructive ? theme.colorScheme.error : theme.colorScheme.primary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: FgTokens.s4, vertical: FgTokens.s3),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(FgTokens.rMd),
              ),
              child: Icon(icon, size: FgTokens.iconMd, color: color),
            ),
            const SizedBox(width: FgTokens.s4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: destructive ? theme.colorScheme.error : null)),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            trailing ??
                (onTap != null
                    ? Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant)
                    : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}

/// Groups [ActionRow]s (or any children) inside one rounded card with
/// hairline dividers between them.
class GroupedCard extends StatelessWidget {
  const GroupedCard({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final divided = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      divided.add(children[i]);
      if (i < children.length - 1) {
        divided.add(Divider(
          height: 1,
          indent: FgTokens.s4 + 40 + FgTokens.s4,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
        ));
      }
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(children: divided),
    );
  }
}

/// Simple entrance animation: fade + slide up. Wrap page sections to give the
/// premium "content settles in" feel. Respects reduced-motion.
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({super.key, required this.child, this.delayMs = 0});
  final Widget child;
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    if (reduce) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: FgTokens.dMed + Duration(milliseconds: delayMs),
      curve: Curves.easeOutCubic,
      builder: (context, t, c) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, (1 - t) * 16), child: c),
      ),
      child: child,
    );
  }
}
