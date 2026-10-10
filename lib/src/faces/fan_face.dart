import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../vu_face.dart';
import 'shape.dart';

/// A fan of rays: every division is a beam from the pivot towards the top
/// edge — long ones at the numbered levels, short ones between — with the
/// numbers in a row along the top and a red needle sweeping across.
class FanVuFace extends VuFace {
  const FanVuFace({
    this.backgroundTop = const Color(0xFF0B1730),
    this.backgroundBottom = const Color(0xFF1F4A93),
    this.ray = const Color(0xFF3FA9F5),
    this.hotColor = const Color(0xFFFF5A4D),
    this.text = const Color(0xFFF4F8FF),
    this.needle = const Color(0xFFE53935),
    this.knob = const Color(0xFF4F7DDB),
  });

  /// The dial, from its upper left to its lower right.
  final Color backgroundTop;
  final Color backgroundBottom;

  /// The rays below the hot zone.
  final Color ray;

  /// The rays of the hot zone and the clip lamp.
  final Color hotColor;

  /// Numbers and words.
  final Color text;

  final Color needle;

  /// The knob over the pivot.
  final Color knob;

  @override
  String get name => 'fan';

  @override
  Color get accent => ray;

  @override
  Color get hot => hotColor;

  // Drawn in a box 1000 wide; the height follows from the shape.
  static const double _w = 1000;

  void _text(
    Canvas canvas,
    VuFaceContext context,
    String value,
    Offset at,
    double size,
    Color color, {
    bool centred = true,
    double? maxWidth,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontFamily: context.fontFamily,
          fontSize: size,
          fontWeight: FontWeight.w700,
          height: 1,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final scale = maxWidth != null && painter.width > maxWidth
        ? maxWidth / painter.width
        : 1.0;
    canvas
      ..save()
      ..translate(at.dx, at.dy)
      ..scale(scale);
    painter.paint(
      canvas,
      Offset(centred ? -painter.width / 2 : 0, -painter.height / 2),
    );
    canvas.restore();
  }

  @override
  void paintFace(Canvas canvas, Size size, VuFaceContext context) {
    final scale = context.scale;
    final hotAt = scale.hotPosition;
    final d = _FanDial(size);
    canvas.save();
    d.fit(canvas, size);
    final box = Rect.fromLTWH(0, 0, _w, d.h);
    canvas
      ..drawRect(
        box,
        Paint()
          ..shader = ui.Gradient.linear(Offset.zero, Offset(_w, d.h), [
            backgroundTop,
            backgroundBottom,
          ]),
      )
      // A band of light across the glass.
      ..drawPath(
        Path()
          ..moveTo(_w * 0.42, 0)
          ..lineTo(_w * 0.78, 0)
          ..lineTo(_w * 0.36, d.h)
          ..lineTo(0, d.h)
          ..close(),
        Paint()..color = const Color(0x12FFFFFF),
      );

    for (final (db, position) in scale.marks) {
      final major = scale.majorDb.contains(db);
      final angle = d.angle(position);
      final reach = d.reach(angle);
      final from = d.from(angle);
      final colour = position >= hotAt - 1e-9 ? hotColor : ray;
      final a = d.polar(angle, major ? from : from + 34);
      final b = d.polar(
        angle,
        major ? reach - 8 : from + 34 + (reach - from) * 0.42,
      );
      final width = major ? 9.5 : 6.0;
      canvas
        ..drawLine(
          a,
          b,
          Paint()
            ..strokeWidth = width
            ..strokeCap = StrokeCap.round
            ..color = colour.withValues(alpha: 0.5)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 0.7),
        )
        ..drawLine(
          a,
          b,
          Paint()
            ..strokeWidth = width
            ..strokeCap = StrokeCap.round
            ..color = colour,
        );
    }
    // The numbers, in a row above the rays.
    for (final db in scale.majorDb) {
      final position = scale.positionFor(db);
      final angle = d.angle(position);
      _text(
        canvas,
        context,
        scale.labelFor(db),
        Offset(d.polar(angle, d.reach(angle)).dx, d.top - 44),
        42,
        position > hotAt + 1e-9 ? hotColor : text,
      );
    }
    // The percent scale: a row of small numbers under the rays.
    if (context.showPercentScale) {
      for (final percent in scale.majorPercent) {
        final angle = d.angle(scale.positionForPercent(percent.toDouble()));
        _text(
          canvas,
          context,
          percent == 100 ? '100%' : '$percent',
          d.polar(angle, d.from(angle) - 44),
          24,
          text.withValues(alpha: 0.8),
        );
      }
    }

    // Unit and label, lower left.
    final label = context.label;
    if (label != null && label.isNotEmpty) {
      _text(
        canvas,
        context,
        label,
        Offset(56, d.h - 116),
        30,
        text.withValues(alpha: 0.85),
        centred: false,
        maxWidth: 300,
      );
    }
    _text(
      canvas,
      context,
      scale.unit,
      Offset(56, d.h - 67),
      36,
      text,
      centred: false,
    );
    canvas.restore();
  }

  static const double _lampRadius = 22;

