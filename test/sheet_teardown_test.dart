import 'package:bubbles_sheet/bubbles_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The sheet's [SheetController] must outlive the sheet subtree.
///
/// A sheet popped with the keyboard up spends its whole 360ms exit transition
/// still mounted, attached to the controller and relaying out as the keyboard
/// collapses. Disposing the controller when the route's future *completes* (the
/// start of that exit) leaves the live sheet driving a dead controller:
/// smooth_sheets defers a controller notification raised during layout to a
/// post-frame callback, and that callback then fires on the disposed controller
/// ("A SheetController was used after being disposed.").
void main() {
  const screen = Size(400, 800);
  const keyboard = 300.0;
  const exit = Duration(milliseconds: 360);

  tearDown(BubblesDeviceCornerRadius.resetForTesting);

  void sizeView(WidgetTester tester) {
    tester.view
      ..devicePixelRatio = 1.0
      ..physicalSize = screen;
    addTearDown(
      () => tester.view
        ..resetViewInsets()
        ..resetPhysicalSize()
        ..resetDevicePixelRatio(),
    );
  }

  Future<GlobalKey<NavigatorState>> pumpHost(
    WidgetTester tester, {
    List<BubblesSheetDetent> detents = const [BubblesSheetDetent.fit, BubblesSheetDetent.large],
  }) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showBubblesSheet<void>(
                context,
                title: 'Form',
                detents: detents,
                builder: (_) => const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [TextField(autofocus: true), SizedBox(height: 200)],
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    return nav;
  }

  Future<void> openWithKeyboard(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
    await tester.pumpAndSettle();
  }

  // Pops the sheet and starts collapsing the keyboard on the same frame, then
  // keeps collapsing it across the exit transition: the device sequence for a
  // tap on the close button (the pop unfocuses the field, which hides the
  // keyboard while the route is still exiting).
  Future<void> popAndCollapseKeyboard(WidgetTester tester, GlobalKey<NavigatorState> nav) async {
    nav.currentState!.pop();
    for (var i = 1; i <= 6; i++) {
      tester.view.viewInsets = FakeViewPadding(bottom: keyboard * (1 - i / 6));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(exit);
    await tester.pumpAndSettle();
  }

  testWidgets('keyboard collapsing during the exit does not touch a disposed controller', (tester) async {
    sizeView(tester);
    final nav = await pumpHost(tester);
    await openWithKeyboard(tester);

    await popAndCollapseKeyboard(tester, nav);

    expect(tester.takeException(), isNull);
    expect(find.byType(Sheet), findsNothing);
  });

  testWidgets('a second open and close cycle tears down cleanly too', (tester) async {
    sizeView(tester);
    final nav = await pumpHost(tester);

    for (var cycle = 0; cycle < 2; cycle++) {
      await openWithKeyboard(tester);
      expect(find.byType(Sheet), findsOneWidget, reason: 'cycle $cycle');
      await popAndCollapseKeyboard(tester, nav);
      expect(tester.takeException(), isNull, reason: 'cycle $cycle');
      expect(find.byType(Sheet), findsNothing, reason: 'cycle $cycle');
      expect(nav.currentState!.canPop(), isFalse, reason: 'cycle $cycle');
    }
  });

  testWidgets('a sheet parked at large keeps its flush bottom corners through the exit', (tester) async {
    // A non-zero device radius is what makes a corner jump observable at all.
    BubblesDeviceCornerRadius.setValueForTesting(62);
    sizeView(tester);
    final nav = await pumpHost(tester, detents: const [BubblesSheetDetent.large]);
    await openWithKeyboard(tester);

    // The surface paints and clips to one rounded rect; read its corners from
    // the clipper the way the render tree resolves them.
    BorderRadius surfaceCorners(Finder scope) {
      final clip = find.descendant(
        of: scope,
        matching: find.byWidgetPredicate(
          (w) => w is ClipRRect && w.clipper.runtimeType.toString() == '_SurfaceClipper',
        ),
      );
      final render = tester.renderObject<RenderClipRRect>(clip.first);
      final rrect = render.clipper!.getClip(render.size);
      return BorderRadius.only(
        topLeft: rrect.tlRadius,
        topRight: rrect.trRadius,
        bottomLeft: rrect.blRadius,
        bottomRight: rrect.brRadius,
      );
    }

    BorderRadius surfaceRadius() => surfaceCorners(find.byType(Sheet));

    final before = surfaceRadius();
    expect(before.bottomLeft, Radius.zero, reason: 'parked at the large detent the corners square off');

    nav.currentState!.pop();
    for (var i = 1; i <= 6; i++) {
      tester.view.viewInsets = FakeViewPadding(bottom: keyboard * (1 - i / 6));
      await tester.pump(const Duration(milliseconds: 40));
      expect(surfaceRadius(), before, reason: 'frame $i of the exit');
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
