import 'dart:ui';

import 'package:flutter/painting.dart';

import 'faces/arc_face.dart';
import 'faces/fan_face.dart';
import 'faces/neon_face.dart';
import 'vu_scale.dart';

/// What a face needs to know to draw itself.
class VuFaceContext {
  const VuFaceContext({
    required this.scale,
    this.label,
    this.clipLabel = 'CLIP',
    this.fontFamily,
    this.showPercentScale = true,
    this.showSigns = true,
  });

  final VuScale scale;

  /// A word on the face — a channel name or a brand.
  final String? label;

  /// The text at the clip lamp.
  final String clipLabel;

  /// The typeface of all numbers and texts; `null` uses the default.
  final String? fontFamily;

  /// Whether the face shows its percent scale, if it has one.
  final bool showPercentScale;

  /// Whether the face shows the minus and the plus at the two ends of its
  /// scale, if it has them.
  final bool showSigns;

  @override
  bool operator ==(Object other) =>
      other is VuFaceContext &&
      other.scale == scale &&
      other.label == label &&
      other.clipLabel == clipLabel &&
      other.fontFamily == fontFamily &&
      other.showPercentScale == showPercentScale &&
      other.showSigns == showSigns;

  @override
  int get hashCode => Object.hash(
        scale,
        label,
        clipLabel,
        fontFamily,
        showPercentScale,
        showSigns,
      );
}

/// The look of a meter: its dial, its needle and its clip lamp.
///
/// Pick one of the ready-made faces —
///
/// * [VuFace.neon] — a dark dial with a glowing blue scale and needle
/// * [VuFace.classic] — the warm, backlit studio VU meter
/// * [VuFace.backlit] — a blue backlit power meter
/// * [VuFace.studio] — mint green on black
/// * [VuFace.fan] — a fan of blue rays with a red needle
/// * [VuFace.paper] — plain black on white
///
/// — or change the colours of one ([NeonVuFace], [ArcVuFace], [FanVuFace]
/// take them as arguments), or extend this class and paint your own.
///
/// Every face draws into any shape from [minAspectRatio] to
/// [maxAspectRatio] and understands every [VuScale]; that is what makes
/// faces, scales and frames combinable.
///
/// A face must never stretch its drawing to fill a shape. It reads the shape
/// from the `size` it is given and lays itself out for it, so that circles
/// stay round and letters keep their proportions.
abstract class VuFace {
  const VuFace();

  static const VuFace neon = NeonVuFace();
  static const VuFace classic = ArcVuFace.classic();
  static const VuFace backlit = ArcVuFace.backlit();
  static const VuFace studio = ArcVuFace.studio();
  static const VuFace fan = FanVuFace();
  static const VuFace paper = ArcVuFace.paper();

  /// The ready-made faces, in a fixed order — handy for a picker.
  static const List<VuFace> values = [
    neon,
    classic,
    backlit,
    studio,
    fan,
    paper,
  ];

  /// Width divided by height of the shape the faces were drawn for — about
  /// 1.3 : 1. The default of a meter.
  static const double aspectRatio = 2443.26 / 1883.95;

  /// The tallest and the widest shape a face can take: 1 : 1 and 2 : 1.
  static const double minAspectRatio = 1;
  static const double maxAspectRatio = 2;

  /// A short name, e.g. for a picker.
  String get name;

  /// The colour that stands for this face — the scale below the hot zone.
  /// Use it to tint things next to the meter.
  Color get accent;

  /// The colour of the hot zone.
  Color get hot;

  /// Paints everything that never moves: dial, scale, numbers, label.
  void paintFace(Canvas canvas, Size size, VuFaceContext context);

  /// Paints the clip lamp and its caption, [lit] or dark.
  void paintLamp(Canvas canvas, Size size, VuFaceContext context, bool lit);

  /// Paints the needle (and whatever covers its pivot) at [position] along
  /// the sweep — 0 is the first mark of the scale, 1 the last.
  void paintNeedle(
    Canvas canvas,
    Size size,
    VuFaceContext context,
    double position,
  );

  /// Where the clip lamp and its caption sit on a face of [aspectRatio], as
  /// a fraction of the face — the tap target for `onClipTap`.
  Rect lampArea(double aspectRatio);
}
