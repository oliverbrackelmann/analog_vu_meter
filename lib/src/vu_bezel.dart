import 'package:flutter/widgets.dart';

import 'vu_face.dart';
import 'vu_meter.dart';

/// The material of a [VuMeterBezel].
///
/// Four come ready-made — [brushed], [silver], [black] and [acrylic] — and
/// each can be changed with the constructor.
class VuBezelStyle {
  const VuBezelStyle({
    required this.name,
    required this.body,
    this.bodyStops = const [0, 0.06, 0.5, 0.86, 1],
    this.captionColor = const Color(0xFFC9CDD2),
    this.edge = const Color(0xFF0B0C0D),
    this.recess = const Color(0xFF08090A),
    this.streaks = false,
    this.clear = false,
  });

  /// Dark brushed aluminium, the front of a power amplifier.
  static const VuBezelStyle brushed = VuBezelStyle(
    name: 'brushed',
    body: [
      Color(0xFF9A9DA2),
      Color(0xFF5C5F64),
      Color(0xFF2E3034),
      Color(0xFF1A1B1E),
      Color(0xFF2A2C30),
    ],
    streaks: true,
  );

  /// Bright satin aluminium.
  static const VuBezelStyle silver = VuBezelStyle(
    name: 'silver',
    body: [
      Color(0xFFFFFFFF),
      Color(0xFFE2E4E7),
      Color(0xFFC4C7CC),
      Color(0xFFA6AAB0),
      Color(0xFFC9CCD1),
    ],
    captionColor: Color(0xFF2A2C30),
    edge: Color(0xFF6F7379),
    recess: Color(0xFF3A3C40),
    streaks: true,
  );

  /// Black lacquer with a soft sheen.
  static const VuBezelStyle black = VuBezelStyle(
    name: 'black',
    body: [
      Color(0xFF4A4B4E),
      Color(0xFF1C1D1F),
      Color(0xFF0C0C0D),
      Color(0xFF050505),
      Color(0xFF141415),
    ],
    captionColor: Color(0xFFD8DADD),
    edge: Color(0xFF000000),
    recess: Color(0xFF000000),
  );

  /// A clear moulded case, as on a panel meter: the surface behind shows
  /// through, two screws hold the lower lip.
  static const VuBezelStyle acrylic = VuBezelStyle(
    name: 'acrylic',
    body: [
      Color(0x55FFFFFF),
      Color(0x26FFFFFF),
      Color(0x14FFFFFF),
      Color(0x1FFFFFFF),
      Color(0x3DFFFFFF),
    ],
    captionColor: Color(0xFFE9ECEF),
    edge: Color(0x80FFFFFF),
    recess: Color(0x66000000),
    clear: true,
  );

  /// The ready-made styles, in a fixed order — handy for a picker.
  static const List<VuBezelStyle> values = [brushed, silver, black, acrylic];

  /// A short name, e.g. for a picker.
  final String name;

  /// The body from top to bottom: five colours, lit from above.
  final List<Color> body;
  final List<double> bodyStops;

  /// The caption on the strip below the window.
  final Color captionColor;

  /// The outline of the body.
  final Color edge;

  /// The shadow gap between frame and window.
  final Color recess;

  /// Faint horizontal streaks, as on brushed metal.
  final bool streaks;

  /// A see-through body with screws instead of an opaque one.
  final bool clear;

  @override
  bool operator ==(Object other) =>
      other is VuBezelStyle &&
      other.name == name &&
      _same(other.body, body) &&
      _sameStops(other.bodyStops, bodyStops) &&
      other.captionColor == captionColor &&
      other.edge == edge &&
      other.recess == recess &&
      other.streaks == streaks &&
      other.clear == clear;

  static bool _same(List<Color> a, List<Color> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _sameStops(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        name,
        Object.hashAll(body),
        Object.hashAll(bodyStops),
        captionColor,
        edge,
        recess,
        streaks,
        clear,
      );
}

/// A frame around a [VuMeter], with a caption below the window — the way a
/// panel meter sits in the front of an amplifier.
///
/// ```dart
/// VuMeterBezel(
///   style: VuBezelStyle.silver,
///   caption: 'LEFT',
///   child: VuMeter(db: level, face: VuFace.classic),
/// )
/// ```
///
/// Every frame fits every face and every shape: the window takes the aspect
/// ratio of the meter in it. The frame takes the width it is given; its own
/// shape follows from the window ([aspectRatioFor]).
///
/// On a wide meter the pivot of the needle lies below the window — the frame
/// hides it, as the case of a panel meter does.
class VuMeterBezel extends StatelessWidget {
  const VuMeterBezel({
    super.key,
    required this.child,
    this.style = VuBezelStyle.brushed,
    this.caption,
    this.fontFamily,
    this.windowAspectRatio,
  });

  /// The meter — or anything else that fills the window.
  final Widget child;

  /// Width divided by height of the window. Leave it out for a [VuMeter]:
  /// the window then takes the meter's own aspect ratio.
  final double? windowAspectRatio;

  final VuBezelStyle style;

  /// The word on the strip below the window — typically the channel.
  final String? caption;

  final String? fontFamily;

