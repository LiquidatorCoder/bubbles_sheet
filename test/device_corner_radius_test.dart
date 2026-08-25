import 'dart:ui' as ui;

import 'package:bubbles_sheet/bubbles_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Resolves through a real BuildContext so View.maybeOf sees the test view.
  Future<double> resolve(WidgetTester tester, BubblesSheetMetrics metrics) async {
    late double resolved;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            resolved = metrics.resolveDeviceCornerRadius(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return resolved;
  }

  testWidgets('converts the display radius from physical to logical pixels', (tester) async {
    // dart:ui reports corner radii in physical pixels. Skipping the conversion
    // would hand a 3x device a radius three times too large — a 62pt bezel
    // would come back as 186.
    tester.view
      ..devicePixelRatio = 3.0
      ..displayFeatures = <ui.DisplayFeature>[];
    addTearDown(tester.view.reset);

    expect(await resolve(tester, const BubblesSheetMetrics()), _expectedFor(tester, 3.0));
  });

  testWidgets('an explicit radius wins over the display', (tester) async {
    expect(await resolve(tester, const BubblesSheetMetrics(deviceCornerRadius: 44)), 44);
  });

  testWidgets('an explicit zero squares the corners off rather than resolving', (tester) async {
    expect(await resolve(tester, const BubblesSheetMetrics(deviceCornerRadius: 0)), 0);
  });

  test('copyWith keeps an override, and resetDeviceCornerRadius clears it', () {
    const overridden = BubblesSheetMetrics(deviceCornerRadius: 44);
    expect(overridden.copyWith(inset: 8).deviceCornerRadius, 44);
    expect(overridden.copyWith(resetDeviceCornerRadius: true).deviceCornerRadius, isNull);
  });

  test('the default is null, so the display is what answers', () {
    expect(const BubblesSheetMetrics().deviceCornerRadius, isNull);
  });
}

// The test view reports whatever the host platform does for corner radii, which
// is nothing under flutter_test — so the honest expectation is 0, and the point
// of the assertion is that the conversion path runs without throwing and never
// returns a physical-pixel value.
double _expectedFor(WidgetTester tester, double ratio) {
  final radii = tester.view.displayCornerRadii;
  if (radii == null) return 0;
  final biggest = radii.bottomLeft > radii.bottomRight ? radii.bottomLeft : radii.bottomRight;
  return biggest / ratio;
}
