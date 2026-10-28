import 'dart:async';

import 'package:bubbles_sheet/bubbles_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins `showBubblesPagedSheet`: the same lifecycle guarantees as
/// `showBubblesSheet` for a multi-page flow, and a header close that pops the
/// route hosting the sheet rather than whatever the root navigator shows.
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

  Widget secondPage() => const Material(
    color: Colors.transparent,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BubblesPagedSheetHeader(title: 'Second', showBack: true),
        SizedBox(height: 160),
      ],
    ),
  );

  Widget firstPage({bool field = false}) => Builder(
    builder: (context) => Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BubblesPagedSheetHeader(title: 'First', showClose: true),
          if (field) const TextField(autofocus: true),
          ElevatedButton(
            onPressed: () => Navigator.of(context).push(PagedSheetRoute<void>(builder: (_) => secondPage())),
            child: const Text('next'),
          ),
          const SizedBox(height: 120),
        ],
      ),
    ),
  );

  Future<GlobalKey<NavigatorState>> pumpHost(
    WidgetTester tester, {
    bool field = false,
    bool barrierDismissible = true,
    bool swipeDismissible = true,
    List<Object?>? results,
  }) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => unawaited(
                showBubblesPagedSheet<Object?>(
                  context,
                  barrierDismissible: barrierDismissible,
                  swipeDismissible: swipeDismissible,
                  builder: (_) => firstPage(field: field),
                ).then((v) => results?.add(v)),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    return nav;
  }

  Finder closeButton() => find.byWidgetPredicate((w) => w is Icon && w.icon == const BubblesSheetThemeData().closeIcon);

  testWidgets('opens, pushes a page, goes back and closes; a second cycle works', (tester) async {
    sizeView(tester);
    final nav = await pumpHost(tester);

    for (var cycle = 0; cycle < 2; cycle++) {
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('First'), findsOneWidget, reason: 'cycle $cycle');

      await tester.tap(find.text('next'));
      await tester.pumpAndSettle();
      expect(find.text('Second'), findsOneWidget, reason: 'cycle $cycle');

      await tester.tap(find.byIcon(const BubblesSheetThemeData().backIcon));
      await tester.pumpAndSettle();
      expect(find.text('Second'), findsNothing, reason: 'cycle $cycle');
      expect(find.text('First'), findsOneWidget, reason: 'cycle $cycle');

      await tester.tap(closeButton());
      await tester.pumpAndSettle();
      expect(find.byType(PagedSheet), findsNothing, reason: 'cycle $cycle');
      expect(nav.currentState!.canPop(), isFalse, reason: 'cycle $cycle');
      expect(tester.takeException(), isNull, reason: 'cycle $cycle');
    }
  });

  testWidgets('popping with the keyboard up and collapsing it over the exit does not touch a disposed controller', (
    tester,
  ) async {
    sizeView(tester);
    final nav = await pumpHost(tester, field: true);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
    await tester.pumpAndSettle();

    nav.currentState!.pop();
    for (var i = 1; i <= 6; i++) {
      tester.view.viewInsets = FakeViewPadding(bottom: keyboard * (1 - i / 6));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(exit);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(PagedSheet), findsNothing);
  });

  testWidgets('header close pops the sheet on a nested navigator, not the root one', (tester) async {
    sizeView(tester);
    final rootNav = GlobalKey<NavigatorState>();
    final innerNav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: rootNav,
        home: Scaffold(
          body: Navigator(
            key: innerNav,
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                body: Builder(
                  builder: (context) => Column(
                    children: [
                      const Text('nested page'),
                      ElevatedButton(
                        onPressed: () => unawaited(
                          showBubblesPagedSheet<void>(context, useRootNavigator: false, builder: (_) => firstPage()),
                        ),
                        child: const Text('open'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('First'), findsOneWidget);
    expect(innerNav.currentState!.canPop(), isTrue, reason: 'the sheet sits on the nested navigator');
    expect(rootNav.currentState!.canPop(), isFalse);

    await tester.tap(closeButton());
    await tester.pumpAndSettle();

    expect(find.byType(PagedSheet), findsNothing);
    expect(find.text('nested page'), findsOneWidget);
    expect(innerNav.currentState!.canPop(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the barrier dismisses, and barrierDismissible: false holds', (tester) async {
    sizeView(tester);
    await pumpHost(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();
    expect(find.byType(PagedSheet), findsNothing);

    await pumpHost(tester, barrierDismissible: false);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();
    expect(find.byType(PagedSheet), findsOneWidget);
  });

  Future<void> dragTitleDown(WidgetTester tester) async {
    const stepMs = 10;
    final gesture = await tester.startGesture(tester.getCenter(find.text('First')));
    for (var i = 1; i <= 50; i++) {
      await tester.pump(const Duration(milliseconds: stepMs));
      await gesture.moveBy(const Offset(0, 8), timeStamp: Duration(milliseconds: stepMs * i));
    }
    await gesture.up(timeStamp: const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  testWidgets('swiping down dismisses, and swipeDismissible: false holds', (tester) async {
    sizeView(tester);
    await pumpHost(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await dragTitleDown(tester);
    expect(find.byType(PagedSheet), findsNothing);

    await pumpHost(tester, swipeDismissible: false);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await dragTitleDown(tester);
    expect(find.byType(PagedSheet), findsOneWidget);
  });
}
