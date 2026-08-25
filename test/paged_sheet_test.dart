import 'package:bubbles_sheet/bubbles_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression for the paged-sheet chrome. A page with a text field raises the
/// keyboard, and confirming pops the whole sheet while it's still up. As the keyboard collapses over the exit, the
/// viewport and surface relayout — they must not reconstruct their
/// [SheetOffsetDrivenAnimation] / [Listenable] on those teardown frames, or
/// `AnimatedBuilder.didUpdateWidget` calls addListener on the just-disposed
/// [SheetController] and throws "used after disposed", cascading into the
/// _dependents.isEmpty crash.
void main() {
  const screen = Size(400, 800);
  const keyboard = 300.0;

  testWidgets('paged sheet tears down cleanly when popped with the keyboard up', (tester) async {
    tester.view
      ..devicePixelRatio = 1.0
      ..physicalSize = screen;
    addTearDown(
      () => tester.view
        ..resetViewInsets()
        ..resetPhysicalSize()
        ..resetDevicePixelRatio(),
    );

    final nav = GlobalKey<NavigatorState>();

    void openSheet(BuildContext context) {
      // Mirrors showWalletSwitcherSheet / showManageWalletsSheet: a fresh
      // controller, BubblesPagedSheetViewport in the viewport, BubblesPagedSheetSurface as the
      // decoration, disposed synchronously on completion.
      final controller = SheetController();
      Navigator.of(context, rootNavigator: true)
          .push<void>(
            ModalSheetRoute<void>(
              transitionDuration: const Duration(milliseconds: 360),
              viewportBuilder: (ctx, child) => BubblesPagedSheetViewport(controller: controller, child: child),
              builder: (_) => Sheet(
                controller: controller,
                snapGrid: const SheetSnapGrid.single(snap: SheetOffset(1)),
                decoration: SheetDecorationBuilder(
                  size: SheetSize.stretch,
                  builder: (ctx, child) => BubblesPagedSheetSurface(controller: controller, child: child),
                ),
                child: const Material(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [TextField(autofocus: true), SizedBox(height: 200)],
                  ),
                ),
              ),
            ),
          )
          .whenComplete(controller.dispose);
    }

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(onPressed: () => openSheet(context), child: const Text('open')),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Keyboard rises for the autofocused field.
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
    await tester.pumpAndSettle();

    // Pop while the keyboard is up, then collapse it across the exit so the
    // viewport/surface relayout as the controller is disposed.
    nav.currentState!.pop();
    await tester.pump(const Duration(milliseconds: 120));
    tester.view.resetViewInsets();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 240));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
