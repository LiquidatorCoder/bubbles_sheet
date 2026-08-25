import 'package:bubbles_sheet/bubbles_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(BubblesDeviceCornerRadius.resetForTesting);

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

  testWidgets('an explicit radius wins over anything the display reports', (tester) async {
    BubblesDeviceCornerRadius.setValueForTesting(62);
    expect(await resolve(tester, const BubblesSheetMetrics(deviceCornerRadius: 44)), 44);
  });

  testWidgets('an explicit zero squares the corners off rather than resolving', (tester) async {
    BubblesDeviceCornerRadius.setValueForTesting(62);
    expect(await resolve(tester, const BubblesSheetMetrics(deviceCornerRadius: 0)), 0);
  });

  testWidgets('with no override, the resolved display radius is used', (tester) async {
    BubblesDeviceCornerRadius.setValueForTesting(62);
    expect(await resolve(tester, const BubblesSheetMetrics()), 62);
  });

  testWidgets('falls back to 0 while the lookup is still outstanding', (tester) async {
    // The platform channel is unanswered under flutter_test, so this is also
    // what a platform with no implementation gets: square corners, not a crash.
    expect(await resolve(tester, const BubblesSheetMetrics()), 0);
  });

  testWidgets('a late answer notifies, so an open sheet can repaint', (tester) async {
    var notified = 0;
    void listener() => notified++;
    BubblesDeviceCornerRadius.listenable.addListener(listener);
    addTearDown(() => BubblesDeviceCornerRadius.listenable.removeListener(listener));

    expect(await resolve(tester, const BubblesSheetMetrics()), 0);
    expect(notified, 0);

    BubblesDeviceCornerRadius.setValueForTesting(62);

    expect(notified, 1, reason: 'surfaces listen to this to redraw their corners');
    expect(BubblesDeviceCornerRadius.value, 62);
  });

  test('the default metrics carry no override, so the display answers', () {
    expect(const BubblesSheetMetrics().deviceCornerRadius, isNull);
  });

  test('copyWith keeps an override, and resetDeviceCornerRadius clears it', () {
    const overridden = BubblesSheetMetrics(deviceCornerRadius: 44);
    expect(overridden.copyWith(inset: 8).deviceCornerRadius, 44);
    expect(overridden.copyWith(resetDeviceCornerRadius: true).deviceCornerRadius, isNull);
  });

  // The resolver being right is not the same as the sheet painting it. The
  // radius arrives over a platform channel, i.e. after the surface has already
  // painted once, and the surface only re-runs its AnimatedBuilder closure —
  // so resolving in the outer build silently pinned the pre-answer 0 forever.
  testWidgets('a sheet already on screen picks up a late radius', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showBubblesSheet<void>(context, title: 'Late', builder: (_) => const Text('body')),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    Radius bottomRadius() {
      final decorated = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .firstWhere(
            (d) => (d.decoration as BoxDecoration).borderRadius is BorderRadius,
          );
      return ((decorated.decoration as BoxDecoration).borderRadius! as BorderRadius).bottomLeft;
    }

    expect(bottomRadius(), Radius.zero, reason: 'nothing resolved yet');

    BubblesDeviceCornerRadius.setValueForTesting(62);
    await tester.pump();

    expect(bottomRadius().x, greaterThan(0), reason: 'the surface must re-read the radius, not cache it');
  });
}
