import 'package:bubbles_sheet/bubbles_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Pumps an app whose single button opens a sheet built by [open].
  Future<void> pumpHost(WidgetTester tester, void Function(BuildContext) open, {BubblesSheetThemeData? theme}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme == null ? null : ThemeData.light().copyWith(extensions: [theme]),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(onPressed: () => open(context), child: const Text('open')),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('renders the title and the body', (tester) async {
    await pumpHost(tester, (context) {
      showBubblesSheet<void>(context, title: 'Sort by', builder: (_) => const Text('body'));
    });

    expect(find.text('Sort by'), findsOneWidget);
    expect(find.text('body'), findsOneWidget);
  });

  testWidgets('the close button pops the sheet and fires the dismiss haptic', (tester) async {
    var dismissed = 0;
    await pumpHost(
      tester,
      (context) => showBubblesSheet<void>(context, title: 'Sort by', builder: (_) => const Text('body')),
      theme: BubblesSheetThemeData(haptics: BubblesSheetHaptics(onDismiss: () => dismissed++)),
    );

    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();

    expect(dismissed, 1);
    expect(find.text('body'), findsNothing);
  });

  testWidgets('showBubblesSheet fires the present haptic', (tester) async {
    var presented = 0;
    await pumpHost(
      tester,
      (context) => showBubblesSheet<void>(context, builder: (_) => const Text('body')),
      theme: BubblesSheetThemeData(haptics: BubblesSheetHaptics(onPresent: () => presented++)),
    );

    expect(presented, 1);
  });

  testWidgets('the trailing action renders in the header and fires', (tester) async {
    var cleared = 0;
    await pumpHost(tester, (context) {
      showBubblesSheet<void>(
        context,
        title: 'Filter',
        trailingAction: BubblesSheetAction(label: 'Clear', onTap: () => cleared++),
        builder: (_) => const Text('body'),
      );
    });

    expect(find.text('Clear'), findsOneWidget);
    await tester.tap(find.text('Clear'));
    expect(cleared, 1);
  });

  testWidgets('a disabled trailing action does not fire', (tester) async {
    var cleared = 0;
    await pumpHost(tester, (context) {
      showBubblesSheet<void>(
        context,
        title: 'Filter',
        trailingAction: BubblesSheetAction(label: 'Clear', enabled: false, onTap: () => cleared++),
        builder: (_) => const Text('body'),
      );
    });

    await tester.tap(find.text('Clear'));
    expect(cleared, 0);
  });

  testWidgets('the title stays centered when a trailing action widens the row', (tester) async {
    await pumpHost(tester, (context) {
      showBubblesSheet<void>(
        context,
        title: 'Filter',
        trailingAction: BubblesSheetAction(label: 'Reset everything', onTap: () {}),
        builder: (_) => const Text('body'),
      );
    });

    final screen = tester.getSize(find.byType(MaterialApp)).width;
    final title = tester.getCenter(find.text('Filter'));
    expect(title.dx, moreOrLessEquals(screen / 2, epsilon: 1));
  });

  testWidgets('the CTA rebuilds from its listenable without rebuilding the body', (tester) async {
    final count = ValueNotifier<int>(0);
    var bodyBuilds = 0;
    addTearDown(count.dispose);

    await pumpHost(tester, (context) {
      showBubblesSheet<void>(
        context,
        primaryCtaListenable: count,
        primaryCtaBuilder: (_) => BubblesSheetCta(title: 'Apply ${count.value}', onTap: () {}),
        builder: (_) {
          bodyBuilds++;
          return const Text('body');
        },
      );
    });

    expect(find.text('Apply 0'), findsOneWidget);
    final buildsBefore = bodyBuilds;

    count.value = 3;
    await tester.pump();

    expect(find.text('Apply 3'), findsOneWidget);
    expect(bodyBuilds, buildsBefore);
  });

  testWidgets('tapping the CTA runs its callback', (tester) async {
    var applied = 0;
    await pumpHost(tester, (context) {
      showBubblesSheet<void>(
        context,
        primaryCta: BubblesSheetCta(title: 'Apply', onTap: () => applied++),
        builder: (_) => const Text('body'),
      );
    });

    await tester.tap(find.text('Apply'));
    expect(applied, 1);
  });

  testWidgets('a disabled CTA does not fire', (tester) async {
    var applied = 0;
    await pumpHost(tester, (context) {
      showBubblesSheet<void>(
        context,
        primaryCta: BubblesSheetCta(title: 'Apply', enabled: false, onTap: () => applied++),
        builder: (_) => const Text('body'),
      );
    });

    await tester.tap(find.text('Apply'));
    expect(applied, 0);
  });

  testWidgets('ctaBuilder replaces the stock pill', (tester) async {
    await pumpHost(
      tester,
      (context) => showBubblesSheet<void>(
        context,
        primaryCta: BubblesSheetCta(title: 'Apply', onTap: () {}),
        builder: (_) => const Text('body'),
      ),
      theme: BubblesSheetThemeData(ctaBuilder: (context, cta) => Text('custom:${cta.title}')),
    );

    expect(find.text('custom:Apply'), findsOneWidget);
  });

  testWidgets('showCloseButton and showDragHandle strip the chrome', (tester) async {
    await pumpHost(tester, (context) {
      showBubblesSheet<void>(
        context,
        showCloseButton: false,
        showDragHandle: false,
        builder: (_) => const Text('body'),
      );
    });

    expect(find.bySemanticsLabel('Close'), findsNothing);
    expect(find.bySemanticsLabel('Drag to dismiss'), findsNothing);
    expect(find.text('body'), findsOneWidget);
  });

  testWidgets('the sheet resolves to the value it is popped with', (tester) async {
    String? result;
    await pumpHost(tester, (context) {
      showBubblesSheet<String>(
        context,
        builder: (sheetContext) => ElevatedButton(
          onPressed: () => Navigator.of(sheetContext).pop('picked'),
          child: const Text('pick'),
        ),
      ).then((value) => result = value);
    });

    await tester.tap(find.text('pick'));
    await tester.pumpAndSettle();

    expect(result, 'picked');
  });

  testWidgets('dark selects the dark palette for the chrome', (tester) async {
    await pumpHost(
      tester,
      (context) => showBubblesSheet<void>(context, title: 'Dark', dark: true, builder: (_) => const Text('body')),
      theme: const BubblesSheetThemeData(
        light: BubblesSheetPalette.cream,
        dark: BubblesSheetPalette.charcoal,
      ),
    );

    final title = tester.widget<Text>(find.text('Dark'));
    expect(title.style?.color, BubblesSheetPalette.charcoal.title);
  });
}
