import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

/// Financial-health gauge (0–100) with a full text alternative for
/// screen readers and colour-independent labelling.
class HealthGauge extends StatelessWidget {
  const HealthGauge({super.key, required this.score, this.size = 120});
  final int score;
  final double size;

  String get _band => score >= 75 ? 'Strong' : score >= 50 ? 'Steady' : score >= 25 ? 'Needs attention' : 'At risk';

  Color get _color => score >= 75
      ? FgTokens.success
      : score >= 50
          ? FgTokens.cyan
          : score >= 25
              ? FgTokens.warning
              : FgTokens.error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: 'Financial health score $score out of 100. Status: $_band. '
          'This is an app-defined wellness indicator, not a credit score.',
      child: ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _GaugePainter(score / 100, _color, theme.colorScheme.onSurface.withValues(alpha: 0.1)),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$score', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: _color)),
                  Text(_band, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter(this.fraction, this.color, this.track);
  final double fraction;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.09;
    final rect = Offset(stroke / 2, stroke / 2) & Size(size.width - stroke, size.height - stroke);
    const start = math.pi * 0.75;
    const sweep = math.pi * 1.5;
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    final valuePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, start, sweep, false, trackPaint);
    canvas.drawArc(rect, start, sweep * fraction.clamp(0.0, 1.0), false, valuePaint);
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.fraction != fraction || old.color != color;
}
