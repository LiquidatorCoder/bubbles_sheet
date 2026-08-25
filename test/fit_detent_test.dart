import 'package:bubbles_sheet/bubbles_sheet.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression for the fit detent going stale when the body grows while the
/// sheet is open — a status sheet that gains a detail paragraph and an extra
/// action once a transaction settles, say. When the detent was measured once at
/// present time the sheet held its original height, and the new content was
/// pushed off the bottom of the screen, unreachable until it was reopened.
void main() {
  const screen = Size(400, 800);
  const grownBy = 200.0;

  Widget host(ValueListenable<bool> grown, Key bottomKey, List<BubblesSheetDetent> detents) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showBubblesSheet<void>(
              context,
              title: 'In flight',
              detents: detents,
              builder: (_) => ValueListenableBuilder<bool>(
                valueListenable: grown,
                builder: (_, big, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 80, width: double.infinity),
                    if (big) const SizedBox(height: grownBy, width: double.infinity),
                    Container(key: bottomKey, height: 44, width: double.infinity, color: Colors.red),
                  ],
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
  }

  for (final (label, detents) in <(String, List<BubblesSheetDetent>)>[
    ('fit-only', [BubblesSheetDetent.fit]),
    ('fit + large', [BubblesSheetDetent.fit, BubblesSheetDetent.large]),
  ]) {
    testWidgets('$label sheet re-measures when its body grows and shrinks while open', (tester) async {
      tester.view
        ..devicePixelRatio = 1.0
        ..physicalSize = screen;
      addTearDown(
        () => tester.view
          ..resetViewInsets()
          ..resetPhysicalSize()
          ..resetDevicePixelRatio(),
      );

      final grown = ValueNotifier<bool>(false);
      addTearDown(grown.dispose);
      final bottomKey = UniqueKey();

      await tester.pumpWidget(host(grown, bottomKey, detents));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // The sheet is bottom-anchored, so the last row's bottom edge is fixed
      // and the header rides up as the body grows.
      final settledBottom = tester.getRect(find.byKey(bottomKey)).bottom;
      final settledTop = tester.getRect(find.text('In flight')).top;
      expect(settledBottom, lessThanOrEqualTo(screen.height));

      grown.value = true;
      await tester.pumpAndSettle();

      expect(tester.getRect(find.byKey(bottomKey)).bottom, lessThanOrEqualTo(screen.height));
      expect(tester.getRect(find.byKey(bottomKey)).bottom, moreOrLessEquals(settledBottom, epsilon: 0.5));
      expect(tester.getRect(find.text('In flight')).top, moreOrLessEquals(settledTop - grownBy, epsilon: 0.5));

      grown.value = false;
      await tester.pumpAndSettle();

      expect(tester.getRect(find.byKey(bottomKey)).bottom, moreOrLessEquals(settledBottom, epsilon: 0.5));
      expect(tester.getRect(find.text('In flight')).top, moreOrLessEquals(settledTop, epsilon: 0.5));
    });
  }

  // The removed `_FitExtentTracker` existed, by its own doc, "so the fit detent
  // can snap back to the natural height after the user drags up to large".
  // Resolving the detent live has to keep that promise.
  testWidgets('fit + large snaps back to the natural fit height after a drag to large', (tester) async {
    tester.view
      ..devicePixelRatio = 1.0
      ..physicalSize = screen;
    addTearDown(
      () => tester.view
        ..resetViewInsets()
        ..resetPhysicalSize()
        ..resetDevicePixelRatio(),
    );

    final grown = ValueNotifier<bool>(false);
    addTearDown(grown.dispose);

    await tester.pumpWidget(host(grown, UniqueKey(), const [BubblesSheetDetent.fit, BubblesSheetDetent.large]));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final fitTop = tester.getRect(find.text('In flight')).top;

    await tester.fling(find.text('In flight'), const Offset(0, -400), 1200);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('In flight')).top, lessThan(fitTop - 100), reason: 'should ride up to large');

    await tester.fling(find.text('In flight'), const Offset(0, 400), 1200);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('In flight')).top, moreOrLessEquals(fitTop, epsilon: 0.5));
  });

  // Growth is capped by the viewport: `contentSize` can never exceed the space
  // the sheet was given, so an oversized body clamps instead of walking off the
  // top of the screen.
  testWidgets('fit detent clamps when the body outgrows the viewport', (tester) async {
    tester.view
      ..devicePixelRatio = 1.0
      ..physicalSize = screen;
    addTearDown(
      () => tester.view
        ..resetViewInsets()
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
                title: 'In flight',
                detents: const [BubblesSheetDetent.fit],
                builder: (_) => const SizedBox(height: 2000, width: double.infinity),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final header = tester.getRect(find.text('In flight'));
    expect(header.top, greaterThanOrEqualTo(0.0), reason: 'the sheet must not walk off the top of the screen');
    expect(header.bottom, lessThanOrEqualTo(screen.height));
  });
}
