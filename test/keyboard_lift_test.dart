import 'package:bubbles_sheet/bubbles_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression test for a sheet with a text field being hidden behind the
/// software keyboard. [showBubblesSheet] must lift its content above the
/// keyboard inset so a bottom-anchored field or CTA stays reachable.
void main() {
  const screen = Size(400, 800);
  const keyboard = 300.0;
  final bottomKey = UniqueKey();

  testWidgets('sheet content stays above the keyboard when it opens', (tester) async {
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
                title: 'Add address',
                builder: (_) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const TextField(),
                    const SizedBox(height: 300),
                    Container(key: bottomKey, height: 48, width: double.infinity, color: Colors.red),
                  ],
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Sanity: the bottom marker is on-screen before the keyboard appears.
    expect(tester.getRect(find.byKey(bottomKey)).bottom, lessThanOrEqualTo(screen.height));

    // The keyboard appears.
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
    await tester.pumpAndSettle();

    // The marker must sit at or above the top edge of the keyboard.
    expect(tester.getRect(find.byKey(bottomKey)).bottom, lessThanOrEqualTo(screen.height - keyboard));
  });

  // Regression: saving an address pops the sheet while the autofocused field
  // still has the keyboard up. The keyboard then collapses over several frames
  // as the route exits and the SheetController is disposed. The viewport must
  // not reconstruct its SheetOffsetDrivenAnimation on those teardown rebuilds —
  // doing so calls addListener on the disposed controller and throws
  // "A SheetController was used after being disposed.", cascading into the
  // _dependents.isEmpty crash that takes down the app.
  testWidgets('popping the sheet while the keyboard is up tears down cleanly', (tester) async {
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
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showBubblesSheet<void>(
                context,
                title: 'Add address',
                dismissKeyboardOnDrag: true,
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

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Keyboard rises for the autofocused field.
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
    await tester.pumpAndSettle();

    // Save → pop while the keyboard is up, then collapse it across the exit so
    // the viewport rebuilds as the route finalizes and the controller is torn
    // down.
    nav.currentState!.pop();
    await tester.pump(const Duration(milliseconds: 120));
    tester.view.resetViewInsets();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 240));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
