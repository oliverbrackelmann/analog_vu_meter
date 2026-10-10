import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../vu_face.dart';
import '../vu_scale.dart';
import 'shape.dart';

/// A dark dial with a glowing scale: deep blue to ice blue, hot from yellow
/// to red, a bright needle on a lit dome, a clip lamp at the right.
///
/// The original face of this package. The lengths and angles are those of
/// its artwork; the divisions come from the [VuScale].
class NeonVuFace extends VuFace {
  const NeonVuFace({
    this.background = const Color(0xFF201E1E),
    this.coolStart = const Color(0xFF3F8FE8),
    this.coolEnd = const Color(0xFF7FE8FF),
    this.hotStart = const Color(0xFFFFFF00),
    this.hotMiddle = const Color(0xFFFF951E),
    this.hotEnd = const Color(0xFFFF2A3C),
    this.accentColor = const Color(0xFF00D8FF),
    this.needle = const Color(0xFFA8F4FF),
    this.labelColor = const Color(0xFF4B4B4D),
    this.glow = true,
  });

  /// The dial.
  final Color background;

  /// The scale below the hot zone, from its start to the hot zone.
  final Color coolStart;
  final Color coolEnd;

  /// The hot zone.
  final Color hotStart;
  final Color hotMiddle;
  final Color hotEnd;

  /// Percent numbers, the unit, the bar and the pivot.
  final Color accentColor;

  final Color needle;

  /// The outline of the label in the lower half.
  final Color labelColor;

  /// Whether lit parts get a soft halo. Turn off on slow devices.
  final bool glow;

  @override
  String get name => 'neon';

  @override
  Color get accent => coolStart;

  @override
  Color get hot => hotEnd;

  // The artwork's own coordinate system; everything is drawn in these units
  // and scaled to the widget.
  static const double _width = 2443.26;
  static const Offset _pivot = Offset(1219.4, 1782.11);

  /// The sweep of the scale, in degrees clockwise from straight up. It is
  /// not symmetric: the clip lamp takes the room at the right.
  static const double _startAngle = -53.62;
  static const double _endAngle = 41.51;

  MaskFilter? _halo(double sigma) =>
      glow ? MaskFilter.blur(BlurStyle.normal, sigma) : null;

  /// The colour of the scale at [angle]: cool up to [zero], hot above.
  Color _at(_NeonDial d, double angle, double zero, {Color? start}) {
    if (angle <= zero) {
      final t = ((angle - d.start) / (zero - d.start)).clamp(0.0, 1.0);
      return Color.lerp(start ?? coolStart, coolEnd, t)!;
    }
    final span = d.end - zero;
    final t = span <= 0 ? 1.0 : ((angle - zero) / span).clamp(0.0, 1.0);
    return t < 0.33
        ? Color.lerp(hotStart, hotMiddle, t / 0.33)!
        : Color.lerp(hotMiddle, hotEnd, (t - 0.33) / 0.67)!;
  }

  void _band(
    Canvas canvas,
    _NeonDial d,
    double zero, {
    required double radius,
    required double width,
    required double from,
    required double to,
    Color? start,
  }) {
    final rect = Rect.fromCircle(center: d.pivot, radius: radius + d.grow);
    const step = 0.75;
    for (var a = from; a < to; a += step) {
      final sweep = math.min(step, to - a);
      canvas.drawArc(
        rect,
        // Flutter measures from the x axis; the dial from straight up.
        (a - 90) * math.pi / 180,
        // A hair of overlap hides the seams between the pieces.
        (sweep + 0.05) * math.pi / 180,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = _at(d, a + sweep / 2, zero, start: start),
      );
    }
  }

  void _tick(
    Canvas canvas,
    _NeonDial d,
    double angle,
    double from,
    double to,
    double width,
    Color color,
  ) {
    final a = d.polar(angle, from);
    final b = d.polar(angle, to);
    final halo = _halo(width * 0.6);
    if (halo != null) {
      canvas.drawLine(
        a,
        b,
        Paint()
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: 0.45)
          ..maskFilter = halo,
      );
    }
    canvas.drawLine(
      a,
      b,
      Paint()
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  /// Text centred on the dial at [angle] and [radius], turned to follow the
  /// arc unless [upright].
  void _text(
    Canvas canvas,
    _NeonDial d,
    VuFaceContext context,
    String text, {
    required double angle,
    required double radius,
    required double size,
    required Color color,
    bool upright = false,
  }) {
    TextPainter make(Paint? foreground) => TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              fontFamily: context.fontFamily,
              fontSize: size,
              fontWeight: FontWeight.w700,
              height: 1,
              color: foreground == null ? color : null,
              foreground: foreground,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

    final at = d.polar(angle, radius);
    canvas
      ..save()
      ..translate(at.dx, at.dy);
    if (!upright) canvas.rotate(angle * math.pi / 180);
    final halo = _halo(size * 0.09);
    if (halo != null) {
      final soft = make(
        Paint()
          ..color = color.withValues(alpha: 0.55)
          ..maskFilter = halo,
      );
      soft.paint(canvas, Offset(-soft.width / 2, -soft.height / 2));
    }
    final sharp = make(null);
    sharp.paint(canvas, Offset(-sharp.width / 2, -sharp.height / 2));
    canvas.restore();
  }

  @override
  void paintFace(Canvas canvas, Size size, VuFaceContext context) {
    final scale = context.scale;
    final d = _NeonDial(size);
    final zero = d.angle(scale.hotPosition.clamp(0.0, 1.0));
    final hasHot = scale.hotPosition <= 1;
    canvas.save();
    d.fit(canvas, size);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, _width, d.h),
      Paint()..color = background,
    );

