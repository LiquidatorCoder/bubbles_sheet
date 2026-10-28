import 'dart:async';

import 'package:bubbles_sheet/bubbles_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins when a downward drag released below the lowest detent dismisses.
///
/// smooth_sheets' stock rule only dismisses on a downward release faster than
/// two screen-heights per second, so a sheet dragged almost off-screen and let
/// go while still moving sprang back. `showBubblesSheet` lowers that bar.
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

  /// Drags the sheet's title down by [distance] over [durationMs] in 10ms
  /// moves, then lifts the finger straight away, so the release velocity is
  /// distance / duration. (Samples further apart than 40ms make Flutter's
  /// velocity tracker assume the pointer stopped, hence the small step.)
  Future<void> drag(WidgetTester tester, {required double distance, required int durationMs}) async {
    const stepMs = 10;
    final steps = durationMs ~/ stepMs;
    final gesture = await tester.startGesture(tester.getCenter(find.text('Sheet')));
    for (var i = 1; i <= steps; i++) {
      await tester.pump(const Duration(milliseconds: stepMs));
      // TestGesture stamps events with Duration.zero unless told otherwise,
      // which would make every release velocity zero.
      await gesture.moveBy(Offset(0, distance / steps), timeStamp: Duration(milliseconds: stepMs * i));
    }
    await gesture.up(timeStamp: Duration(milliseconds: durationMs));
    await tester.pumpAndSettle();
  }

  testWidgets('a moving release well below the lowest detent dismisses', (tester) async {
    final (_, done) = await open(tester);
    // 400pt over 0.5s = 800pt/s = 1.0 screen-heights/s on the 800pt screen:
    // under the stock 2.0 bar, over ours. The sheet rests at fit (~300pt), so
    // this takes it almost entirely off-screen.
    await drag(tester, distance: 400, durationMs: 500);
    expect(done.value, isTrue);
  });

  testWidgets('a small, slow nudge below fit does not dismiss', (tester) async {
    final (_, done) = await open(tester);
    // 40pt over 0.5s = 80pt/s = 0.1 screen-heights/s.
    await drag(tester, distance: 40, durationMs: 500);
    expect(done.value, isFalse);
    expect(find.text('Sheet'), findsOneWidget);
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
