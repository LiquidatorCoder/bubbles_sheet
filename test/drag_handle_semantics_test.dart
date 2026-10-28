import 'package:bubbles_sheet/bubbles_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

/// The drag handle is the sheet's grabber for assistive tech: it must not
/// claim a dismiss the sheet will not honour, and it must let a screen-reader
/// user step between detents the way a sighted user drags.
void main() {
  const screen = Size(400, 800);
  const bodyKey = Key('body');

  Future<SemanticsHandle> open(
    WidgetTester tester, {
    bool swipeDismissible = true,
    List<BubblesSheetDetent> detents = const [BubblesSheetDetent.fit, BubblesSheetDetent.large],
  }) async {
    final handle = tester.ensureSemantics();
    tester.view
      ..devicePixelRatio = 1.0
      ..physicalSize = screen;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showBubblesSheet<void>(
                context,
                detents: detents,
                swipeDismissible: swipeDismissible,
                barrierDismissible: swipeDismissible,
                builder: (_) => const SizedBox(key: bodyKey, height: 120, width: double.infinity),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return handle;
  }

  SemanticsNode grabber(WidgetTester tester) => tester.getSemantics(find.bySemanticsLabel('Sheet grabber'));

  bool has(WidgetTester tester, SemanticsAction action) => grabber(tester).getSemanticsData().hasAction(action);

  void perform(WidgetTester tester, SemanticsAction action) {
    tester.semantics.performAction(find.semantics.byLabel('Sheet grabber'), action);
  }

  double sheetTop(WidgetTester tester) => tester.getTopLeft(find.byKey(bodyKey)).dy;

  testWidgets('a locked sheet exposes no dismiss action and never says dismiss', (tester) async {
    final handle = await open(tester, swipeDismissible: false);

    final data = grabber(tester).getSemanticsData();
    expect(data.hasAction(SemanticsAction.dismiss), isFalse);
    expect('${data.label} ${data.hint}'.toLowerCase(), isNot(contains('dismiss')));
    handle.dispose();
  });

  testWidgets('a dismissible sheet pops when the dismiss action is performed', (tester) async {
    final handle = await open(tester);

    expect(has(tester, SemanticsAction.dismiss), isTrue);
    perform(tester, SemanticsAction.dismiss);
    await tester.pumpAndSettle();

    expect(find.byKey(bodyKey), findsNothing);
    handle.dispose();
  });

  testWidgets('increase and decrease step between the fit and large detents', (tester) async {
    final handle = await open(tester);
    final fitTop = sheetTop(tester);

    expect(has(tester, SemanticsAction.increase), isTrue);
    expect(has(tester, SemanticsAction.decrease), isFalse);

    perform(tester, SemanticsAction.increase);
    await tester.pumpAndSettle();
    final largeTop = sheetTop(tester);
    expect(largeTop, lessThan(fitTop - 100));
    expect(has(tester, SemanticsAction.increase), isFalse);
    expect(has(tester, SemanticsAction.decrease), isTrue);

    perform(tester, SemanticsAction.decrease);
    await tester.pumpAndSettle();
    expect(sheetTop(tester), closeTo(fitTop, 0.5));
    handle.dispose();
  });

  testWidgets('a single-detent sheet offers no resize actions', (tester) async {
    final handle = await open(tester, detents: const [BubblesSheetDetent.fit]);

    expect(has(tester, SemanticsAction.increase), isFalse);
    expect(has(tester, SemanticsAction.decrease), isFalse);
    handle.dispose();
  });
}