    // A tick stands with its middle on its mark, so half of it would reach
    // beyond a band that ends on the mark. The bands run that much further:
    // every end closes flush with the outer edge of its tick.
    double pad(double width, double radius) =>
        width / (radius + d.grow) * 180 / math.pi;
    double half(double db) => scale.majorDb.contains(db) ? 10.6 : 6.125;
    final first = pad(half(scale.marks.first.$1), 980);
    final last = pad(half(scale.marks.last.$1), 980);

    // The outer scale: a broad band, cool up to the hot zone and hot above.
    _band(
      canvas,
      d,
      zero,
      radius: 980,
      width: 72,
      from: d.start - first,
      to: hasHot ? zero + 0.3 : d.end + last,
    );
    if (hasHot) {
      _band(
        canvas,
        d,
        zero,
        radius: 980,
        width: 72,
        from: zero + 0.6,
        to: d.end + last,
      );
    }

    for (final (db, position) in scale.marks) {
      final major = scale.majorDb.contains(db);
      final angle = d.angle(position);
      _tick(
        canvas,
        d,
        angle,
        1030,
        major ? 1166 : 1109,
        major ? 21.2 : 12.25,
        _at(d, angle, zero),
      );
    }
    for (final db in scale.majorDb) {
      final angle = d.angle(scale.positionFor(db));
      _text(
        canvas,
        d,
        context,
        scale.labelFor(db),
        angle: angle,
        radius: 1325,
        size: 132,
        color: _at(d, angle, zero),
      );
    }
    _text(
      canvas,
      d,
      context,
      scale.unit,
      angle: 1.1 * d.squeeze,
      radius: 1316,
      // A longer unit must still fit between its two neighbours.
      // On a flat arc the neighbours also move closer.
      size: (scale.unit.length > 2 ? 104 : 132) * (0.55 + 0.45 * d.squeeze),
      color: accentColor,
      upright: true,
    );

    // The percent scale: a fine arc with its ticks pointing inwards.
    if (context.showPercentScale) {
      final start = Color.lerp(const Color(0xFF2F7FE0), coolStart, 0.5)!;
      // Here only the 100 % tick can stand on an end.
      final full =
          scale.positionForPercent(100) >= 1 - 1e-9 ? pad(8, 759.5) : 0.0;
      _band(
        canvas,
        d,
        zero,
        radius: 759.5,
        width: 15,
        from: d.start - 0.2,
        to: hasHot ? zero : d.end + full,
        start: start,
      );
      if (hasHot) {
        _band(
          canvas,
          d,
          zero,
          radius: 759.5,
          width: 15,
          from: zero + 0.3,
          to: d.end + full,
        );
      }
      for (final percent in scale.majorPercent) {
        final angle = d.angle(scale.positionForPercent(percent.toDouble()));
        _tick(
            canvas, d, angle, 704, 757, 16, _at(d, angle, zero, start: start));
        _text(
          canvas,
          d,
          context,
          percent == 100 ? '100%' : '$percent',
          // "100%" is wider than the others and sits a little to the right.
          angle: percent == 100 ? angle + 2 : angle,
          radius: 878,
          size: 92,
          color: accentColor,
        );
      }
      for (final percent in scale.minorPercent) {
        final angle = d.angle(scale.positionForPercent(percent.toDouble()));
        _tick(
          canvas,
          d,
          angle,
          722,
          757,
          9.4,
          _at(d, angle, zero, start: start),
        );
      }
    }

