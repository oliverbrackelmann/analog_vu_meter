import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'vu_face.dart';
import 'vu_scale.dart';

/// An analog needle meter.
///
/// Give it a level in dB on its [scale]:
///
/// ```dart
/// VuMeter(db: -3)
/// ```
///
/// Choose the look with [face] and the divisions with [scale]; every face
/// works with every scale. For a digital signal use [VuScale.digital] — the
/// dial then ends at 0 dBFS:
///
/// ```dart
/// VuMeter(
///   face: VuFace.classic,
///   scale: VuScale.digital,
///   db: VuScale.dbFromAmplitude(peak),
///   clip: peak >= 1,
/// )
/// ```
///
/// The widget keeps its [aspectRatio] and takes the width it is given. Any
/// shape from 1 : 1 to 2 : 1 works: the face is laid out for it, not
/// stretched — a wide meter gets a flat arc and a pivot below the window, as
/// on a panel meter. The dial is painted once; only the needle repaints when
/// the level changes. Wrap it in a `VuMeterBezel` for a frame.
class VuMeter extends StatefulWidget {
  const VuMeter({
    super.key,
    required this.db,
    this.clip = false,
    this.onClipTap,
    this.face = VuFace.neon,
    this.scale = VuScale.analog,
    this.label,
    this.clipLabel = 'CLIP',
    this.showPercentScale = true,
    this.showSigns = true,
    this.showClipLamp = true,
    this.response = const Duration(milliseconds: 300),
    this.fontFamily,
    this.borderRadius = 0,
    this.aspectRatio = VuFace.aspectRatio,
  }) : assert(
          aspectRatio >= VuFace.minAspectRatio &&
              aspectRatio <= VuFace.maxAspectRatio,
          'aspectRatio must lie between 1 and 2',
        );

  /// The level on the dial's [scale]. `double.negativeInfinity` is silence.
  final double db;

  /// Lights the clip lamp.
  final bool clip;

  /// Called when the clip lamp is tapped — typically to reset a latch.
  final VoidCallback? onClipTap;

  /// The look: dial, needle and lamp. See [VuFace] for the ready-made ones.
  final VuFace face;

  /// The divisions: [VuScale.analog], [VuScale.digital] or your own.
  final VuScale scale;

  /// A word on the dial — a channel name or a brand.
  final String? label;

  /// The text at the clip lamp.
  final String clipLabel;

  /// The percent scale, where the face has one.
  final bool showPercentScale;

  /// The minus and the plus at the two ends of the scale, where the face
  /// has them. They are decoration from the classic VU meter; turn them off
  /// where they would mislead — on a dBFS scale nothing is "plus".
  final bool showSigns;

  /// The clip lamp. Without it [clip] and [onClipTap] have no effect.
  final bool showClipLamp;

  /// How long the needle takes to (almost) reach a new level.
  ///
  /// A classic VU meter needs about 300 ms. [Duration.zero] makes the needle
  /// jump — use that if you already smooth the level yourself.
  final Duration response;

  /// The typeface of all numbers and texts; `null` uses the default.
  final String? fontFamily;

  /// Rounds the corners of the dial, in logical pixels.
  final double borderRadius;

  /// Width divided by height, from [VuFace.minAspectRatio] (1 : 1) to
  /// [VuFace.maxAspectRatio] (2 : 1). The default is the shape the faces
  /// were drawn for, [VuFace.aspectRatio].
  final double aspectRatio;

  @override
  State<VuMeter> createState() => _VuMeterState();
}

class _VuMeterState extends State<VuMeter> with SingleTickerProviderStateMixin {
  late final ValueNotifier<double> _position = ValueNotifier(_target);
  late final Ticker _ticker = createTicker(_onTick);
  Duration _last = Duration.zero;

  double get _target => widget.scale.positionFor(widget.db);

  @override
  void didUpdateWidget(VuMeter old) {
    super.didUpdateWidget(old);
    if (widget.response <= Duration.zero) {
      _ticker.stop();
      _position.value = _target;
    } else if (_position.value != _target && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt <= 0) return;
    // First-order lag that covers 99 % of a step within [VuMeter.response].
    final tau = widget.response.inMicroseconds / 1e6 / 4.6;
    final target = _target;
    final next = target + (_position.value - target) * math.exp(-dt / tau);
    if ((next - target).abs() < 0.0002) {
      _position.value = target;
      _ticker.stop();
    } else {
      _position.value = next;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _position.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final face = widget.face;
    final onClipTap = widget.onClipTap;
    final faceContext = VuFaceContext(
      scale: widget.scale,
      label: widget.label,
      clipLabel: widget.clipLabel,
      fontFamily: widget.fontFamily,
      showPercentScale: widget.showPercentScale,
      showSigns: widget.showSigns,
    );
    final ratio = widget.aspectRatio.clamp(
      VuFace.minAspectRatio,
      VuFace.maxAspectRatio,
    );
    final lamp = face.lampArea(ratio);
    return Semantics(
      label: widget.label,
      value: widget.db.isFinite
          ? '${widget.db.toStringAsFixed(1)} ${widget.scale.unit}'
          : '-∞ ${widget.scale.unit}',
      child: AspectRatio(
        aspectRatio: ratio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                child: CustomPaint(
                  painter: _FacePainter(face: face, context: faceContext),
                ),
              ),
              if (widget.showClipLamp)
                RepaintBoundary(
                  child: CustomPaint(
                    painter: _LampPainter(
                      face: face,
                      context: faceContext,
                      lit: widget.clip,
                    ),
                  ),
                ),
              RepaintBoundary(
                child: CustomPaint(
                  painter: _NeedlePainter(
                    face: face,
                    context: faceContext,
                    position: _position,
                  ),
                ),
              ),
              if (onClipTap != null && widget.showClipLamp)
                // The lamp and its caption, as a tap target.
                Align(
                  alignment: Alignment(
                    lamp.width >= 1 ? 0 : lamp.left / (1 - lamp.width) * 2 - 1,
                    lamp.height >= 1 ? 0 : lamp.top / (1 - lamp.height) * 2 - 1,
                  ),
                  child: FractionallySizedBox(
                    widthFactor: lamp.width,
                    heightFactor: lamp.height,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onClipTap,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FacePainter extends CustomPainter {
  _FacePainter({required this.face, required this.context});

  final VuFace face;
  final VuFaceContext context;

  @override
  void paint(Canvas canvas, Size size) => face.paintFace(canvas, size, context);

  @override
  bool shouldRepaint(_FacePainter old) =>
      old.face != face || old.context != context;
}

class _LampPainter extends CustomPainter {
  _LampPainter({required this.face, required this.context, required this.lit});

  final VuFace face;
  final VuFaceContext context;
  final bool lit;

  @override
  void paint(Canvas canvas, Size size) =>
      face.paintLamp(canvas, size, context, lit);

  @override
  bool shouldRepaint(_LampPainter old) =>
      old.lit != lit || old.face != face || old.context != context;
}

/// The only part that moves.
class _NeedlePainter extends CustomPainter {
  _NeedlePainter({
    required this.face,
    required this.context,
    required this.position,
  }) : super(repaint: position);

  final VuFace face;
  final VuFaceContext context;
  final ValueListenable<double> position;

  @override
  void paint(Canvas canvas, Size size) =>
      face.paintNeedle(canvas, size, context, position.value);

  @override
  bool shouldRepaint(_NeedlePainter old) =>
      old.face != face || old.context != context || old.position != position;
}
