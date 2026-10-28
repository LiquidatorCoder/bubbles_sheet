import 'dart:math' as math;

import 'package:bubbles_sheet/bubbles_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Opaque colour of [fg] (which may carry alpha) composited over [bg].
Color _over(Color fg, Color bg) => Color.alphaBlend(fg, bg);

void main() {
  Future<void> openSheet(
    WidgetTester tester, {
    required ThemeData appTheme,
    required bool dark,
    required bool enabled,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showBubblesSheet<void>(
                  context,
                  dark: dark,
                  title: 'Sort by',
                  primaryCta: BubblesSheetCta(title: 'Done', enabled: enabled, onTap: enabled ? () {} : null),
                  builder: (_) => const SizedBox(height: 80),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Color labelColor(WidgetTester tester) => tester.widget<Text>(find.text('Done')).style!.color!;

  Color pillColor(WidgetTester tester) {
    final container = tester.widget<AnimatedContainer>(
      find.ancestor(of: find.text('Done'), matching: find.byType(AnimatedContainer)),
    );
    return (container.decoration! as BoxDecoration).color!;
  }

  testWidgets('disabled CTA on a dark sheet in a light app contrasts with the charcoal surface', (tester) async {
    await openSheet(tester, appTheme: ThemeData.light(), dark: true, enabled: false);
    final surface = BubblesSheetPalette.charcoal.surface;

    expect(_contrast(_over(labelColor(tester), surface), surface), greaterThanOrEqualTo(3));
    // The pill is derived from the same palette title colour, not the app's black.
    expect(pillColor(tester).withValues(alpha: 1), BubblesSheetPalette.charcoal.title);
  });

  testWidgets('disabled CTA on a light sheet in a dark app contrasts with the cream surface', (tester) async {
    await openSheet(tester, appTheme: ThemeData.dark(), dark: false, enabled: false);
    final surface = BubblesSheetPalette.cream.surface;

    // A disabled label is title@38% by design, which tops out near 2.5:1 on
    // cream (the same a light app gets today); the bug was ~1:1 (near-white).
    expect(_contrast(_over(labelColor(tester), surface), surface), greaterThanOrEqualTo(2.4));
    expect(pillColor(tester).withValues(alpha: 1), BubblesSheetPalette.cream.title);
  });

  testWidgets('the enabled CTA keeps the app primary and onPrimary', (tester) async {
    final app = ThemeData.light();
    await openSheet(tester, appTheme: app, dark: true, enabled: true);

    expect(pillColor(tester), app.colorScheme.primary);
    expect(labelColor(tester), app.colorScheme.onPrimary);
  });
}
