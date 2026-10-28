import 'package:bubbles_sheet/bubbles_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the snap feel: after the finger lifts, the sheet reaches its detent
/// quickly and without overshooting it. smooth_sheets' default spring is
/// overdamped (a long creeping tail); ours is critically damped and stiffer.
void main() {
  const screen = Size(400, 800);

  tearDown(BubblesDeviceCornerRadius.resetForTesting);

  Future<void> openSheet(WidgetTester tester) async {
    tester.view
      ..devicePixelRatio = 1.0
      ..physicalSize = screen;
    addTearDown(
      () => tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showBubblesSheet<void>(
                context,
                title: 'Snap',
                detents: [BubblesSheetDetent.fit, BubblesSheetDetent.large],
                builder: (_) => const SizedBox(height: 200, width: double.infinity),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  /// Flings [by] on the header, then steps 16 ms frames until the sheet top
  /// stops moving. Returns (ms until within 1 px of rest, rest top, tops after release).
  Future<({int ms, double finalTop, List<double> tops})> releaseAndTrack(WidgetTester tester, Offset by) async {
    final title = find.text('Snap');
    await tester.fling(title, by, 800);
    final tops = <double>[tester.getTopLeft(title).dy];
    for (var ms = 0; ms < 1500; ms += 16) {
      await tester.pump(const Duration(milliseconds: 16));
      tops.add(tester.getTopLeft(title).dy);
    }
    // "Settled" = within 1 px of where it finally rests, and staying there.
    final rest = tops.last;
    var lastOutside = -1;
    for (var i = 0; i < tops.length; i++) {
      if ((tops[i] - rest).abs() > 1) lastOutside = i;
    }
    final ms = (lastOutside + 1) * 16;
    return (ms: ms, finalTop: rest, tops: tops);
  }

  testWidgets('drag up to large: settles within 450 ms and does not overshoot', (tester) async {
    await openSheet(tester);
    final startTop = tester.getTopLeft(find.text('Snap')).dy;
    final r = await releaseAndTrack(tester, const Offset(0, -400));
    expect(r.finalTop, lessThan(startTop), reason: 'sheet should have grown to large');
    expect(r.ms, lessThanOrEqualTo(450), reason: 'tops: ${r.tops}');
    // Going up: overshoot would carry the header above the final position.
    final minTop = r.tops.reduce((a, b) => a < b ? a : b);
    expect(minTop, greaterThanOrEqualTo(r.finalTop - 1), reason: 'tops: ${r.tops}');
  });

  testWidgets('drag down to fit: settles within 450 ms and does not overshoot', (tester) async {
    await openSheet(tester);
    final fitTop = tester.getTopLeft(find.text('Snap')).dy;
    await releaseAndTrack(tester, const Offset(0, -400));
    final r = await releaseAndTrack(tester, const Offset(0, 400));
    expect(r.finalTop, moreOrLessEquals(fitTop, epsilon: 1));
    expect(r.ms, lessThanOrEqualTo(450), reason: 'tops: ${r.tops}');
    // Going down: overshoot would carry the header below the final position.
    final maxTop = r.tops.reduce((a, b) => a > b ? a : b);
    expect(maxTop, lessThanOrEqualTo(r.finalTop + 1), reason: 'tops: ${r.tops}');
  });
}