  @override
  Rect lampArea(double aspectRatio) =>
      Rect.fromLTRB(0.85, 1 - 160 / (_w / aspectRatio), 0.99, 1);

  @override
  void paintLamp(Canvas canvas, Size size, VuFaceContext context, bool lit) {
    final d = _FanDial(size);
    final lamp = Offset(928, d.h - 119);
    canvas.save();
    d.fit(canvas, size);
    if (lit) {
      canvas.drawCircle(
        lamp,
        _lampRadius * 1.3,
        Paint()
          ..color = hotColor.withValues(alpha: 0.75)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }
    canvas.drawCircle(
      lamp,
      _lampRadius,
      Paint()
        ..shader = ui.Gradient.radial(
          lamp - const Offset(6, 7),
          _lampRadius * 1.5,
          lit
              ? [
                  Color.lerp(hotColor, const Color(0xFFFFFFFF), 0.55)!,
                  hotColor,
                  Color.lerp(hotColor, const Color(0xFF000000), 0.35)!,
                ]
              : [
                  Color.lerp(hotColor, backgroundTop, 0.6)!,
                  Color.lerp(hotColor, backgroundTop, 0.82)!,
                  Color.lerp(hotColor, const Color(0xFF000000), 0.85)!,
                ],
          [0, 0.4, 1],
        ),
    );
    _text(
      canvas,
      context,
      context.clipLabel,
      Offset(928, d.h - 67),
      26,
      lit ? hotColor : text.withValues(alpha: 0.5),
      maxWidth: 130,
    );
    canvas.restore();
  }

  @override
  void paintNeedle(
    Canvas canvas,
    Size size,
    VuFaceContext context,
    double position,
  ) {
    final d = _FanDial(size);
    final pivot = d.pivot;
    canvas.save();
    d.fit(canvas, size);
    canvas.clipRect(Rect.fromLTWH(0, 0, _w, d.h));
    final angle = d.angle(position);
    final tip = d.polar(angle, d.reach(angle) - 34);
    canvas
      ..drawLine(
        pivot + const Offset(4, 5),
        tip + const Offset(4, 5),
        Paint()
          ..strokeWidth = 8
          ..color = const Color(0x40000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      )
      ..drawLine(
        pivot,
        tip,
        Paint()
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..color = needle,
      );
    // The knob over the pivot — unless the pivot lies below the window, as
    // it does on a wide dial.
    if (pivot.dy < d.h + 36) {
      canvas.drawCircle(
        pivot,
        36,
        Paint()
          ..shader = ui.Gradient.radial(pivot - const Offset(10, 12), 54, [
            Color.lerp(knob, const Color(0xFFFFFFFF), 0.55)!,
            knob,
            Color.lerp(knob, const Color(0xFF000000), 0.6)!,
          ], [
            0,
            0.45,
            1
          ]),
      );
    }
    canvas.restore();
  }

  @override
  bool operator ==(Object other) =>
      other is FanVuFace &&
      other.backgroundTop == backgroundTop &&
      other.backgroundBottom == backgroundBottom &&
      other.ray == ray &&
      other.hotColor == hotColor &&
      other.text == text &&
      other.needle == needle &&
      other.knob == knob;

  @override
  int get hashCode => Object.hash(
        backgroundTop,
        backgroundBottom,
        ray,
        hotColor,
        text,
        needle,
        knob,
      );
}

/// The measures of the dial for one shape, in a box [FanVuFace._w] wide.
class _FanDial {
  _FanDial(Size size) : this.shaped(vuRatioOf(size));

  _FanDial.shaped(double ratio)
      : h = FanVuFace._w / ratio,
        top = vuShaped(ratio, 152, 152, 110),
        _depth = vuShaped(ratio, 738, 590, 998.6),
        _from = vuShaped(ratio, 400, 318, 818.6),
        _flat = vuShaped(ratio, 0, 0, 1);

  /// Half the width of the fan where it meets the top line. It stays; the
  /// sweep follows from how deep the pivot lies.
  static const double _halfWidth = 444.6;

  /// The height of the box.
  final double h;

  /// The rays end on this line.
  final double top;

  /// How far the pivot lies below the top line.
  final double _depth;

  /// Where the upright ray begins, as a distance from the pivot.
  final double _from;

  /// 0: the rays begin on a circle around the pivot. 1: on a level line —
  /// on a wide dial a circle would dip into the corners.
  final double _flat;

  late final Offset pivot = Offset(500, top + _depth);
  late final double sweep = math.atan(_halfWidth / _depth) * 180 / math.pi;

  double angle(double position) => -sweep + position * 2 * sweep;

  Offset polar(double degrees, double radius) {
    final a = degrees * math.pi / 180;
    return pivot + Offset(math.sin(a), -math.cos(a)) * radius;
  }

  /// How far a ray at [degrees] runs until it meets the top line.
  double reach(double degrees) => _depth / math.cos(degrees * math.pi / 180);

  /// Where a ray at [degrees] begins.
  double from(double degrees) =>
      _from / math.pow(math.cos(degrees * math.pi / 180), _flat);

  /// One scale for both directions: nothing is stretched.
  void fit(Canvas canvas, Size size) => canvas.scale(size.width / FanVuFace._w);
}
