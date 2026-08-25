import 'dart:math' as math;

/// Explainable cash-flow forecasting: Holt's linear exponential smoothing
/// (level + trend) with an honest uncertainty band derived from historical
/// one-step forecast errors. No accuracy claims are made beyond what the
/// residuals support; insufficient data is reported, not papered over.
class ForecastPoint {
  const ForecastPoint(this.periodIndex, this.expectedMinor, this.lowMinor, this.highMinor);
  final int periodIndex; // 1 = next month
  final int expectedMinor;
  final int lowMinor; // expected − 1.28σ (~80% band)
  final int highMinor;
}

class ForecastResult {
  const ForecastResult({
    required this.points,
    required this.confidence,
    required this.insufficientData,
    this.meanAbsoluteError,
  });
  final List<ForecastPoint> points;

  /// 'low' | 'medium' | 'high' — driven by history length and error size.
  final String confidence;
  final bool insufficientData;
  final double? meanAbsoluteError;

  static const empty = ForecastResult(points: [], confidence: 'low', insufficientData: true);
}

class Forecaster {
  const Forecaster({this.alpha = 0.5, this.beta = 0.3});
  final double alpha; // level smoothing
  final double beta; // trend smoothing

  /// [history]: monthly totals in minor units, oldest first. Needs ≥ 3 months.
  ForecastResult forecast(List<int> history, {int horizon = 3}) {
    if (history.length < 3) return ForecastResult.empty;

    var level = history[0].toDouble();
    var trend = (history[1] - history[0]).toDouble();
    final errors = <double>[];

    for (var t = 1; t < history.length; t++) {
      final predicted = level + trend;
      errors.add((history[t] - predicted).abs());
      final prevLevel = level;
      level = alpha * history[t] + (1 - alpha) * (level + trend);
      trend = beta * (level - prevLevel) + (1 - beta) * trend;
    }

    final mae = errors.isEmpty ? 0.0 : errors.reduce((a, b) => a + b) / errors.length;
    final sigma = _stdev(errors);

    final points = <ForecastPoint>[];
    for (var h = 1; h <= horizon; h++) {
      final expected = level + trend * h;
      // Uncertainty grows with horizon (√h scaling of iid residuals).
      final band = 1.28 * sigma * math.sqrt(h.toDouble());
      points.add(ForecastPoint(h, expected.round(), (expected - band).round(), (expected + band).round()));
    }

    final mean = history.reduce((a, b) => a + b).abs() / history.length;
    final relError = mean < 1 ? 1.0 : mae / mean;
    final confidence = history.length >= 6 && relError < 0.25
        ? 'high'
        : (history.length >= 4 && relError < 0.6)
            ? 'medium'
            : 'low';

    return ForecastResult(
      points: points,
      confidence: confidence,
      insufficientData: false,
      meanAbsoluteError: mae,
    );
  }

  /// Backtest: compares one-step forecasts against actuals so the UI can show
  /// "last month we predicted X, actual was Y" — honest self-evaluation.
  List<(int predictedMinor, int actualMinor)> backtest(List<int> history) {
    final out = <(int, int)>[];
    if (history.length < 4) return out;
    for (var end = 3; end < history.length; end++) {
      final r = forecast(history.sublist(0, end), horizon: 1);
      if (r.points.isNotEmpty) out.add((r.points.first.expectedMinor, history[end]));
    }
    return out;
  }

  static double _stdev(List<double> xs) {
    if (xs.length < 2) return 0;
    final mean = xs.reduce((a, b) => a + b) / xs.length;
    final variance = xs.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) / (xs.length - 1);
    return math.sqrt(variance);
  }
}