  // All measures as a fraction of the frame's width.
  static const double _side = 0.045;
  static const double _strip = 0.125;

  /// Width divided by height of a frame around a meter of the default shape.
  static const double aspectRatio =
      1 / (_side + (1 - 2 * _side) / VuFace.aspectRatio + _strip);

  /// Width divided by height of a frame whose window has
  /// [windowAspectRatio] — for a framed `VuMeter(aspectRatio: 2)` that is
  /// `aspectRatioFor(2)`.
  static double aspectRatioFor(double windowAspectRatio) =>
      1 / (_side + (1 - 2 * _side) / windowAspectRatio + _strip);

  @override
  Widget build(BuildContext context) {
    final child = this.child;
    final window = windowAspectRatio ??
        (child is VuMeter ? child.aspectRatio : VuFace.aspectRatio);
    return AspectRatio(
      aspectRatio: aspectRatioFor(window),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final side = width * _side;
          final caption = this.caption;
          return CustomPaint(
            painter: _BezelPainter(style, window),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(side, side, side, 0),
                  child: AspectRatio(aspectRatio: window, child: child),
                ),
                Expanded(
                  child: Center(
                    child: caption == null || caption.isEmpty
                        ? null
                        : Padding(
                            // On a clear case the screws sit at the ends.
                            padding: EdgeInsets.symmetric(
                              horizontal: style.clear ? side * 2.6 : side,
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                caption.toUpperCase(),
                                maxLines: 1,
                                style: TextStyle(
                                  fontFamily: fontFamily,
                                  fontSize: width * 0.052,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: width * 0.012,
                                  height: 1,
                                  color: style.captionColor,
                                  // Engraved: a dark edge above, a light
                                  // one below.
                                  shadows: [
                                    Shadow(
                                      color: const Color(0x99000000),
                                      offset: Offset(0, -width * 0.002),
                                    ),
                                    Shadow(
                                      color: const Color(0x33FFFFFF),
                                      offset: Offset(0, width * 0.002),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The frame: a body lit from above, a bevel around the edge and a recess
/// in which the window sits.
class _BezelPainter extends CustomPainter {
  const _BezelPainter(this.style, this.windowAspectRatio);

  final VuBezelStyle style;
  final double windowAspectRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final outer = Offset.zero & size;
    final radius = Radius.circular(w * (style.clear ? 0.02 : 0.012));
    final body = RRect.fromRectAndRadius(outer, radius);

    canvas.drawRRect(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: style.body,
          stops: style.bodyStops,
        ).createShader(outer),
    );
    if (style.streaks) {
      final streak = Paint()..strokeWidth = 1;
      for (var y = 1.5; y < size.height; y += 3) {
        streak.color =
            (y ~/ 3).isEven ? const Color(0x0AFFFFFF) : const Color(0x0F000000);
        canvas.drawLine(Offset(w * 0.006, y), Offset(w * 0.994, y), streak);
      }
    }
    // The bevel: light along the top and left, dark along the bottom.
    canvas
      ..drawRRect(
        body.deflate(w * 0.003),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.004
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0x99FFFFFF), Color(0x11FFFFFF), Color(0x99000000)],
            stops: [0, 0.45, 1],
          ).createShader(outer),
      )
      ..drawRRect(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = style.edge,
      );

    // The recess around the window.
    final side = w * VuMeterBezel._side;
    final window = Rect.fromLTWH(
      side,
      side,
      w - 2 * side,
      (w - 2 * side) / windowAspectRatio,
    );
    final recess = window.inflate(w * 0.008);
    canvas
      ..drawRect(recess, Paint()..color = style.recess)
      ..drawRect(
        recess,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.004
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xCC000000), Color(0x22000000), Color(0x66FFFFFF)],
            stops: [0, 0.5, 1],
          ).createShader(recess),
      );

    if (!style.clear) return;
    // A clear case: a brighter lip under the window and a screw at each end.
    final lip = Rect.fromLTRB(
      w * 0.012,
      window.bottom + w * 0.012,
      w * 0.988,
      size.height - w * 0.012,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(lip, Radius.circular(w * 0.01)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x33FFFFFF), Color(0x0DFFFFFF), Color(0x26FFFFFF)],
        ).createShader(lip),
    );
    for (final x in [side * 1.5, w - side * 1.5]) {
      final centre = Offset(x, lip.center.dy);
      final r = w * 0.021;
      canvas
        ..drawCircle(
          centre,
          r,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.35, -0.4),
              colors: const [
                Color(0xFFF4F5F6),
                Color(0xFFA9ADB2),
                Color(0xFF55585D),
              ],
              stops: const [0, 0.55, 1],
            ).createShader(Rect.fromCircle(center: centre, radius: r)),
        )
        // The slot.
        ..drawLine(
          centre - Offset(r * 0.62, r * 0.25),
          centre + Offset(r * 0.62, r * 0.25),
          Paint()
            ..strokeWidth = r * 0.26
            ..strokeCap = StrokeCap.round
            ..color = const Color(0xFF2B2D30),
        );
    }
  }

  @override
  bool shouldRepaint(_BezelPainter old) =>
      old.style != style || old.windowAspectRatio != windowAspectRatio;
}
