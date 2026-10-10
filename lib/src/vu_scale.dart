import 'dart:math' as math;

/// The scale of a meter: which level sits where along the sweep.
///
/// A scale knows nothing about angles. It places every level at a *position*
/// between 0 (the first mark) and 1 (the last mark); the face decides where
/// on its dial that position lies. So every scale works on every face.
///
/// Three ways to get one:
///
/// * [VuScale.analog] — the classic one, −20 … +6 dB, hot above 0. For
///   signals with headroom above their nominal level.
/// * [VuScale.digital] — −40 … 0 dBFS, hot over the last 6 dB. For digital
///   levels, where nothing exists above full scale: the needle ends at 0 and
///   the red zone means "about to clip".
/// * your own: [VuScale.even] spreads a list of levels evenly, the plain
///   constructor takes every mark with its position.
class VuScale {
  /// A scale from its marks.
  ///
  /// [marks] lists every division as `(level, position)`, ascending, the
  /// first at position 0 and the last at 1. The levels in [majorDb] get a
  /// long tick and a number; all others a short tick.
  const VuScale({
    required this.marks,
    required this.majorDb,
    required this.hotFromDb,
    required this.silenceDb,
    this.fullPercentDb = 0,
    this.majorPercent = const [20, 40, 60, 80, 100],
    this.minorPercent = const [10, 30, 50, 70, 90],
    this.unit = 'dB',
  });

  /// A scale whose numbered [levels] are spread evenly along the sweep.
  ///
  /// [minorTicks] short ticks divide each step. [hotFromDb] starts the hot
  /// zone (default: none — pass a level, typically the last or second to
  /// last). Levels at or below [silenceDb] rest left of the scale; by
  /// default that is one step below the first level.
  ///
  /// ```dart
  /// VuScale.even(levels: [-60, -48, -36, -24, -12, 0], hotFromDb: -12,
  ///     unit: 'dBFS')
  /// ```
  factory VuScale.even({
    required List<double> levels,
    int minorTicks = 1,
    double? hotFromDb,
    double? silenceDb,
    double? fullPercentDb,
    List<int> majorPercent = const [20, 40, 60, 80, 100],
    List<int> minorPercent = const [10, 30, 50, 70, 90],
    String unit = 'dB',
  }) {
    if (levels.length < 2) {
      throw ArgumentError.value(levels, 'levels', 'needs at least two');
    }
    for (var i = 1; i < levels.length; i++) {
      if (levels[i] <= levels[i - 1]) {
        throw ArgumentError.value(levels, 'levels', 'must be ascending');
      }
    }
    final steps = levels.length - 1;
    final parts = minorTicks + 1;
    final marks = <(double, double)>[
      for (var i = 0; i < steps; i++)
        for (var k = 0; k < parts; k++)
          (
            levels[i] + (levels[i + 1] - levels[i]) * k / parts,
            (i + k / parts) / steps,
          ),
      (levels.last, 1),
    ];
    return VuScale(
      marks: marks,
      majorDb: List.unmodifiable(levels),
      // Above the last mark nothing is drawn, so this means "no hot zone".
      hotFromDb: hotFromDb ?? levels.last + 1,
      silenceDb: silenceDb ?? levels.first - (levels[1] - levels.first),
      fullPercentDb: fullPercentDb ?? levels.last,
      majorPercent: majorPercent,
      minorPercent: minorPercent,
      unit: unit,
    );
  }

  /// −20 … +6 dB, hot above 0 dB; 100 % is 0 dB.
  ///
  /// The divisions follow the original artwork — as on a real VU meter they
  /// are drawn, not computed, and their spacing is neither linear in dB nor
  /// in voltage.
  static const VuScale analog = VuScale(
    marks: [
      (-20, 0),
      (-15, 0.0997),
      (-12, 0.1596),
      (-10, 0.1995),
      (-8, 0.2662),
      (-7, 0.2995),
      (-6, 0.3395),
      (-5, 0.3796),
      (-4, 0.4296),
      (-3, 0.4797),
      (-2, 0.5447),
      (-1, 0.6099),
      (0, 0.68),
      (1, 0.7701),
      (2, 0.8452),
      (3, 0.9001),
      (4, 0.9335),
      (5, 0.9667),
      (6, 1),
    ],
    majorDb: [-20, -10, -5, -3, 0, 3, 6],
    hotFromDb: 0,
    silenceDb: -40,
  );

