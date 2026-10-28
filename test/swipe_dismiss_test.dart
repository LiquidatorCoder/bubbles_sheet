import 'dart:async';

import 'package:bubbles_sheet/bubbles_sheet.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins when a downward drag released below the lowest detent dismisses.
///
/// smooth_sheets' stock rule only dismisses on a downward release faster than
/// two screen-heights per second, so a sheet dragged almost off-screen and let
/// go while still moving sprang back. `showBubblesSheet` lowers that bar to 0.2
/// screen-heights per second (160px/s here): a slow peek snaps back, a
/// deliberate drag dismisses.
void main() {
  tearDown(BubblesDeviceCornerRadius.resetForTesting);

  const screen = Size(400, 800);

  Future<(Future<void>, ValueNotifier<bool>)> open(
    WidgetTester tester, {
    bool swipeDismissible = true,
    List<BubblesSheetDetent> detents = const [BubblesSheetDetent.fit, BubblesSheetDetent.large],
  }) async {
    tester.view
      ..devicePixelRatio = 1.0
      ..physicalSize = screen;
    addTearDown(
      () => tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio(),
    );

    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
    final done = ValueNotifier<bool>(false);
    addTearDown(done.dispose);
    final future = showBubblesSheet<void>(
      ctx,
      title: 'Sheet',
      detents: detents,
      swipeDismissible: swipeDismissible,
      builder: (_) => const SizedBox(height: 200, width: double.infinity),
    );
    unawaited(future.then((_) => done.value = true));
    await tester.pumpAndSettle();
    return (future, done);
  }

  /// Drags the sheet's title down by one entry of [deltas] per 10ms move
  /// (samples further apart than 40ms make Flutter's velocity tracker assume
  /// the pointer stopped, hence the small step), then lifts the finger.
  ///
  /// Returns the release velocity (px/s, downwards positive) the drag
  /// recogniser reports to the sheet: a [VelocityTracker] fed the same
  /// timestamped moves, zeroed unless it passes `isFlingGesture` (faster than
  /// [kMinFlingVelocity] *and* moved more than the hit slop within the
  /// tracker's last ~100ms window).
  Future<double> dragSteps(WidgetTester tester, List<double> deltas) async {
    const stepMs = 10;
    final tracker = VelocityTracker.withKind(PointerDeviceKind.touch);
    var y = 0.0;
    tracker.addPosition(Duration.zero, Offset.zero);
    final gesture = await tester.startGesture(tester.getCenter(find.text('Sheet')));
    for (var i = 1; i <= deltas.length; i++) {
      await tester.pump(const Duration(milliseconds: stepMs));
      // TestGesture stamps events with Duration.zero unless told otherwise,
      // which would make every release velocity zero.
      await gesture.moveBy(Offset(0, deltas[i - 1]), timeStamp: Duration(milliseconds: stepMs * i));
      y += deltas[i - 1];
      tracker.addPosition(Duration(milliseconds: stepMs * i), Offset(0, y));
    }
    await gesture.up(timeStamp: Duration(milliseconds: stepMs * deltas.length));
    final estimate = tracker.getVelocityEstimate();
    final isFling =
        estimate != null &&
        estimate.pixelsPerSecond.distanceSquared > kMinFlingVelocity * kMinFlingVelocity &&
        estimate.offset.distanceSquared > kTouchSlop * kTouchSlop;
    await tester.pumpAndSettle();
    return isFling ? estimate.pixelsPerSecond.dy : 0;
  }

  /// Drags the sheet's title down by [distance] over [durationMs] in 10ms
  /// moves, then lifts the finger straight away, so the release velocity is
  /// distance / duration. See [dragSteps] for the return value.
  Future<double> drag(WidgetTester tester, {required double distance, required int durationMs}) {
    final steps = durationMs ~/ 10;
    return dragSteps(tester, List.filled(steps, distance / steps));
  }

  testWidgets('a slow peek released as a non-zero fling does not dismiss', (tester) async {
    final (_, done) = await open(tester);
    // A 40px pull: 15px at a steady 100px/s, then the finger eases out over
    // 120ms, from 350px/s down to 100px/s at the instant of release (~27px).
    // The recogniser only reports a fling when the last ~100ms moved past the
    // 18px hit slop, which a steady 80px/s crawl (8px per 100ms) never does:
    // that is reported as 0 and falls to the distance rule. The release is
    // therefore ~80px/s, above Flutter's 50px/s floor and the old 0.04 ratio's
    // 32px/s, yet far under the 160px/s bar. At 0.04 this closed the sheet.
    final deltas = [
      ...List.filled(15, 1.0),
      for (var i = 0; i < 12; i++) (350 - 250 * i / 11) / 100,
    ];
    final v = await dragSteps(tester, deltas);
    debugPrint('slow peek: ${deltas.fold<double>(0, (a, b) => a + b)}px, release velocity $v px/s');
    expect(v, inExclusiveRange(kMinFlingVelocity, 160));
    expect(done.value, isFalse);
    expect(find.text('Sheet'), findsOneWidget);
  });

  testWidgets('a deliberate drag released at ~0.5 screen-heights/s dismisses', (tester) async {
    final (_, done) = await open(tester);
    // 320px over 0.8s = ~400px/s = 0.5 screen-heights/s on the 800px screen:
    // far under the stock 2.0 bar (1600px/s), over ours (160px/s). The sheet
    // rests at fit (~300px), so this takes it almost entirely off-screen.
    final v = await drag(tester, distance: 320, durationMs: 800);
    debugPrint('deliberate drag release velocity: $v px/s');
    expect(v, closeTo(400, 20));
    expect(done.value, isTrue);
  });

  testWidgets('a slower deliberate release at ~0.3 screen-heights/s dismisses', (tester) async {
    final (_, done) = await open(tester);
    // 240px over 1s = ~240px/s = 0.3 screen-heights/s: over the 160px/s bar.
    final v = await drag(tester, distance: 240, durationMs: 1000);
    debugPrint('0.3 h/s release velocity: $v px/s');
    expect(v, closeTo(240, 15));
    expect(done.value, isTrue);
  });

  testWidgets('a release far past the threshold dismisses', (tester) async {
    final (_, done) = await open(tester);
    // 400px over 0.5s = 800px/s = 1.0 screen-heights/s.
    final v = await drag(tester, distance: 400, durationMs: 500);
    debugPrint('far release velocity: $v px/s');
    expect(done.value, isTrue);
  });

  testWidgets('swipeDismissible: false never dismisses', (tester) async {
    final (_, done) = await open(tester, swipeDismissible: false);
    await drag(tester, distance: 400, durationMs: 500);
    expect(done.value, isFalse);
  });

  testWidgets('a fast flick down from large that settles at fit does not dismiss', (tester) async {
    final (_, done) = await open(tester, detents: const [BubblesSheetDetent.fit, BubblesSheetDetent.large]);
    final sheet = find.text('Sheet');
    // Lift to large first.
    await drag(tester, distance: -400, durationMs: 200);
    expect(done.value, isFalse);
    // Fast flick (~2000pt/s) that the sheet absorbs by snapping to fit.
    final gesture = await tester.startGesture(tester.getCenter(sheet));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
      await gesture.moveBy(const Offset(0, 20), timeStamp: Duration(milliseconds: 10 * (i + 1)));
    }
    await gesture.up(timeStamp: const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    expect(done.value, isFalse);
  });
}
