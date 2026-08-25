import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Vector-painted 3D gold coin (shared by the welcome and sign-up screens).
/// No image assets — renders crisply at any density and costs ~0 bytes.
class GoldCoin extends StatelessWidget {
  const GoldCoin({super.key, required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 1.14, // room for the 3D thickness + shadow
      child: CustomPaint(painter: CoinPainter()),
    );
  }
}

class CoinPainter extends CustomPainter {
  static const _rimLight = Color(0xFFFFF1B8);
  static const _gold = Color(0xFFF6C948);
  static const _goldDeep = Color(0xFFC8901E);
  static const _bronze = Color(0xFF9A6A12);
  static const _bronzeDark = Color(0xFF6E4A0C);

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final center = Offset(r, r);
    final thickness = r * 0.16;

    // Drop shadow
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(center.dx, center.dy + thickness + r * 0.28),
          width: r * 1.7,
          height: r * 0.5),
      shadow,
    );

    // Coin edge / thickness (offset down, darker bronze)
    final edge = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_bronze, _bronzeDark],
      ).createShader(Rect.fromCircle(
          center: Offset(center.dx, center.dy + thickness), radius: r));
    canvas.drawCircle(Offset(center.dx, center.dy + thickness), r, edge);

    // Top face — radial gold with a top-left highlight
    final face = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.45, -0.55),
        radius: 1.1,
        colors: [_rimLight, _gold, _goldDeep],
        stops: [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, face);

    // Raised rim ring
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.08
      ..shader = const SweepGradient(
        colors: [_rimLight, _goldDeep, _bronze, _gold, _rimLight],
      ).createShader(Rect.fromCircle(center: center, radius: r * 0.9));
    canvas.drawCircle(center, r * 0.9, rim);

    // Reeded edge ticks
    final tick = Paint()
      ..color = _goldDeep.withValues(alpha: 0.5)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    const ticks = 48;
    for (var i = 0; i < ticks; i++) {
      final a = (i / ticks) * 2 * math.pi;
      final p1 = center + Offset(math.cos(a), math.sin(a)) * (r * 0.95);
      final p2 = center + Offset(math.cos(a), math.sin(a)) * r;
      canvas.drawLine(p1, p2, tick);
    }

    // Inner disc (slightly recessed face for the "$")
    final disc = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.3, -0.4),
        colors: [Color(0xFFFBDD84), _gold, _goldDeep],
        stops: [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: r * 0.78));
    canvas.drawCircle(center, r * 0.78, disc);

    // Top-left specular highlight arc
    final gloss = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.09
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r * 0.72),
      math.pi * 1.05,
      math.pi * 0.5,
      false,
      gloss,
    );

    // "$" glyph — embossed (light copy behind, deep copy front)
    _drawDollar(canvas, center, r,
        offset: const Offset(0, -1.5), color: _rimLight.withValues(alpha: 0.8));
    _drawDollar(canvas, center, r, offset: Offset.zero, color: _bronzeDark);
  }

  void _drawDollar(Canvas canvas, Offset center, double r,
      {required Offset offset, required Color color}) {
    final tp = TextPainter(
      text: TextSpan(
        text: r'$',
        style: TextStyle(
          fontSize: r * 1.05,
          fontWeight: FontWeight.w900,
          color: color,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2) + offset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Decorative floating coins layered BEHIND content (wrap in a Stack).
///
/// - Never intercepts touches ([IgnorePointer]).
/// - Causes no layout shift (positioned within the existing paint area).
/// - Static when the OS reduced-motion setting is on.
/// - Pauses the animation while the app is backgrounded.
class FloatingCoinsBackdrop extends StatefulWidget {
  const FloatingCoinsBackdrop({super.key, this.opacity = 0.55});

  /// Dim the coins so foreground text keeps full contrast.
  final double opacity;

  @override
  State<FloatingCoinsBackdrop> createState() => _FloatingCoinsBackdropState();
}

class _FloatingCoinsBackdropState extends State<FloatingCoinsBackdrop>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _float;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    // Created eagerly (never lazily): a lazily-created controller would be
    // instantiated inside dispose() when reduced motion skips the animation.
    _float =
        AnimationController(vsync: this, duration: const Duration(seconds: 5));
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.of(context).disableAnimations;
    if (_reduceMotion) {
      _float.stop();
    } else if (!_float.isAnimating) {
      _float.repeat(reverse: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Battery hygiene: no offscreen animation work in the background.
    if (state == AppLifecycleState.resumed) {
      if (!_reduceMotion && !_float.isAnimating) _float.repeat(reverse: true);
    } else {
      _float.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = _reduceMotion;
    return IgnorePointer(
      child: Opacity(
        opacity: widget.opacity,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            Widget coin(double left, double top, double size, double phase,
                double amplitude) {
              if (reduceMotion) {
                return Positioned(
                    left: left, top: top, child: GoldCoin(size: size));
              }
              return AnimatedBuilder(
                animation: _float,
                builder: (context, child) {
                  final dy =
                      math.sin(_float.value * 2 * math.pi + phase) * amplitude;
                  return Positioned(left: left, top: top + dy, child: child!);
                },
                child: GoldCoin(size: size),
              );
            }

            return Stack(clipBehavior: Clip.none, children: [
              coin(w * 0.62, 6, 88, 0, 10),
              coin(w * 0.06, 40, 52, math.pi * 0.7, 7),
              coin(w * 0.82, 130, 40, math.pi * 1.3, 6),
            ]);
          },
        ),
      ),
    );
  }
}
