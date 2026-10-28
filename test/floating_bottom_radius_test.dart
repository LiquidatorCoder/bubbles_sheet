import 'package:bubbles_sheet/bubbles_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// A floating sheet's bottom corners are concentric with the bezel
/// (`deviceRadius - inset`) but never tighter than the top corners, so a
/// square or unknown display does not strip the card's bottom curve.
void main() {
  tearDown(BubblesDeviceCornerRadius.resetForTesting);

  Radius bottomRadius(WidgetTester tester) {
    final clip = find.descendant(
      of: find.byWidgetPredicate((w) => w is Sheet || w is PagedSheet),
      matching: find.byWidgetPredicate((w) => w is ClipRRect && w.clipper.runtimeType.toString() == '_SurfaceClipper'),
    );
    final render = tester.renderObject<RenderClipRRect>(clip.first);
    return render.clipper!.getClip(render.size).blRadius;
  }

  Future<void> open(WidgetTester tester, void Function(BuildContext) show, {double? device}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: [BubblesSheetThemeData(metrics: BubblesSheetMetrics(deviceCornerRadius: device))],
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(onPressed: () => show(context), child: const Text('open')),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  void showFit(BuildContext c) => showBubblesSheet<void>(c, title: 'T', builder: (_) => const Text('body'));

  testWidgets('square display: floating bottom mirrors the top radius', (tester) async {
    BubblesDeviceCornerRadius.setValueForTesting(0);
    await open(tester, showFit);
    expect(bottomRadius(tester), const Radius.circular(32));
  });

  testWidgets('curved display: floating bottom stays concentric (55 - 16)', (tester) async {
    BubblesDeviceCornerRadius.setValueForTesting(55);
    await open(tester, showFit);
    expect(bottomRadius(tester), const Radius.circular(39));
  });

  testWidgets('square display: parked flush at large the bottom is square', (tester) async {
    BubblesDeviceCornerRadius.setValueForTesting(0);
    await open(
      tester,
      (c) => showBubblesSheet<void>(
        c,
        title: 'T',
        detents: const [BubblesSheetDetent.large],
        builder: (_) => const Text('body'),
      ),
    );
    expect(bottomRadius(tester), Radius.zero);
  });

  testWidgets('paged surface, square display: floating bottom mirrors the top', (tester) async {
    BubblesDeviceCornerRadius.setValueForTesting(0);
    await open(
      tester,
      (c) => showBubblesPagedSheet<void>(
        c,
        builder: (_) => const Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BubblesPagedSheetHeader(title: 'Page', showClose: true),
              SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
    expect(bottomRadius(tester), const Radius.circular(32));
  });
}
