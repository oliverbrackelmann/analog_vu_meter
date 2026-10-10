import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../vu_face.dart';
import 'shape.dart';

/// The traditional dial: one arc with ticks and upright numbers above it, a
/// percent arc below, a thin needle whose pivot hides behind a bump at the
/// bottom edge.
///
/// Four looks come ready-made — [ArcVuFace.classic], [ArcVuFace.backlit],
/// [ArcVuFace.studio] and [ArcVuFace.paper] — and every colour can be
/// changed.
class ArcVuFace extends VuFace {
  const ArcVuFace({
    required this.name,
    required this.faceCentre,
    required this.faceEdge,
    required this.ink,
    required this.hotColor,
    required this.needle,
    required this.pivot,
    required this.accentColor,
    this.arcWidth = 6,
    this.gloss = false,
    this.grain = 0,
  });

  /// The warm, backlit studio meter: black on amber, red above the hot mark.
  const ArcVuFace.classic({
    this.faceCentre = const Color(0xFFFFF3C4),
    this.faceEdge = const Color(0xFFF0A531),
    this.ink = const Color(0xFF2B2219),
    this.hotColor = const Color(0xFFD32A1E),
    this.needle = const Color(0xFF1C1C1C),
    this.pivot = const Color(0xFF121212),
    this.accentColor = const Color(0xFFF0A531),
    this.arcWidth = 6,
    this.gloss = true,
    this.grain = 1,
  }) : name = 'classic';

  /// A blue backlit power meter: white on blue.
  const ArcVuFace.backlit({
    this.faceCentre = const Color(0xFF3F86FF),
    this.faceEdge = const Color(0xFF0A2FA8),
    this.ink = const Color(0xFFF2F7FF),
    this.hotColor = const Color(0xFFFFC53A),
    this.needle = const Color(0xFFF2F7FF),
    this.pivot = const Color(0xFF06143F),
    this.accentColor = const Color(0xFF3F86FF),
    this.arcWidth = 6,
    this.gloss = true,
    this.grain = 0,
  }) : name = 'backlit';

  /// Mint green on black, a white needle.
  const ArcVuFace.studio({
    this.faceCentre = const Color(0xFF151718),
    this.faceEdge = const Color(0xFF050606),
    this.ink = const Color(0xFF35E3A4),
    this.hotColor = const Color(0xFFFF4D3D),
    this.needle = const Color(0xFFF4F4F4),
    this.pivot = const Color(0xFF2A2D30),
    this.accentColor = const Color(0xFF35E3A4),
    this.arcWidth = 6,
    this.gloss = false,
    this.grain = 0,
  }) : name = 'studio';

  /// Plain black on white with a bold arc and a red needle.
  const ArcVuFace.paper({
    this.faceCentre = const Color(0xFFFCFCFA),
    this.faceEdge = const Color(0xFFEFEFEB),
    this.ink = const Color(0xFF1B1B1B),
    this.hotColor = const Color(0xFFC62828),
    this.needle = const Color(0xFFC62828),
    this.pivot = const Color(0xFF1B1B1B),
    this.accentColor = const Color(0xFFE8E8E8),
    this.arcWidth = 16,
    this.gloss = false,
    this.grain = 1,
  }) : name = 'paper';

  @override
  final String name;

  /// The dial: lit from the middle ([faceCentre]) towards the rim
  /// ([faceEdge]).
  final Color faceCentre;
  final Color faceEdge;

  /// Scale, numbers and texts below the hot zone.
  final Color ink;

  /// The hot zone and the clip lamp.
  final Color hotColor;

  final Color needle;

  /// The bump that covers the pivot.
  final Color pivot;

  /// See [VuFace.accent].
  final Color accentColor;

  /// The thickness of the scale's arc.
  final double arcWidth;

  /// A reflection across the glass.
  final bool gloss;

  /// How much the dial looks printed on paper, from 0 (a clean drawing) to
  /// 1: the paper shows its tooth and a few fibres, and the ink does not
  /// cover evenly — it has pinholes, and its edges are a little ragged.
  final double grain;

  @override
  Color get accent => accentColor;

  @override
  Color get hot => hotColor;

  // Drawn in a box 1000 wide; the height follows from the shape.
  static const double _w = 1000;

  void _arc(
    Canvas canvas,
    _ArcDial d,
    double radius,
    double from,
    double to,
    double width,
    Color color,
  ) {
    if (to <= from) return;
    canvas.drawArc(
      Rect.fromCircle(center: d.pivot, radius: radius),
      (from - 90) * math.pi / 180,
      (to - from) * math.pi / 180,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = color,
    );
  }

