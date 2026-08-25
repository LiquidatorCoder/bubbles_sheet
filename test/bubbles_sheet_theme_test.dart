import 'package:bubbles_sheet/bubbles_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BubblesSheetThemeData', () {
    testWidgets('falls back to the package defaults when nothing is registered', (tester) async {
      late BubblesSheetThemeData resolved;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              resolved = BubblesSheetThemeData.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(resolved, const BubblesSheetThemeData());
      expect(resolved.light, BubblesSheetPalette.cream);
    });

    test('paletteFor picks the palette from the flag, not the ambient brightness', () {
      const theme = BubblesSheetThemeData();
      expect(theme.paletteFor(dark: false), BubblesSheetPalette.cream);
      expect(theme.paletteFor(dark: true), BubblesSheetPalette.charcoal);
    });

    test('copyWith replaces only what it is given', () {
      const base = BubblesSheetThemeData();
      final next = base.copyWith(closeIcon: Icons.abc);

      expect(next.closeIcon, Icons.abc);
      expect(next.light, base.light);
      expect(next.metrics, base.metrics);
    });

    test('equality is by value, so a rebuilt identical theme does not churn', () {
      expect(const BubblesSheetThemeData(), const BubblesSheetThemeData());
      expect(const BubblesSheetThemeData().hashCode, const BubblesSheetThemeData().hashCode);
      expect(
        const BubblesSheetThemeData(metrics: BubblesSheetMetrics(inset: 8)),
        isNot(const BubblesSheetThemeData()),
      );
    });

    test('lerp interpolates palettes and snaps the things that cannot interpolate', () {
      const a = BubblesSheetThemeData();
      final b = a.copyWith(
        light: BubblesSheetPalette.cream.copyWith(surface: const Color(0xFF000000)),
        closeIcon: Icons.abc,
      );

      final quarter = a.lerp(b, 0.25);
      expect(quarter.closeIcon, a.closeIcon, reason: 'icons snap at the midpoint');
      expect(quarter.light.surface, isNot(a.light.surface));

      expect(a.lerp(b, 0.75).closeIcon, b.closeIcon);
      expect(a.lerp(null, 0.5), a, reason: 'a foreign extension leaves this one alone');
    });
  });

  group('BubblesSheetPalette', () {
    test('equality accounts for the shadow list', () {
      const a = BubblesSheetPalette.cream;
      final b = a.copyWith(surfaceShadow: const [BoxShadow(color: Color(0xFF000000))]);

      expect(a, a.copyWith());
      expect(a, isNot(b));
    });
  });
}