    // Minus and plus at the two ends of the scale.
    canvas.drawRect(
      Rect.fromCenter(
        center: d.place(const Offset(322.6, 1226.2)),
        width: 77.3,
        height: 24.1,
      ),
      Paint()..color = Color.lerp(const Color(0xFF2F7FE0), coolStart, 0.5)!,
    );
    final plus = Paint()..color = hotEnd;
    canvas
      ..drawRect(
        Rect.fromCenter(
          center: d.place(const Offset(2011.9, 1068.5)),
          width: 85.2,
          height: 26.5,
        ),
        plus,
      )
      ..drawRect(
        Rect.fromCenter(
          center: d.place(const Offset(2011.9, 1068.5)),
          width: 21.4,
          height: 103.7,
        ),
        plus,
      );

    _label(canvas, d, context);

    // The bar the needle stands on.
    final bar = RRect.fromRectAndRadius(
      Rect.fromLTRB(880.2, d.pivot.dy - 18.71, 1558.6, d.pivot.dy + 14.29),
      const Radius.circular(16.5),
    );
    final halo = _halo(14);
    if (halo != null) {
      canvas.drawRRect(
        bar,
        Paint()
          ..color = accentColor.withValues(alpha: 0.5)
          ..maskFilter = halo,
      );
    }
    canvas.drawRRect(bar, Paint()..color = accentColor);
    canvas.restore();
  }

  /// The label: outlined letters, barely lighter than the dial — it is part
  /// of the instrument, not of the reading.
  void _label(Canvas canvas, _NeonDial d, VuFaceContext context) {
    final label = context.label;
    if (label == null || label.isEmpty) return;
    TextPainter make(Paint foreground) => TextPainter(
          text: TextSpan(
            text: label.toUpperCase(),
            style: TextStyle(
              fontFamily: context.fontFamily,
              fontSize: 150,
              fontWeight: FontWeight.w700,
              letterSpacing: 14,
              height: 1,
              foreground: foreground,
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();

    final outline = make(
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = labelColor,
    );
    final fill = make(
      Paint()..color = Color.lerp(background, labelColor, 0.25)!,
    );
    // Never wider than the space between the ends of the scale.
    const room = 1650.0;
    final scale = outline.width > room ? room / outline.width : 1.0;
    canvas
      ..save()
      ..translate(_pivot.dx, d.labelY)
      ..scale(scale);
    final at = Offset(-outline.width / 2, -outline.height / 2);
    fill.paint(canvas, at);
    outline.paint(canvas, at);
    canvas.restore();
  }

  static const Offset _lamp = Offset(2190.17, 1071.9);
  static const double _lampRadius = 80.09;

  @override
  Rect lampArea(double aspectRatio) {
    final d = _NeonDial.shaped(aspectRatio);
    final lamp = d.place(_lamp);
    return Rect.fromLTWH(
      (lamp.dx - 190) / _width,
      (lamp.dy - 100) / d.h,
      380 / _width,
      330 / d.h,
    );
  }

  @override
  void paintLamp(Canvas canvas, Size size, VuFaceContext context, bool lit) {
    final d = _NeonDial(size);
    final lamp = d.place(_lamp);
    canvas.save();
    d.fit(canvas, size);
    final red = hotEnd;
    final halo = _halo(36);
    if (lit && halo != null) {
      canvas.drawCircle(
        lamp,
        _lampRadius * 1.15,
        Paint()
          ..color = red.withValues(alpha: 0.75)
          ..maskFilter = halo,
      );
    }
    canvas.drawCircle(
      lamp,
      _lampRadius,
      Paint()
        ..shader = ui.Gradient.radial(
          lamp - const Offset(24, 28),
          _lampRadius * 1.5,
          lit
              ? [
                  Color.lerp(red, const Color(0xFFFFFFFF), 0.55)!,
                  red,
                  Color.lerp(red, const Color(0xFF000000), 0.35)!,
                ]
              // Off, the lamp is dark glass with a hint of its colour.
              : [
                  Color.lerp(red, background, 0.55)!,
                  Color.lerp(red, background, 0.8)!,
                  Color.lerp(red, const Color(0xFF000000), 0.85)!,
                ],
          [0, 0.35, 1],
        ),
    );

    final text = TextPainter(
      text: TextSpan(
        text: context.clipLabel,
        style: TextStyle(
          fontFamily: context.fontFamily,
          fontSize: 112,
          fontWeight: FontWeight.w700,
          letterSpacing: 6,
          height: 1,
          color: lit ? red : Color.lerp(red, background, 0.6),
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    // The caption must stay on the dial, however long it is.
    const room = 380.0;
    final scale = text.width > room ? room / text.width : 1.0;
    canvas
      ..translate(lamp.dx, lamp.dy + 156.1)
      ..scale(scale);
    text.paint(canvas, Offset(-text.width / 2, -text.height / 2));
    canvas.restore();
  }

  @override
  void paintNeedle(
    Canvas canvas,
    Size size,
    VuFaceContext context,
    double position,
  ) {
    final d = _NeonDial(size);
    final pivot = d.pivot;
    canvas.save();
    d.fit(canvas, size);
    final tip = d.polar(d.angle(position), 1130.8);
    final halo = _halo(16);
    if (halo != null) {
      canvas.drawLine(
        pivot,
        tip,
        Paint()
          ..strokeWidth = 26
          ..strokeCap = StrokeCap.round
          ..color = accentColor.withValues(alpha: 0.55)
          ..maskFilter = halo,
      );
    }
    canvas.drawLine(
      pivot,
      tip,
      Paint()
        ..strokeWidth = 17
        ..strokeCap = StrokeCap.round
        ..color = needle,
    );

    // The dome: the upper half of a disc, lit from its middle.
    final centre = pivot + const Offset(0, 14);
    const radius = 141.34;
    final dome = Path()
      ..moveTo(centre.dx - radius, centre.dy)
      ..arcToPoint(
        Offset(centre.dx + radius, centre.dy),
        radius: const Radius.circular(radius),
      )
      ..close();
    final soft = _halo(22);
    if (soft != null) {
      canvas.drawPath(
        dome,
        Paint()
          ..color = accentColor.withValues(alpha: 0.5)
          ..maskFilter = soft,
      );
    }
    canvas.drawPath(
      dome,
      Paint()
        ..shader = ui.Gradient.radial(
          pivot + const Offset(0.5, -7.81),
          254.4,
          [
            Color.lerp(accentColor, const Color(0xFFFFFFFF), 0.72)!,
            accentColor,
            Color.lerp(accentColor, const Color(0xFF000000), 0.45)!,
          ],
          [0, 0.45, 1],
        ),
    );
    canvas.restore();
  }

  @override
  bool operator ==(Object other) =>
      other is NeonVuFace &&
      other.background == background &&
      other.coolStart == coolStart &&
      other.coolEnd == coolEnd &&
      other.hotStart == hotStart &&
      other.hotMiddle == hotMiddle &&
      other.hotEnd == hotEnd &&
      other.accentColor == accentColor &&
      other.needle == needle &&
      other.labelColor == labelColor &&
      other.glow == glow;

  @override
  int get hashCode => Object.hash(
        background,
        coolStart,
        coolEnd,
        hotStart,
        hotMiddle,
        hotEnd,
        accentColor,
        needle,
        labelColor,
        glow,
      );
}

/// The measures of the dial for one shape, in the artwork's units.
///
/// The artwork fixes every part by its distance and angle from the pivot.
/// For another shape all distances grow by [grow] and all angles shrink by
/// [squeeze]: the scale keeps its width and its thickness, only its curve
/// flattens.
class _NeonDial {
  _NeonDial(Size size) : this.shaped(vuRatioOf(size));

  _NeonDial.shaped(double ratio)
      : h = NeonVuFace._width / ratio,
        grow = vuShaped(ratio, 0, 0, 598),
        _margin = vuShaped(ratio, 670.77, 391.11, 60),
        labelY = vuShaped(ratio, 1796.66, 1517, 1060);

  /// The height of the box.
  final double h;

  /// How much longer every radius is than in the artwork.
  final double grow;

  /// The room above the numbers.
  final double _margin;

  /// The middle of the label.
  final double labelY;

  late final Offset pivot = Offset(
    NeonVuFace._pivot.dx,
    _margin + 1391 + grow,
  );

  /// By how much every angle shrinks, so that the scale stays as wide.
  late final double squeeze = math.asin(
        980 * math.sin(-NeonVuFace._startAngle * math.pi / 180) / (980 + grow),
      ) *
      180 /
      math.pi /
      -NeonVuFace._startAngle;

  late final double start = NeonVuFace._startAngle * squeeze;
  late final double end = NeonVuFace._endAngle * squeeze;

  double angle(double position) => start + position * (end - start);

  /// A point at [degrees] of this dial and at a [radius] of the artwork.
  Offset polar(double degrees, double radius) {
    final a = degrees * math.pi / 180;
    return pivot + Offset(math.sin(a), -math.cos(a)) * (radius + grow);
  }

  /// Where a point of the artwork lies on this dial.
  Offset place(Offset artwork) {
    final v = artwork - NeonVuFace._pivot;
    return polar(
      math.atan2(v.dx, -v.dy) * 180 / math.pi * squeeze,
      v.distance,
    );
  }

  /// One scale for both directions: nothing is stretched.
  void fit(Canvas canvas, Size size) =>
      canvas.scale(size.width / NeonVuFace._width);
}