  void _text(
    Canvas canvas,
    VuFaceContext context,
    String text,
    Offset centre,
    double size,
    Color color, {
    FontWeight weight = FontWeight.w700,
    double spacing = 0,
    double? maxWidth,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: context.fontFamily,
          fontSize: size,
          fontWeight: weight,
          letterSpacing: spacing,
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
      ..translate(centre.dx, centre.dy)
      ..scale(scale);
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();
  }

  @override
  void paintFace(Canvas canvas, Size size, VuFaceContext context) {
    final scale = context.scale;
    final hotAt = scale.hotPosition;
    final d = _ArcDial(size);
    final hotAngle = d.angle(hotAt.clamp(0.0, 1.0));
    canvas.save();
    d.fit(canvas, size);
    final box = Rect.fromLTWH(0, 0, _w, d.h);
    canvas.drawRect(
      box,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(500, d.h * 0.675),
          640 * math.max(1.0, d.h / (_w / VuFace.aspectRatio)),
          [faceCentre, faceEdge],
        ),
    );

    // The scale: one arc, the hot zone as a broad band on its outside.
    // A printed dial gets its ink on a layer of its own, so that the gaps
    // in the ink show the paper beneath, whatever its colour there.
    final printed = grain > 0;
    if (printed) canvas.saveLayer(box, Paint());

    // A tick stands with its middle on its mark, so half of it would reach
    // beyond an arc that ends on the mark. The arcs run that much further:
    // every end closes flush with the outer edge of its tick.
    double half(double db) => scale.majorDb.contains(db) ? 2.75 : 1.6;
    double pad(double width, double radius) => width / radius * 180 / math.pi;
    final first = half(scale.marks.first.$1);
    final last = half(scale.marks.last.$1);
    final hotHalf = half(scale.hotFromDb);
    // The band overlaps the arc a little, or a seam would show between them.
    final bandRadius = d.radius + arcWidth / 2 + 10;
    _arc(
      canvas,
      d,
      d.radius,
      -d.sweep - pad(first, d.radius),
      hotAt <= 1 ? hotAngle : d.sweep + pad(last, d.radius),
      arcWidth,
      ink,
    );
    if (hotAt <= 1) {
      _arc(
        canvas,
        d,
        d.radius,
        hotAngle,
        d.sweep + pad(last, d.radius),
        arcWidth,
        hotColor,
      );
      _arc(
        canvas,
        d,
        bandRadius,
        hotAngle - pad(hotHalf, bandRadius),
        d.sweep + pad(last, bandRadius),
        24,
        hotColor,
      );
    }

    final outer = d.radius + arcWidth / 2;
    for (final (db, position) in scale.marks) {
      final major = scale.majorDb.contains(db);
      final angle = d.angle(position);
      final hot = position >= hotAt - 1e-9;
      canvas.drawLine(
        d.polar(angle, outer - 1),
        d.polar(angle, outer + (major ? 36 : 21)),
        Paint()
          ..strokeWidth = major ? 5.5 : 3.2
          ..color = hot ? hotColor : ink,
      );
    }
    for (final db in scale.majorDb) {
      final position = scale.positionFor(db);
      _text(
        canvas,
        context,
        scale.labelFor(db),
        d.polar(d.angle(position), outer + 72),
        46,
        position > hotAt + 1e-9 ? hotColor : ink,
      );
    }
    if (context.showSigns) {
      // Minus and plus beyond the two ends.
      _text(canvas, context, '–', d.polar(-d.sweep - 6.5, d.radius), 44, ink);
      _text(
        canvas,
        context,
        '+',
        d.polar(d.sweep + 6.5, d.radius),
        44,
        hotAt <= 1 ? hotColor : ink,
      );
    }

    // The percent scale, below the arc.
    if (context.showPercentScale) {
      final inner = d.radius - 46;
      // Here only the 100 % tick can stand on an end.
      final full = scale.positionForPercent(100) >= 1 - 1e-9;
      _arc(
        canvas,
        d,
        inner,
        -d.sweep,
        d.sweep + (full ? pad(1.5, inner) : 0),
        2.6,
        ink.withValues(alpha: 0.85),
      );
      for (final percent in scale.majorPercent) {
        final angle = d.angle(scale.positionForPercent(percent.toDouble()));
        canvas.drawLine(
          d.polar(angle, inner + 1),
          d.polar(angle, inner - 16),
          Paint()
            ..strokeWidth = 3
            ..color = ink,
        );
        _text(
          canvas,
          context,
          percent == 100 ? '100%' : '$percent',
          d.polar(angle, inner - 38),
          25,
          ink,
          weight: FontWeight.w600,
        );
      }
      for (final percent in scale.minorPercent) {
        final angle = d.angle(scale.positionForPercent(percent.toDouble()));
        canvas.drawLine(
          d.polar(angle, inner + 1),
          d.polar(angle, inner - 9),
          Paint()
            ..strokeWidth = 2
            ..color = ink,
        );
      }
    }

    // The word in the middle: the label, or else the unit.
    final label = context.label;
    final word = label == null || label.isEmpty ? scale.unit : label;
    _text(
      canvas,
      context,
      word,
      Offset(500, d.labelY),
      label == null || label.isEmpty ? 84 : 52,
      ink,
      weight: FontWeight.w600,
      spacing: 4,
      maxWidth: 520,
    );
    if (label != null && label.isNotEmpty) {
      _text(
        canvas,
        context,
        scale.unit,
        Offset(500, d.labelY + 60),
        30,
        ink.withValues(alpha: 0.8),
        weight: FontWeight.w600,
        spacing: 2,
      );
    }

    if (printed) {
      _gaps(canvas, d.h);
      canvas.restore();
      _paper(canvas, d.h);
    }

    if (gloss) {
      // A reflection: a pale wedge from the upper left.
      canvas.drawPath(
        Path()
          ..moveTo(0, 0)
          ..lineTo(_w * 0.62, 0)
          ..lineTo(_w * 0.34, d.h)
          ..lineTo(0, d.h)
          ..close(),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset.zero,
            Offset(_w * 0.5, d.h),
            [const Color(0x30FFFFFF), const Color(0x05FFFFFF)],
          ),
      );
    }
    // The shadow of the rim on the dial.
    canvas.drawRect(
      box.deflate(4),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..color = const Color(0x30000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.restore();
  }

  static const double _lampRadius = 24;

  /// Scatters round specks over the dial, by a fixed [seed]: the same dial
  /// always carries the same grain, and it does not crawl on a repaint.
  void _specks(
    Canvas canvas,
    double h,
    math.Random random,
    int count,
    double width,
    Paint paint,
  ) {
    // As many per area in every shape.
    final area = h / (_w / VuFace.aspectRatio);
    final amount = grain.clamp(0.0, 1.0);
    final points = Float32List((count * amount * area).round() * 2);
    for (var i = 0; i < points.length; i += 2) {
      points[i] = random.nextDouble() * _w;
      points[i + 1] = random.nextDouble() * h;
    }
    canvas.drawRawPoints(
      ui.PointMode.points,
      points,
      paint
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Where the ink did not take: specks that wear the ink layer thin. In
  /// the ink they are pinholes, and where they meet an edge they fray it.
  /// See [grain].
  void _gaps(Canvas canvas, double h) {
    final random = math.Random(1883);
    Paint wear(double alpha) => Paint()
      ..blendMode = BlendMode.dstOut
      ..color = Color.fromRGBO(0, 0, 0, alpha);
    _specks(canvas, h, random, 16000, 1.3, wear(0.5));
    _specks(canvas, h, random, 7000, 2.1, wear(0.38));
    _specks(canvas, h, random, 1800, 3.3, wear(0.28));
  }

  /// The paper itself: its tooth, a few fibres and the odd fleck of ink
  /// beside a line. Needle and lamp are painted later and stay clean — they
  /// are not printed.
  void _paper(Canvas canvas, double h) {
    final random = math.Random(2443);
    final area = h / (_w / VuFace.aspectRatio);
    final amount = grain.clamp(0.0, 1.0);
    canvas
      ..save()
      ..clipRect(Rect.fromLTWH(0, 0, _w, h));
    _specks(canvas, h, random, 9000, 1.5,
        Paint()..color = ink.withValues(alpha: 0.05));
    _specks(canvas, h, random, 2500, 2.6,
        Paint()..color = ink.withValues(alpha: 0.035));
    final fibre = Paint()
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round
      ..color = ink.withValues(alpha: 0.06);
    for (var i = (260 * amount * area).round(); i > 0; i--) {
      final from = Offset(random.nextDouble() * _w, random.nextDouble() * h);
      final angle = random.nextDouble() * math.pi;
      final length = 6 + random.nextDouble() * 16;
      canvas.drawLine(
        from,
        from + Offset(math.cos(angle), math.sin(angle)) * length,
        fibre,
      );
    }
    _specks(canvas, h, random, 700, 1.2,
        Paint()..color = ink.withValues(alpha: 0.22));
    canvas.restore();
  }

  @override
  Rect lampArea(double aspectRatio) {
    final d = _ArcDial.shaped(aspectRatio);
    return Rect.fromLTRB(0.84, 0, 0.99, (d.lamp.dy + 86) / d.h);
  }

  @override
  void paintLamp(Canvas canvas, Size size, VuFaceContext context, bool lit) {
    final d = _ArcDial(size);
    final lamp = d.lamp;
    canvas.save();
    d.fit(canvas, size);
    if (lit) {
      canvas.drawCircle(
        lamp,
        _lampRadius * 1.3,
        Paint()
          ..color = hotColor.withValues(alpha: 0.7)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }
    canvas
      ..drawCircle(
        lamp,
        _lampRadius,
        Paint()
          ..shader = ui.Gradient.radial(
            lamp - const Offset(7, 8),
            _lampRadius * 1.5,
            lit
                ? [
                    Color.lerp(hotColor, const Color(0xFFFFFFFF), 0.55)!,
                    hotColor,
                    Color.lerp(hotColor, const Color(0xFF000000), 0.35)!,
                  ]
                : [
                    Color.lerp(hotColor, const Color(0xFF202020), 0.6)!,
                    Color.lerp(hotColor, const Color(0xFF101010), 0.8)!,
                    const Color(0xFF0A0A0A),
                  ],
            [0, 0.4, 1],
          ),
      )
      ..drawCircle(
        lamp,
        _lampRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0x66000000),
      );
    _text(
      canvas,
      context,
      context.clipLabel,
      lamp + const Offset(0, 46),
      24,
      lit ? hotColor : ink.withValues(alpha: 0.55),
      spacing: 1.5,
      maxWidth: 140,
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
    final d = _ArcDial(size);
    final pivot = d.pivot;
    canvas.save();
    d.fit(canvas, size);
    // Nothing of the needle shows below the dial.
    canvas.clipRect(Rect.fromLTWH(0, 0, _w, d.h));
    final angle = d.angle(position);
    final tip = d.polar(angle, d.radius + 58);
    // Its shadow on the dial, a little to the side.
    canvas
      ..drawLine(
        pivot + const Offset(5, 6),
        tip + const Offset(5, 6),
        Paint()
          ..strokeWidth = 5
          ..color = const Color(0x33000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      )
      ..drawLine(
        pivot,
        tip,
        Paint()
          ..strokeWidth = 4.5
          ..strokeCap = StrokeCap.round
          ..color = needle,
      );
    if (pivot.dy <= d.h - 20) {
      // A tall dial shows the pivot: a hub on it.
      canvas.drawCircle(pivot, 40, Paint()..color = this.pivot);
    } else if (pivot.dy <= d.h + 60) {
      // The pivot lies just below the edge: a bump covers it.
      canvas.drawOval(
        Rect.fromCenter(center: Offset(500, d.h + 2), width: 128, height: 74),
        Paint()..color = this.pivot,
      );
    }
    // On a wide dial the pivot lies far below the window; the needle simply
    // comes up over the edge, as on a panel meter.
    canvas.restore();
  }

  @override
  bool operator ==(Object other) =>
      other is ArcVuFace &&
      other.name == name &&
      other.faceCentre == faceCentre &&
      other.faceEdge == faceEdge &&
      other.ink == ink &&
      other.hotColor == hotColor &&
      other.needle == needle &&
      other.pivot == pivot &&
      other.accentColor == accentColor &&
      other.arcWidth == arcWidth &&
      other.gloss == gloss &&
      other.grain == grain;

  @override
  int get hashCode => Object.hash(
        name,
        faceCentre,
        faceEdge,
        ink,
        hotColor,
        needle,
        pivot,
        accentColor,
        arcWidth,
        gloss,
        grain,
      );
}

/// The measures of the dial for one shape, in a box [ArcVuFace._w] wide.
class _ArcDial {
  _ArcDial(Size size) : this.shaped(vuRatioOf(size));

  _ArcDial.shaped(double ratio)
      : h = ArcVuFace._w / ratio,
        sweep = vuShaped(ratio, 40, 46, 27),
        _top = vuShaped(ratio, 310, 272, 160),
        labelY = ArcVuFace._w / ratio - vuShaped(ratio, 340, 175, 120),
        lamp = Offset(918, vuShaped(ratio, 82, 82, 62));

  /// Half the width of the scale's arc. It stays; radius and sweep follow.
  static const double _chord = 374.0567;

  /// The height of the box.
  final double h;

  /// Half the sweep of the scale, in degrees.
  final double sweep;

  /// Where the arc touches its highest point.
  final double _top;

  /// The middle of the word on the dial.
  final double labelY;

  final Offset lamp;

  late final double radius = _chord / math.sin(sweep * math.pi / 180);
  late final Offset pivot = Offset(500, _top + radius);

  double angle(double position) => -sweep + position * 2 * sweep;

  Offset polar(double degrees, double radius) {
    final a = degrees * math.pi / 180;
    return pivot + Offset(math.sin(a), -math.cos(a)) * radius;
  }

  /// One scale for both directions: nothing is stretched.
  void fit(Canvas canvas, Size size) => canvas.scale(size.width / ArcVuFace._w);
}
