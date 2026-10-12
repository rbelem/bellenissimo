import 'dart:math' as math;

/// The geometry of a baking pan.
enum PanShape { round, square, rectangular }

/// A baking pan, in centimetres: area in cm², volume in ml (1 cm³ = 1 ml).
class Pan {
  const Pan._(this.shape, this._firstCm, this._secondCm, this.depthCm);

  factory Pan.round(double diameterCm, double depthCm) {
    _requirePositive(diameterCm, 'diameterCm');
    _requirePositive(depthCm, 'depthCm');
    return Pan._(PanShape.round, diameterCm, diameterCm, depthCm);
  }

  factory Pan.square(double sideCm, double depthCm) {
    _requirePositive(sideCm, 'sideCm');
    _requirePositive(depthCm, 'depthCm');
    return Pan._(PanShape.square, sideCm, sideCm, depthCm);
  }

  factory Pan.rectangular(double lengthCm, double widthCm, double depthCm) {
    _requirePositive(lengthCm, 'lengthCm');
    _requirePositive(widthCm, 'widthCm');
    _requirePositive(depthCm, 'depthCm');
    return Pan._(PanShape.rectangular, lengthCm, widthCm, depthCm);
  }

  final PanShape shape;

  /// Diameter (round), side (square), or length (rectangular).
  final double _firstCm;

  /// Width; only meaningful for rectangular pans.
  final double _secondCm;

  final double depthCm;

  double get areaCm2 => switch (shape) {
        PanShape.round => math.pi * _firstCm * _firstCm / 4,
        PanShape.square => _firstCm * _firstCm,
        PanShape.rectangular => _firstCm * _secondCm,
      };

  double get volumeMl => areaCm2 * depthCm;

  static void _requirePositive(double value, String name) {
    if (value <= 0) throw ArgumentError.value(value, name, 'must be positive');
  }
}

/// How much batter the target pan holds relative to the base pan.
double panScaleFactor(Pan from, Pan to) => to.volumeMl / from.volumeMl;

/// Adapts a base baking time to a pan-size change. This is a heuristic,
/// not science: scaling time by volume overshoots because heat reaches the
/// centre slower than the batter grows, so time grows as factor^0.8,
/// clamped to half to double the base and rounded to whole minutes.
Duration scaledBakingTime(Duration base, double factor) {
  final scaled = base.inMinutes * math.pow(factor, 0.8);
  final clamped = scaled.clamp(base.inMinutes * 0.5, base.inMinutes * 2.0);
  return Duration(minutes: clamped.round());
}
