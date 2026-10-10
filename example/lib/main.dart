import 'dart:async';
import 'dart:math' as math;

import 'package:analog_vu_meter/analog_vu_meter.dart';
import 'package:flutter/material.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'analog_vu_meter',
        theme: ThemeData.dark(),
        home: const Demo(),
      );
}

/// Two meters fed by a made-up signal. Tap the buttons to step through the
/// faces, the frames and the scales — every combination works.
class Demo extends StatefulWidget {
  const Demo({super.key});

  @override
  State<Demo> createState() => _DemoState();
}

class _DemoState extends State<Demo> {
  final _random = math.Random();
  late final Timer _timer;
  double _left = 0;
  double _right = 0;
  bool _clipped = false;

  int _face = 0;
  // One more than there are frames: the last step is "no frame".
  int _frame = 0;
  int _shape = 1;

  static const _shapes = [1.0, VuFace.aspectRatio, 1.5, 1.75, 2.0];
  int _scale = 0;

  static final _scales = [
    ('digital', VuScale.digital),
    ('analog', VuScale.analog),
    (
      'custom',
      VuScale.even(
        levels: [-60, -48, -36, -24, -12, 0],
        hotFromDb: -12,
        unit: 'dBFS',
      ),
    ),
  ];

  @override
  void initState() {
    super.initState();
    // A new "peak" twenty times a second, as a level meter would deliver it.
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      setState(() {
        _left = 0.2 + _random.nextDouble() * 0.85;
        _right = 0.15 + _random.nextDouble() * 0.7;
        if (_left >= 1) _clipped = true;
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Widget _meter(String caption, double peak, {bool clip = false}) {
    final face = VuFace.values[_face];
    final (_, scale) = _scales[_scale];
    final meter = VuMeter(
      face: face,
      scale: scale,
      // On the analog scale full scale sits on the last mark (+6).
      db: VuScale.dbFromAmplitude(
        peak,
        referenceDb: identical(scale, VuScale.analog) ? 6 : 0,
      ),
      clip: clip,
      onClipTap: () => setState(() => _clipped = false),
      aspectRatio: _shapes[_shape],
    );
    return Center(
      child: _frame == VuBezelStyle.values.length
          ? meter
          : VuMeterBezel(
              style: VuBezelStyle.values[_frame],
              caption: caption,
              child: meter,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final frame = _frame == VuBezelStyle.values.length
        ? 'none'
        : VuBezelStyle.values[_frame].name;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0C0E),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Wrap(
              spacing: 12,
              children: [
                FilledButton.tonal(
                  onPressed: () => setState(
                    () => _face = (_face + 1) % VuFace.values.length,
                  ),
                  child: Text('face: ${VuFace.values[_face].name}'),
                ),
                FilledButton.tonal(
                  onPressed: () => setState(
                    () => _frame =
                        (_frame + 1) % (VuBezelStyle.values.length + 1),
                  ),
                  child: Text('frame: $frame'),
                ),
                FilledButton.tonal(
                  onPressed: () => setState(
                    () => _shape = (_shape + 1) % _shapes.length,
                  ),
                  child: Text(
                    'shape: ${_shapes[_shape].toStringAsFixed(2)} : 1',
                  ),
                ),
                FilledButton.tonal(
                  onPressed: () => setState(
                    () => _scale = (_scale + 1) % _scales.length,
                  ),
                  child: Text('scale: ${_scales[_scale].$1}'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _meter('Left', _left, clip: _clipped)),
                  const SizedBox(width: 16),
                  Expanded(child: _meter('Right', _right)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
