import 'package:bubbles_sheet/bubbles_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The two headers are laid out differently — the modal one by
  // NavigationToolbar, the paged one by a Row — and NavigationToolbar hands its
  // leading slot a *tight* height. That overrode Container's own size and drew
  // the modal sheet's close button at 44pt against the paged sheet's 36pt, which
  // is visible the moment you open one sheet after the other.
  const expected = Size(36, 36);

  Finder circleOf(Finder button) => find.descendant(of: button, matching: find.byType(Container)).first;

  testWidgets('the modal sheet draws its close button at closeButtonSize', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showBubblesSheet<void>(
                context,
                title: 'Sort by',
                builder: (_) => const Text('body'),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.getSize(circleOf(find.bySemanticsLabel('Close'))), expected);
  });

  testWidgets('a trailing action does not change the close button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showBubblesSheet<void>(
                context,
                title: 'Filter',
                trailingAction: BubblesSheetAction(label: 'Clear', onTap: () {}),
                builder: (_) => const Text('body'),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.getSize(circleOf(find.bySemanticsLabel('Close'))), expected);
  });

  testWidgets('the paged header matches it', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BubblesPagedSheetHeader(title: 'Wallets', showClose: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Found by its label, not its widget type: the close control goes through
    // BubblesSheetThemeData.closeBuilder now, and what matters here is that
    // both headers still draw the same circle at the same size.
    expect(tester.getSize(circleOf(find.bySemanticsLabel('Close'))), expected);
  });

  testWidgets('the back button matches it too', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BubblesPagedSheetHeader(title: 'Wallet', showBack: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(circleOf(find.byType(BubblesPagedSheetCircleButton))), expected);
  });

  testWidgets('the tap target stays a full 44pt slot around the 36pt circle', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () =>
                  showBubblesSheet<void>(context, title: 'Sort by', builder: (_) => const Text('body')),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Shrinking the circle must not shrink what a thumb can hit.
    expect(tester.getSize(find.bySemanticsLabel('Close')), const Size(44, 44));
  });
}