  /// −40 … 0 dBFS, hot over the last 6 dB; 100 % is full scale.
  ///
  /// The ticks stand where [analog] has them. The numbered ones carry round
  /// levels; the short ones in between divide the sweep evenly, so their
  /// levels are not round.
  static const VuScale digital = VuScale(
    marks: [
      (-40, 0),
      (-30.011, 0.0997),
      (-24.004, 0.1596),
      (-20, 0.1995),
      (-17.039, 0.2662),
      (-15.559, 0.2995),
      (-13.779, 0.3395),
      (-12, 0.3796),
      (-10.5, 0.4296),
      (-9, 0.4797),
      (-8.026, 0.5447),
      (-7.05, 0.6099),
      (-6, 0.68),
      (-4.772, 0.7701),
      (-3.749, 0.8452),
      (-3, 0.9001),
      (-1.999, 0.9335),
      (-1.001, 0.9667),
      (0, 1),
    ],
    majorDb: [-40, -20, -12, -9, -6, -3, 0],
    hotFromDb: -6,
    silenceDb: -60,
    // Half of full scale is only 6 dB down, so the upper percentages crowd
    // into the hot zone; the numbers thin out towards the top instead.
    majorPercent: [10, 20, 30, 50, 100],
    minorPercent: [5, 15, 40, 60, 70, 80, 90],
    unit: 'dBFS',
  );

  /// Every drawn division, as `(level, position)`, ascending; positions run
  /// from 0 to 1.
  final List<(double db, double position)> marks;

  /// The divisions that carry a number and a long tick.
  final List<double> majorDb;

  /// From this level on the scale is drawn hot.
  final double hotFromDb;

  /// The level that is 100 % on the percent scale (linear in voltage).
  final double fullPercentDb;

  /// The percent scale: the numbered divisions and the short ones between.
  final List<int> majorPercent;
  final List<int> minorPercent;

  /// Levels at or below this sit at [restPosition].
  final double silenceDb;

  /// The unit written on the face.
  final String unit;

  /// The lowest and the highest mark.
  double get minDb => marks.first.$1;
  double get maxDb => marks.last.$1;

  /// Where the needle rests without signal — a little before the scale.
  static const double restPosition = -0.046;

  /// The position of [db] along the sweep: 0 at the first mark, 1 at the
  /// last.
  ///
  /// Between two marks the position is interpolated linearly in dB. Below
  /// the lowest mark the needle falls towards [restPosition], above the
  /// highest it stops at 1.
  double positionFor(double db) {
    if (db.isNaN || db <= silenceDb) return restPosition;
    final first = marks.first;
    if (db <= first.$1) {
      final t = (db - silenceDb) / (first.$1 - silenceDb);
      return restPosition + t * (first.$2 - restPosition);
    }
    for (var i = 1; i < marks.length; i++) {
      final (hiDb, hi) = marks[i];
      if (db <= hiDb) {
        final (loDb, lo) = marks[i - 1];
        return lo + (db - loDb) / (hiDb - loDb) * (hi - lo);
      }
    }
    return marks.last.$2;
  }

  /// The position for a percentage of [fullPercentDb].
  double positionForPercent(double percent) => percent <= 0
      ? restPosition
      : positionFor(fullPercentDb + 20 * math.log(percent / 100) / math.ln10);

  /// Where the hot zone begins, as a position; above 1 if there is none.
  double get hotPosition =>
      hotFromDb > maxDb ? 2 : positionFor(hotFromDb).clamp(0.0, 1.0);

  /// The number written at a numbered division.
  ///
  /// Negative levels carry their sign; the others are plain — on the hot
  /// side the colour says enough.
  String labelFor(double db) {
    final rounded = db.roundToDouble();
    final text = (db - rounded).abs() < 1e-9
        ? '${rounded.abs().toInt()}'
        : db.abs().toStringAsFixed(1);
    return db < 0 ? '-$text' : text;
  }

  /// Converts a linear amplitude to dB: 1.0 becomes [referenceDb].
  ///
  /// For [digital] leave [referenceDb] at 0 — an amplitude of 1.0 is full
  /// scale. For [analog] choose where full scale should sit, e.g. 6 for the
  /// last mark.
  static double dbFromAmplitude(double amplitude, {double referenceDb = 0}) {
    if (amplitude <= 0) return double.negativeInfinity;
    return 20 * math.log(amplitude) / math.ln10 + referenceDb;
  }
}
