import 'dart:ui';

import '../vu_face.dart';

/// A measure of a dial that depends on its shape: [square] at 1 : 1,
/// [native] at [VuFace.aspectRatio], [wide] at 2 : 1, and in between a
/// straight line from one to the next.
///
/// Faces are not stretched to a new shape — that would distort every letter.
/// They are laid out again: the wider the dial, the flatter its arc and the
/// lower its pivot, until the pivot lies below the window.
double vuShaped(double aspectRatio, double square, double native, double wide) {
  const middle = VuFace.aspectRatio;
  final ratio = aspectRatio.clamp(
    VuFace.minAspectRatio,
    VuFace.maxAspectRatio,
  );
  if (ratio <= middle) {
    final t =
        (ratio - VuFace.minAspectRatio) / (middle - VuFace.minAspectRatio);
    return square + (native - square) * t;
  }
  final t = (ratio - middle) / (VuFace.maxAspectRatio - middle);
  return native + (wide - native) * t;
}

/// Width divided by height of [size], or the native shape if it has none.
double vuRatioOf(Size size) => size.width > 0 && size.height > 0
    ? size.width / size.height
    : VuFace.aspectRatio;
