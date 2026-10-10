import 'dart:io';
import 'dart:ui' as ui;

import 'package:analog_vu_meter/analog_vu_meter.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {double width = 480}) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: SizedBox(width: width, child: child)),
    );

/// The shapes worth trying: both ends and the steps between.
const _ratios = [1.0, 1.25, 1.5, 1.75, 2.0];

void main() {
  group('VuScale', () {
    for (final (name, scale) in [
      ('analog', VuScale.analog),
      ('digital', VuScale.digital),
      (
        'even',
        VuScale.even(levels: [-60, -48, -36, -24, -12, 0], hotFromDb: -12),
      ),
    ]) {
      test('$name: marks run from 0 to 1 and sit at their own position', () {
        expect(scale.marks.first.$2, 0);
        expect(scale.marks.last.$2, 1);
        for (final (db, position) in scale.marks) {
          expect(scale.positionFor(db), closeTo(position, 1e-9));
        }
        for (final db in scale.majorDb) {
          expect(scale.marks.any((mark) => mark.$1 == db), isTrue);
        }
      });

      test('$name: positions rise with the level', () {
        var last = scale.positionFor(-120);
        for (var db = -100.0; db <= 10; db += 0.25) {
          final position = scale.positionFor(db);
          expect(position, greaterThanOrEqualTo(last), reason: '$db dB');
          last = position;
        }
      });

      test(
          '$name: silence rests before the scale, overload stops at the '
          'last mark', () {
        expect(
            scale.positionFor(double.negativeInfinity), VuScale.restPosition);
        expect(scale.positionFor(double.nan), VuScale.restPosition);
        expect(scale.positionFor(scale.silenceDb), VuScale.restPosition);
        expect(VuScale.restPosition, lessThan(0));
        expect(scale.positionFor(60), 1);
      });
    }

    test('analog and digital share the drawing: the same ticks', () {
      expect(
        [for (final mark in VuScale.digital.marks) mark.$2],
        [for (final mark in VuScale.analog.marks) mark.$2],
      );
    });

    test('analog: 100 % is 0 dB, hot above 0', () {
      const scale = VuScale.analog;
      expect(scale.positionForPercent(100), scale.positionFor(0));
      expect(
        scale.positionForPercent(50),
        closeTo(scale.positionFor(-6.0206), 1e-6),
      );
      expect(scale.positionForPercent(0), VuScale.restPosition);
      expect(scale.hotFromDb, 0);
      expect(scale.maxDb, 6);
      expect(scale.hotPosition, scale.positionFor(0));
    });

    // Nothing exists above digital full scale: the dial ends at 0.
    test('digital: ends at 0 dBFS, hot over the last 6 dB', () {
      const scale = VuScale.digital;
      expect(scale.maxDb, 0);
      expect(scale.minDb, -40);
      expect(scale.hotFromDb, -6);
      expect(scale.unit, 'dBFS');
      expect(scale.positionFor(0), 1);
      expect(scale.positionForPercent(100), 1);
      // The hot zone starts where the analog scale has its 0.
      expect(scale.hotPosition, VuScale.analog.positionFor(0));
    });

    test('even: levels are spread evenly, with ticks between', () {
      final scale = VuScale.even(
        levels: [-30, -20, -10, 0],
        minorTicks: 1,
        hotFromDb: -10,
        unit: 'dBu',
      );
      expect(scale.positionFor(-30), 0);
      expect(scale.positionFor(-20), closeTo(1 / 3, 1e-9));
      expect(scale.positionFor(-15), closeTo(0.5, 1e-9));
      expect(scale.positionFor(0), 1);
      // Three steps, each halved: seven marks.
      expect(scale.marks, hasLength(7));
      expect(scale.majorDb, [-30, -20, -10, 0]);
      expect(scale.hotPosition, closeTo(2 / 3, 1e-9));
      expect(scale.unit, 'dBu');
      // One step below the first level is silence.
      expect(scale.silenceDb, -40);
    });

    test('even: without a hot level there is no hot zone', () {
      final scale = VuScale.even(levels: [-20, -10, 0]);
      expect(scale.hotPosition, greaterThan(1));
    });

    test('even: refuses fewer than two or unordered levels', () {
      expect(() => VuScale.even(levels: [0]), throwsArgumentError);
      expect(() => VuScale.even(levels: [0, -10]), throwsArgumentError);
    });

    test('a scale from hand-placed marks', () {
      const scale = VuScale(
        marks: [(-10, 0), (-5, 0.7), (0, 1)],
        majorDb: [-10, 0],
        hotFromDb: -5,
        silenceDb: -20,
        unit: 'VU',
      );
      expect(scale.positionFor(-7.5), closeTo(0.35, 1e-9));
      expect(scale.hotPosition, 0.7);
    });

    test('labels: negatives carry their sign, the rest are plain', () {
      expect(VuScale.analog.labelFor(-20), '-20');
      expect(VuScale.analog.labelFor(0), '0');
      expect(VuScale.analog.labelFor(3), '3');
      expect(VuScale.analog.labelFor(-1.5), '-1.5');
    });

    test('amplitude to dB, with a reference', () {
      expect(VuScale.dbFromAmplitude(1), 0);
      expect(VuScale.dbFromAmplitude(0.5), closeTo(-6.0206, 1e-4));
      expect(VuScale.dbFromAmplitude(1, referenceDb: 6), 6);
      expect(VuScale.dbFromAmplitude(0), double.negativeInfinity);
    });
  });

  group('VuFace', () {
    test('six ready-made faces with distinct names', () {
      expect(VuFace.values, hasLength(6));
      expect({for (final face in VuFace.values) face.name}, hasLength(6));
      expect(VuFace.values.first, VuFace.neon);
    });

    test('faces compare by value, so a recoloured one repaints', () {
      expect(const NeonVuFace(), VuFace.neon);
      expect(const NeonVuFace(glow: false), isNot(VuFace.neon));
      expect(const ArcVuFace.classic(), VuFace.classic);
      expect(
        const ArcVuFace.classic(needle: Color(0xFFFF0000)),
        isNot(VuFace.classic),
      );
      expect(const FanVuFace(), VuFace.fan);
    });

    test('every lamp area lies on the face, in every shape', () {
      for (final face in VuFace.values) {
        for (final ratio in _ratios) {
          final area = face.lampArea(ratio);
          final reason = '${face.name} at $ratio';
          expect(area.left, greaterThanOrEqualTo(0), reason: reason);
          expect(area.top, greaterThanOrEqualTo(0), reason: reason);
          expect(area.right, lessThanOrEqualTo(1), reason: reason);
          expect(area.bottom, lessThanOrEqualTo(1), reason: reason);
        }
      }
    });
  });

  group('VuMeter', () {
    testWidgets('keeps the aspect ratio of its face', (tester) async {
      await tester.pumpWidget(_host(const VuMeter(db: -3)));
      final size = tester.getSize(find.byType(VuMeter));
      expect(size.width, 480);
      expect(size.width / size.height, closeTo(VuFace.aspectRatio, 1e-3));
      expect(tester.takeException(), isNull);
    });

    // From square to twice as wide as high — every face, with and without
    // a frame.
    testWidgets('takes every shape from 1 : 1 to 2 : 1', (tester) async {
      for (final face in VuFace.values) {
        for (final ratio in _ratios) {
          final reason = '${face.name} at $ratio';
          await tester.pumpWidget(
            _host(
              VuMeter(
                db: -3,
                clip: true,
                face: face,
                aspectRatio: ratio,
                label: 'Front Left',
              ),
            ),
          );
          final size = tester.getSize(find.byType(VuMeter));
          expect(size.width, 480, reason: reason);
          expect(size.width / size.height, closeTo(ratio, 1e-3),
              reason: reason);
          expect(tester.takeException(), isNull, reason: reason);

          await tester.pumpWidget(
            _host(
              VuMeterBezel(
                caption: 'Left',
                child: VuMeter(db: -3, face: face, aspectRatio: ratio),
              ),
            ),
          );
          final frame = tester.getSize(find.byType(VuMeterBezel));
          expect(
            frame.width / frame.height,
            closeTo(VuMeterBezel.aspectRatioFor(ratio), 1e-3),
            reason: reason,
          );
          // The window has the shape of the meter in it.
          final window = tester.getSize(find.byType(VuMeter));
          expect(window.width / window.height, closeTo(ratio, 1e-3),
              reason: reason);
          expect(tester.takeException(), isNull, reason: reason);
        }
      }
    });

    testWidgets('the clip lamp can be tapped in every shape', (tester) async {
      for (final face in VuFace.values) {
        for (final ratio in _ratios) {
          var taps = 0;
          await tester.pumpWidget(
            _host(
              VuMeter(
                db: 0,
                clip: true,
                face: face,
                aspectRatio: ratio,
                onClipTap: () => taps++,
              ),
            ),
          );
          final rect = tester.getRect(find.byType(VuMeter));
          final lamp = face.lampArea(ratio);
          await tester.tapAt(
            rect.topLeft +
                Offset(
                  rect.width * lamp.center.dx,
                  rect.height * lamp.center.dy,
                ),
          );
          expect(taps, 1, reason: '${face.name} at $ratio');
        }
      }
    });

    testWidgets('minus and plus at the ends can be turned off', (tester) async {
      for (final face in VuFace.values) {
        await tester.pumpWidget(
          _host(VuMeter(db: -3, face: face, showSigns: false)),
        );
        expect(tester.takeException(), isNull, reason: face.name);
      }
      // A face repaints when the switch changes.
      expect(
        const VuFaceContext(scale: VuScale.digital),
        isNot(const VuFaceContext(scale: VuScale.digital, showSigns: false)),
      );
    });

    testWidgets('the print is optional on every arc face', (tester) async {
      // Paper and classic come printed, the others clean.
      expect(const ArcVuFace.paper().grain, 1);
      expect(const ArcVuFace.classic().grain, 1);
      expect(const ArcVuFace.backlit().grain, 0);
      expect(const ArcVuFace.studio().grain, 0);
      expect(const ArcVuFace.classic(grain: 0), isNot(VuFace.classic));
      for (final face in const [
        ArcVuFace.paper(grain: 0),
        ArcVuFace.classic(grain: 0),
        ArcVuFace.backlit(grain: 1),
        ArcVuFace.studio(grain: 0.5),
      ]) {
        for (final ratio in _ratios) {
          await tester.pumpWidget(
            _host(VuMeter(db: -3, face: face, aspectRatio: ratio)),
          );
          expect(tester.takeException(), isNull, reason: face.name);
        }
      }
    });

    test('a shape outside 1 : 1 … 2 : 1 is refused', () {
      expect(() => VuMeter(db: 0, aspectRatio: 0.9), throwsAssertionError);
      expect(() => VuMeter(db: 0, aspectRatio: 2.1), throwsAssertionError);
    });

    // Every face must take every scale, at every size.
    testWidgets('every face paints every scale, tiny and large', (
      tester,
    ) async {
      final scales = [
        VuScale.analog,
        VuScale.digital,
        VuScale.even(levels: [-60, -40, -20, 0], minorTicks: 3),
        VuScale.even(levels: [-12, 0, 12], hotFromDb: 0, unit: 'dBu'),
      ];
      for (final face in VuFace.values) {
        for (final scale in scales) {
          for (final width in [60.0, 320.0, 1100.0]) {
            await tester.pumpWidget(
              _host(
                VuMeter(
                  db: scale.maxDb - 2,
                  clip: true,
                  face: face,
                  scale: scale,
                  label: 'A very long label that must still fit',
                  clipLabel: 'OVERLOAD',
                  showPercentScale: width > 100,
                  showClipLamp: width > 100,
                  borderRadius: 8,
                ),
                width: width,
              ),
            );
            expect(
              tester.takeException(),
              isNull,
              reason: '${face.name} ${scale.unit} $width',
            );
          }
        }
      }
    });

    testWidgets('the needle travels to a new level and comes to rest', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const VuMeter(db: -20)));
      await tester.pumpWidget(_host(const VuMeter(db: 0)));
      // Under way: frames are still being scheduled.
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.hasRunningAnimations, isTrue);
      // After well over the response time it has settled.
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('with no response time nothing animates', (tester) async {
      await tester.pumpWidget(
        _host(const VuMeter(db: -20, response: Duration.zero)),
      );
      await tester.pumpWidget(
        _host(const VuMeter(db: 3, response: Duration.zero)),
      );
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('a tap on the clip lamp is reported, on every face', (
      tester,
    ) async {
      for (final face in VuFace.values) {
        var taps = 0;
        await tester.pumpWidget(
          _host(
            VuMeter(db: 6, clip: true, face: face, onClipTap: () => taps++),
          ),
        );
        final rect = tester.getRect(find.byType(VuMeter));
        final lamp = face.lampArea(VuFace.aspectRatio);
        await tester.tapAt(
          rect.topLeft +
              Offset(
                rect.width * lamp.center.dx,
                rect.height * lamp.center.dy,
              ),
        );
        expect(taps, 1, reason: face.name);
        // Elsewhere on the face nothing happens.
        await tester.tapAt(rect.center);
        expect(taps, 1, reason: face.name);
      }
    });

    testWidgets('without the lamp there is nothing to tap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          VuMeter(db: 0, showClipLamp: false, onClipTap: () => taps++),
        ),
      );
      final rect = tester.getRect(find.byType(VuMeter));
      final lamp = VuFace.neon.lampArea(VuFace.aspectRatio);
      await tester.tapAt(
        rect.topLeft +
            Offset(rect.width * lamp.center.dx, rect.height * lamp.center.dy),
      );
      expect(taps, 0);
    });

    testWidgets('announces label and level with the unit of the scale', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(const VuMeter(db: -3, label: 'Left', scale: VuScale.digital)),
      );
      expect(find.bySemanticsLabel('Left'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Left')).value,
        '-3.0 dBFS',
      );
      handle.dispose();
    });
  });

  group('VuMeterBezel', () {
    test('four ready-made frames with distinct names', () {
      expect(VuBezelStyle.values, hasLength(4));
      expect({for (final s in VuBezelStyle.values) s.name}, hasLength(4));
    });

    // Every frame must fit every face.
    testWidgets('every frame takes every face', (tester) async {
      for (final style in VuBezelStyle.values) {
        for (final face in VuFace.values) {
          await tester.pumpWidget(
            _host(
              VuMeterBezel(
                style: style,
                caption: 'Front Left',
                child: VuMeter(db: -3, face: face),
              ),
            ),
          );
          expect(
            tester.takeException(),
            isNull,
            reason: '${style.name} ${face.name}',
          );
        }
      }
    });

    testWidgets('frames the meter and shows the caption in capitals', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const VuMeterBezel(caption: 'Front Left', child: VuMeter(db: -3)),
        ),
      );
      final frame = tester.getSize(find.byType(VuMeterBezel));
      expect(
        frame.width / frame.height,
        closeTo(VuMeterBezel.aspectRatio, 1e-3),
      );
      // The window is inside the frame and keeps the meter's own ratio.
      final meter = tester.getRect(find.byType(VuMeter));
      final outer = tester.getRect(find.byType(VuMeterBezel));
      expect(meter.left, greaterThan(outer.left));
      expect(meter.right, lessThan(outer.right));
      expect(meter.width / meter.height, closeTo(VuFace.aspectRatio, 1e-3));
      // The caption sits on the strip below the window.
      final caption = tester.getRect(find.text('FRONT LEFT'));
      expect(caption.top, greaterThan(meter.bottom));
      expect(caption.bottom, lessThan(outer.bottom));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a long caption shrinks instead of overflowing', (
      tester,
    ) async {
      for (final style in VuBezelStyle.values) {
        await tester.pumpWidget(
          _host(
            VuMeterBezel(
              style: style,
              caption: 'A caption far too long for this small frame',
              child: const VuMeter(db: 0),
            ),
            width: 120,
          ),
        );
        expect(tester.takeException(), isNull, reason: style.name);
      }
    });
  });

  // Writes the pictures of the README into the directory VU_SHOT names:
  //
  //   VU_SHOT=doc VU_FONT=/path/to/a.ttf flutter test --plain-name pictures
  //
  // VU_FONT names the typeface; without it the test font draws boxes.
  testWidgets('pictures', (tester) async {
    final target = Platform.environment['VU_SHOT'];
    if (target == null) return;
    final font = Platform.environment['VU_FONT'];
    if (font != null) {
      await tester.runAsync(() async {
        final loader = FontLoader('Shot')
          ..addFont(
            Future.value(File(font).readAsBytesSync().buffer.asByteData()),
          );
        await loader.load();
      });
    }
    final family = font == null ? null : 'Shot';
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> shoot(String name, Size size, List<Widget> cells,
        {int columns = 0}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      final perRow = columns == 0 ? cells.length : columns;
      final key = GlobalKey();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(
            key: key,
            child: ColoredBox(
              color: const Color(0xFF0B0C0E),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    for (var i = 0; i < cells.length; i += perRow)
                      Expanded(
                        child: Row(
                          children: [
                            for (final cell in cells.skip(i).take(perRow))
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Center(child: cell),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$target/$name.png')
          ..createSync(recursive: true)
          ..writeAsBytesSync(data!.buffer.asUint8List());
      });
    }

    final levels = [-4.0, -1.5, -9.0, -3.0, -6.5, -12.0];
    VuMeter meter(int i, {double ratio = VuFace.aspectRatio, String? label}) =>
        VuMeter(
          db: levels[i % levels.length],
          clip: i == 0,
          face: VuFace.values[i % VuFace.values.length],
          scale: i.isEven ? VuScale.digital : VuScale.analog,
          // On a dBFS scale nothing is "plus".
          showSigns: i.isOdd,
          label: label,
          response: Duration.zero,
          fontFamily: family,
          aspectRatio: ratio,
        );

    // The six faces, by name.
    await shoot(
      'faces',
      const Size(1500, 830),
      [
        for (var i = 0; i < VuFace.values.length; i++)
          VuMeter(
            db: levels[i],
            clip: i == 0,
            face: VuFace.values[i],
            scale: i.isEven ? VuScale.digital : VuScale.analog,
            // On a dBFS scale nothing is "plus".
            showSigns: i.isOdd,
            label: VuFace.values[i].name,
            response: Duration.zero,
            fontFamily: family,
            borderRadius: 8,
          ),
      ],
      columns: 3,
    );
    // The four frames, each around another face.
    await shoot('frames', const Size(1600, 400), [
      for (var i = 0; i < VuBezelStyle.values.length; i++)
        VuMeterBezel(
          style: VuBezelStyle.values[i],
          caption: VuBezelStyle.values[i].name,
          fontFamily: family,
          child: meter(i + 1),
        ),
    ]);
    // One face in five shapes, and another without a frame.
    await shoot(
      'shapes',
      const Size(1700, 640),
      [
        for (final ratio in _ratios)
          VuMeterBezel(
            style: VuBezelStyle.silver,
            caption: '$ratio : 1',
            fontFamily: family,
            child: meter(1, ratio: ratio),
          ),
        for (final ratio in _ratios)
          VuMeter(
            db: -9,
            face: VuFace.neon,
            scale: VuScale.digital,
            showSigns: false,
            response: Duration.zero,
            fontFamily: family,
            borderRadius: 8,
            aspectRatio: ratio,
          ),
      ],
      columns: 5,
    );
    // The two printed faces, close up.
    await shoot('print', const Size(1400, 560), [
      for (final face in [VuFace.paper, VuFace.classic])
        VuMeter(
          db: -8,
          face: face,
          response: Duration.zero,
          fontFamily: family,
          borderRadius: 8,
        ),
    ]);
    // A stereo pair, as the first picture.
    await shoot('pair', const Size(1200, 560), [
      for (final (caption, db) in [('Left', -4.0), ('Right', -7.5)])
        VuMeterBezel(
          caption: caption,
          fontFamily: family,
          child: VuMeter(
            db: db,
            face: VuFace.classic,
            response: Duration.zero,
            fontFamily: family,
          ),
        ),
    ]);
  });
}
