import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

/// Presentation-only fintech components distilled from the ROSCA ("Dart") and
/// Crypto Wallet Figma references and adapted to the FinGenius brand
/// (neon lime on forest black).
///
/// Every widget here is pure UI: it renders what it is given and calls back.
/// No provider reads, no navigation, no business logic — screens keep owning
/// their data and actions, so the redesign cannot change behaviour.

// ─────────────────────────────────────────────────────────────────────────────
// Greeting header — "Hello Anna / Welcome Back!" pattern (Crypto ref)
// ─────────────────────────────────────────────────────────────────────────────

/// Screen-top greeting: small accent line, bold title, and trailing actions
/// laid out as tappable rounded squares.
class GreetingHeader extends StatelessWidget {
  const GreetingHeader({
    super.key,
    required this.greeting,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
  });

  final String greeting;
  final String title;
  final String? subtitle;

  /// Usually the user's avatar.
  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: FgTokens.s3)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                greeting,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800, height: 1.15),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
            ],
          ),
        ),
        for (final a in actions) ...[const SizedBox(width: FgTokens.s2), a],
      ],
    );
  }
}

/// Rounded-square icon button used in headers (bell, eye, settings).
class SquareIconButton extends StatelessWidget {
  const SquareIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.badge = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;

  /// Small dot indicating unread/pending items.
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(FgTokens.rMd),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(FgTokens.rMd),
            child: SizedBox(
              width: FgTokens.minTouchTarget,
              height: FgTokens.minTouchTarget,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(icon,
                      size: FgTokens.iconMd,
                      color: theme.colorScheme.onSurface),
                  if (badge)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: theme.colorScheme.surfaceContainer,
                              width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero balance card — gradient + delta chip + big figure (both refs)
// ─────────────────────────────────────────────────────────────────────────────

/// The single most important number on the screen. Caller supplies already
/// formatted strings so currency/hide-balance rules stay in the screen layer.
class BalanceHeroCard extends StatelessWidget {
  const BalanceHeroCard({
    super.key,
    required this.label,
    required this.amount,
    this.deltaLabel,
    this.deltaPositive = true,
    this.footer,
    this.onTap,
  });

  final String label;

  /// Pre-formatted amount widget (keeps AmountText / hide-balance behaviour).
  final Widget amount;
  final String? deltaLabel;
  final bool deltaPositive;

  /// Optional row beneath the figure (income / expense / savings pills).
  final Widget? footer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final onHero = const Color(0xFF0A1705); // dark ink reads on the lime wash
    return Semantics(
      container: true,
      button: onTap != null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(FgTokens.r2Xl),
          boxShadow: FgTokens.glow(FgTokens.green, alpha: 0.28),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(FgTokens.r2Xl),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Ink(
              decoration: const BoxDecoration(gradient: FgTokens.heroGradient),
              child: Padding(
                padding: const EdgeInsets.all(FgTokens.s5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: onHero.withValues(alpha: 0.75),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        if (deltaLabel != null)
                          _DeltaChip(
                              label: deltaLabel!,
                              positive: deltaPositive,
                              ink: onHero),
                      ],
                    ),
                    const SizedBox(height: FgTokens.s2),
                    DefaultTextStyle.merge(
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: onHero,
                                letterSpacing: -1,
                              ) ??
                          const TextStyle(),
                      child: amount,
                    ),
                    if (footer != null) ...[
                      const SizedBox(height: FgTokens.s4),
                      footer!,
                    ],
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

class _DeltaChip extends StatelessWidget {
  const _DeltaChip(
      {required this.label, required this.positive, required this.ink});
  final String label;
  final bool positive;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: FgTokens.s3, vertical: 5),
      decoration: BoxDecoration(
        color: ink.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(FgTokens.rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon + sign, never colour alone (accessibility).
          Icon(positive ? Icons.trending_up : Icons.trending_down,
              size: 14, color: ink),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: ink, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

/// Income / expense / savings pill shown inside the hero card footer.
class HeroStat extends StatelessWidget {
  const HeroStat({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final Widget value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF0A1705);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: FgTokens.s3, vertical: FgTokens.s2),
        margin: const EdgeInsets.only(right: FgTokens.s2),
        decoration: BoxDecoration(
          color: ink.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(FgTokens.rMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Icon(icon, size: 13, color: ink.withValues(alpha: 0.75)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: ink.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ]),
            const SizedBox(height: 2),
            DefaultTextStyle.merge(
              style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: ink, fontWeight: FontWeight.w800) ??
                  const TextStyle(),
              child: value,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick actions row — coloured tiles (Crypto ref "Actions")
// ─────────────────────────────────────────────────────────────────────────────

class QuickAction {
  const QuickAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.tint,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? tint;
}

/// Action tiles that share the row width equally, so no tile — and no label —
/// is ever clipped at the screen edge. Each tile calls the action's own
/// callback, so these stay wired to whatever the screen already did.
///
/// Designed for up to 4 actions on a phone; beyond that the row falls back to
/// horizontal scrolling rather than squeezing labels into unreadable slivers.
class QuickActionsRow extends StatelessWidget {
  const QuickActionsRow({super.key, required this.actions, this.maxFitted = 4});

  final List<QuickAction> actions;

  /// Above this count the row scrolls instead of dividing the width.
  final int maxFitted;

  Color _tint(int i) =>
      actions[i].tint ?? FgTokens.actionTints[i % FgTokens.actionTints.length];

  @override
  Widget build(BuildContext context) {
    if (actions.length > maxFitted) {
      return SizedBox(
        height: 96,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: FgTokens.s1),
          itemCount: actions.length,
          separatorBuilder: (_, __) => const SizedBox(width: FgTokens.s3),
          itemBuilder: (context, i) => SizedBox(
            width: 104,
            child: _ActionTile(action: actions[i], tint: _tint(i)),
          ),
        ),
      );
    }
    return SizedBox(
      height: 96,
      child: Row(
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: FgTokens.s3),
            Expanded(child: _ActionTile(action: actions[i], tint: _tint(i))),
          ],
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action, required this.tint});
  final QuickAction action;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: action.label,
      child: SizedBox.expand(
        child: Material(
          color: tint.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(FgTokens.rCard),
          child: InkWell(
            onTap: action.onTap,
            borderRadius: BorderRadius.circular(FgTokens.rCard),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: FgTokens.s2, vertical: FgTokens.s3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(FgTokens.s2),
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(FgTokens.rMd),
                    ),
                    child:
                        Icon(action.icon, size: FgTokens.iconSm, color: tint),
                  ),
                  // Scales down rather than truncating, so a longer label such
                  // as "Accounts" stays fully readable in a narrow tile.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      action.label,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelMedium
                          ?.copyWith(fontWeight: FontWeight.w700, height: 1.2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mini stat card with sparkline — "Top Movers" (Crypto ref)
// ─────────────────────────────────────────────────────────────────────────────

/// Compact metric with an optional sparkline. [spark] values are plotted in
/// order; an empty or single-point list renders the card without a chart.
class MiniStatCard extends StatelessWidget {
  const MiniStatCard({
    super.key,
    required this.label,
    required this.value,
    this.spark = const [],
    this.tint,
    this.onTap,
  });

  final String label;
  final String value;
  final List<double> spark;
  final Color? tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = tint ?? theme.colorScheme.primary;
    return Semantics(
      container: true,
      label: '$label: $value',
      button: onTap != null,
      child: Material(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(FgTokens.rCard),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(FgTokens.rCard),
          child: Padding(
            padding: const EdgeInsets.all(FgTokens.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 2),
                ExcludeSemantics(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                if (spark.length > 1) ...[
                  const SizedBox(height: FgTokens.s2),
                  SizedBox(
                    height: 26,
                    width: double.infinity,
                    child: CustomPaint(painter: _SparkPainter(spark, color)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.values, this.color);
  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.width <= 0) return;
    final lo = values.reduce(math.min);
    final hi = values.reduce(math.max);
    final span =
        (hi - lo).abs() < 1e-9 ? 1.0 : hi - lo; // avoid /0 on flat data
    final dx = size.width / (values.length - 1);

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = dx * i;
      final y = size.height - ((values[i] - lo) / span) * size.height;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }

    // Soft fill under the line.
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.30), color.withValues(alpha: 0.0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.color != color || !identical(old.values, values);
}

// ─────────────────────────────────────────────────────────────────────────────
// List row — transaction / item row shared by Activity, Bills, Plans
// ─────────────────────────────────────────────────────────────────────────────

/// Scannable row: tinted leading icon, title + subtitle, trailing amount and
/// optional badge. Used for transactions, bills and other money lists.
class FinListRow extends StatelessWidget {
  const FinListRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.iconTint,
    this.onTap,
    this.onLongPress,
    this.badge,
    this.semanticLabel,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// Usually an AmountText so hide-balances keeps working.
  final Widget trailing;
  final Color? iconTint;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Small trailing-side marker (e.g. pending-sync icon).
  final Widget? badge;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = iconTint ?? theme.colorScheme.primary;
    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      // A caller-supplied label replaces the row's own text for screen
      // readers, so the pieces are not announced twice.
      excludeSemantics: semanticLabel != null,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(FgTokens.rLg),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: FgTokens.s3, vertical: FgTokens.s3),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(FgTokens.rMd),
                ),
                child: Icon(icon, size: FgTokens.iconMd, color: tint),
              ),
              const SizedBox(width: FgTokens.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Row(children: [
                      Flexible(
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: FgTokens.s2),
                        badge!,
                      ],
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: FgTokens.s2),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// Wraps rows in one rounded card with hairline separators — the grouped-list
/// look used throughout both references.
class RowGroup extends StatelessWidget {
  const RowGroup({super.key, required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(vertical: FgTokens.s1),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(FgTokens.rCard),
        border: Border.all(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: FgTokens.s4 + 44,
                endIndent: FgTokens.s4,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section heading with optional trailing action
// ─────────────────────────────────────────────────────────────────────────────

class FinSectionHeader extends StatelessWidget {
  const FinSectionHeader(
    this.title, {
    super.key,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(
        FgTokens.s1, FgTokens.s6, FgTokens.s1, FgTokens.s3),
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: FgTokens.s2),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(actionLabel!),
                const SizedBox(width: 2),
                const Icon(Icons.chevron_right, size: FgTokens.iconSm),
              ]),
            ),
        ],
      ),
    );
  }
}
