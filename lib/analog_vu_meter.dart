/// Analog needle meters: six faces, four frames, any scale.
///
/// ```dart
/// VuMeterBezel(
///   caption: 'LEFT',
///   child: VuMeter(db: -3, face: VuFace.classic),
/// )
/// ```
library;

export 'src/faces/arc_face.dart';
export 'src/faces/fan_face.dart';
export 'src/faces/neon_face.dart';
export 'src/vu_bezel.dart';
export 'src/vu_face.dart';
export 'src/vu_meter.dart';
export 'src/vu_scale.dart';
