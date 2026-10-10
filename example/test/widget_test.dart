import 'package:analog_vu_meter/analog_vu_meter.dart';
import 'package:analog_vu_meter_example/main.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows two meters and steps through the faces', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    expect(find.byType(VuMeter), findsNWidgets(2));
    for (final face in [...VuFace.values.skip(1), VuFace.values.first]) {
      await tester.tap(find.textContaining('face:'));
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.widget<VuMeter>(find.byType(VuMeter).first).face, face);
      expect(tester.takeException(), isNull);
    }
    // Take the app down, so that its timer stops.
    await tester.pumpWidget(const SizedBox());
  });
}
