import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/widgets/gold_coin.dart';

/// Premium first-run welcome screen: floating 3D gold coins, a bold value
/// proposition and a glowing "Start Now" call to action.
///
/// The coins are painted with a [CustomPainter] (radial gold gradients + an
/// embossed "$"), so the screen ships with zero image assets and renders
/// crisply at any density.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _float =
      AnimationController(vsync: this, duration: const Duration(seconds: 4))
        ..repeat(reverse: true);
  late final AnimationController _enter =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
        ..forward();

  @override
  void dispose() {
    _float.dispose();
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final coinArea = size.height * 0.5;

    return Scaffold(
      backgroundColor: const Color(0xFF060A05),
      body: Stack(
        children: [
          // Deep background wash with a soft green aurora at the bottom.
          const Positioned.fill(child: _Backdrop()),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Coins hero ──────────────────────────────────────────────
                SizedBox(
                  height: coinArea,
                  width: double.infinity,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Vertical light streaks on the right, like the ref.
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _LightStreaksPainter(),
                        ),
                      ),
                      // Big coin
                      _FloatingCoin(
                        controller: _float,
                        phase: 0,
                        amplitude: 14,
                        child: const GoldCoin(size: 210),
                        left: size.width * 0.30,
                        top: coinArea * 0.16,
                      ),
                      // Small coin
                      _FloatingCoin(
                        controller: _float,
                        phase: math.pi,
                        amplitude: 10,
                        child: const GoldCoin(size: 96),
                        left: size.width * 0.12,
                        top: coinArea * 0.60,
                      ),
                    ],
                  ),
                ),

                // ── Copy + CTA ──────────────────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        FgTokens.s6, FgTokens.s4, FgTokens.s6, FgTokens.s8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Reveal(
                          controller: _enter,
                          start: 0.1,
                          child: Text(
                            'Maintain Your\nPersonal Finance,\nMade Simple',
                            style: theme.textTheme.headlineLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              height: 1.12,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: FgTokens.s4),
                        _Reveal(
                          controller: _enter,
                          start: 0.25,
                          child: Text(
                            'Manage your finances with ease. Start by '
                            'customizing your app experience for smarter '
                            'financial choices.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.62),
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: FgTokens.s8),
                        _Reveal(
                          controller: _enter,
                          start: 0.4,
                          child: _StartButton(
                            onPressed: () => context.go('/signin'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Background
// ─────────────────────────────────────────────────────────────────────────────

class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B120A), Color(0xFF060A05), Color(0xFF04160C)],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.0, 1.15),
            radius: 1.1,
            colors: [
              FgTokens.success.withValues(alpha: 0.16),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Floating wrapper + entrance reveal
// ─────────────────────────────────────────────────────────────────────────────

class _FloatingCoin extends StatelessWidget {
  const _FloatingCoin({
    required this.controller,
    required this.phase,
    required this.amplitude,
    required this.child,
    required this.left,
    required this.top,
  });

  final AnimationController controller;
  final double phase;
  final double amplitude;
  final Widget child;
  final double left;
  final double top;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, c) {
        final dy = math.sin(controller.value * 2 * math.pi + phase) * amplitude;
        return Positioned(left: left, top: top + dy, child: c!);
      },
      child: child,
    );
  }
}

/// Fade + slide-up reveal keyed to a fraction of a shared controller.
class _Reveal extends StatelessWidget {
  const _Reveal({
    required this.controller,
    required this.start,
    required this.child,
  });

  final AnimationController controller;
  final double start;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final anim = CurvedAnimation(
      parent: controller,
      curve: Interval(start, 1.0, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: anim,
      builder: (context, c) => Opacity(
        opacity: anim.value.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, (1 - anim.value) * 22), child: c),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Start Now button — dark pill with a green glow border
// ─────────────────────────────────────────────────────────────────────────────

class _StartButton extends StatefulWidget {
  const _StartButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  State<_StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends State<_StartButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Start Now',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _down ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 140),
          child: Container(
            height: 60,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0E1A0E), Color(0xFF13230F)],
              ),
              borderRadius: BorderRadius.circular(FgTokens.rPill),
              border: Border.all(color: FgTokens.success, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: FgTokens.success.withValues(alpha: 0.45),
                  blurRadius: 26,
                  spreadRadius: -4,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Start Now',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded,
                    size: 20, color: FgTokens.success),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Subtle vertical light streaks behind the coins (upper-right)
// ─────────────────────────────────────────────────────────────────────────────

class _LightStreaksPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rnd = [0.62, 0.70, 0.78, 0.86, 0.93];
    for (var i = 0; i < rnd.length; i++) {
      final x = size.width * rnd[i];
      final w = 2.0 + (i.isEven ? 1.5 : 0.0);
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            (i.isEven ? FgTokens.gold : FgTokens.success)
                .withValues(alpha: 0.0),
            (i.isEven ? FgTokens.gold : FgTokens.success)
                .withValues(alpha: 0.14),
            Colors.transparent,
          ],
          stops: const [0.0, 0.4, 1.0],
        ).createShader(Rect.fromLTWH(x, 0, w, size.height));
      canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height * 0.9), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
