import 'package:bubbles_sheet/bubbles_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// At a partial detent the sheet must float: a visible surface that ends at the
/// viewport bottom (the inset above the screen edge) with rounded corners, not
/// a box that runs off the bottom of the screen.
void main() {
  const screen = Size(400, 800);
  const inset = 16.0;

  setUp(() => BubblesDeviceCornerRadius.setValueForTesting(40));
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

  Widget host({
    required List<BubblesSheetDetent> detents,
    required Widget Function(BuildContext) builder,
    BubblesSheetDetent? initialDetent,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showBubblesSheet<void>(
              context,
              title: 'Sheet',
              detents: detents,
              initialDetent: initialDetent,
              builder: builder,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
  }

  Widget longList() => ListView.builder(
    itemCount: 40,
    itemBuilder: (_, i) => ListTile(title: Text('Row $i')),
  );

  /// The rounded rect the sheet's surface actually paints and clips to, in
  /// global coordinates.
  RRect surfaceClip(WidgetTester tester) {
    final surface = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_BubblesSheetSurface');
    final clip = find.descendant(of: surface, matching: find.byType(ClipRRect)).first;
    final render = tester.renderObject<RenderClipRRect>(clip);
    final local =
        render.clipper?.getClip(render.size) ??
        render.borderRadius.resolve(TextDirection.ltr).toRRect(Offset.zero & render.size);
    return local.shift(render.localToGlobal(Offset.zero));
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('medium detent floats: surface ends at the inset with rounded bottom corners', (tester) async {
    sizeView(tester);
    await tester.pumpWidget(
      host(
        detents: [BubblesSheetDetent.medium, BubblesSheetDetent.large],
        builder: (_) => longList(),
      ),
    );
    await open(tester);

    final clip = surfaceClip(tester);
    expect(clip.bottom, moreOrLessEquals(screen.height - inset, epsilon: 0.5));
    expect(clip.top, moreOrLessEquals((screen.height - inset) * 0.45, epsilon: 1.0));
    expect(clip.blRadiusX, greaterThan(0));
    expect(clip.brRadiusX, greaterThan(0));
    expect(clip.tlRadiusX, greaterThan(0));
  });

  testWidgets('nothing below the visible surface is tappable at medium', (tester) async {
    sizeView(tester);
    var taps = 0;
    final key = UniqueKey();
    // A body taller than medium, fully covered by one opaque tap target: any
    // part of the sheet box that outlives its visible surface is tappable.
    await tester.pumpWidget(
      host(
        detents: [BubblesSheetDetent.medium, BubblesSheetDetent.large],
        builder: (_) => GestureDetector(
          key: key,
          behavior: HitTestBehavior.opaque,
          onTap: () => taps++,
          child: const SizedBox(height: 900, width: double.infinity),
        ),
      ),
    );
    await open(tester);

    expect(find.byKey(key), findsOneWidget);
    // Sanity: inside the visible surface the target does receive taps.
    await tester.tapAt(Offset(200, screen.height * 0.7));
    await tester.pump();
    expect(taps, 1);
    taps = 0;
    // The inset strip under the visible sheet belongs to the barrier.
    await tester.tapAt(Offset(200, screen.height - 8));
    await tester.pump();
    expect(taps, 0);
  });

  testWidgets('fit sheet geometry: floats on the inset, rounded on all corners', (tester) async {
    sizeView(tester);
    await tester.pumpWidget(
      host(
        detents: [BubblesSheetDetent.fit, BubblesSheetDetent.large],
        builder: (_) => const SizedBox(height: 200, width: double.infinity),
      ),
    );
    await open(tester);

    final clip = surfaceClip(tester);
    expect(clip.bottom, moreOrLessEquals(screen.height - inset, epsilon: 0.5));
    expect(clip.left, moreOrLessEquals(inset, epsilon: 0.5));
    expect(clip.right, moreOrLessEquals(screen.width - inset, epsilon: 0.5));
    expect(clip.height, moreOrLessEquals(274, epsilon: 0.5));
    expect(clip.blRadiusX, greaterThan(0));
  });

  testWidgets('large detent stays flush with square bottom corners', (tester) async {
    sizeView(tester);
    await tester.pumpWidget(
      host(
        detents: [BubblesSheetDetent.medium, BubblesSheetDetent.large],
        initialDetent: BubblesSheetDetent.large,
        builder: (_) => longList(),
      ),
    );
    await open(tester);

    final clip = surfaceClip(tester);
    expect(clip.bottom, moreOrLessEquals(screen.height, epsilon: 0.5));
    expect(clip.left, moreOrLessEquals(0, epsilon: 0.5));
    expect(clip.right, moreOrLessEquals(screen.width, epsilon: 0.5));
    expect(clip.blRadiusX, 0);
    expect(clip.brRadiusX, 0);
  });

  testWidgets('dragging below the lowest detent slides the sheet without shrinking it', (tester) async {
    sizeView(tester);
    await tester.pumpWidget(
      host(
        detents: [BubblesSheetDetent.medium, BubblesSheetDetent.large],
        builder: (_) => longList(),
      ),
    );
    await open(tester);

    final rest = surfaceClip(tester);
    final gesture = await tester.startGesture(tester.getCenter(find.text('Sheet')));
    await gesture.moveBy(const Offset(0, 60));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 60));
    await tester.pump();

    final dragged = surfaceClip(tester);
    expect(dragged.top, greaterThan(rest.top + 20));
    expect(dragged.height, moreOrLessEquals(rest.height, epsilon: 0.5));
    expect(dragged.blRadiusX, greaterThan(0));

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('dragging between detents repaints the surface without rebuilding it', (tester) async {
    sizeView(tester);
    await tester.pumpWidget(
      host(
        detents: [BubblesSheetDetent.medium, BubblesSheetDetent.large],
        builder: (_) => longList(),
      ),
    );
    await open(tester);

    // Counts rebuilds of the surface and the widgets it builds around the sheet
    // (not the sheet's own chrome, which tracks the offset by design). The drag
    // stays under the flush threshold (0.6 of the viewport): past it the
    // route's inset animates, which re-lays the whole sheet out by design.
    const surfaceWidgets = {
      '_BubblesSheetSurface',
      'BubblesSheetSurfaceBox',
      'AnimatedBuilder',
      'DecoratedBox',
      'CustomPaint',
      'ClipRRect',
    };
    var builds = 0;
    final previous = debugOnRebuildDirtyWidget;
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      if (!surfaceWidgets.contains(element.widget.runtimeType.toString())) return;
      var inSurface = element.widget.runtimeType.toString() == '_BubblesSheetSurface';
      element.visitAncestorElements((ancestor) {
        if (ancestor.widget.runtimeType.toString() == '_BubblesSheetSurface') inSurface = true;
        return !inSurface;
      });
      if (inSurface) builds++;
    };
    addTearDown(() => debugOnRebuildDirtyWidget = previous);

    final before = surfaceClip(tester);
    final gesture = await tester.startGesture(tester.getCenter(find.text('Sheet')));
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(const Offset(0, -4));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(surfaceClip(tester).top, lessThan(before.top - 20), reason: 'the drag must actually move the sheet');
    expect(builds, 0);

    await gesture.up();
    await tester.pumpAndSettle();
  });
}
