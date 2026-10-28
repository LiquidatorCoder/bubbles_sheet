import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:bubbles_sheet_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

late IntegrationTestWidgetsFlutterBinding binding;

/// Pumps until nothing is scheduled any more, capped at 3 s.
Future<void> settle(WidgetTester tester) async {
  final clock = Stopwatch()..start();
  await tester.pump(const Duration(milliseconds: 16));
  while (clock.elapsedMilliseconds < 3000) {
    final scheduler = SchedulerBinding.instance;
    if (!scheduler.hasScheduledFrame && scheduler.transientCallbackCount == 0) break;
    await tester.pump(const Duration(milliseconds: 16));
  }
}

double _percentile(List<double> sorted, double p) {
  if (sorted.isEmpty) return 0;
  return sorted[math.min(sorted.length - 1, (sorted.length * p).ceil() - 1)];
}

double _round(double v) => (v * 100).round() / 100;

/// Runs [action], collecting frame timings and wall latency, and prints one
/// `PERF {json}` line.
Future<void> measure(String name, Future<void> Function() action) async {
  final timings = <FrameTiming>[];
  void collect(List<FrameTiming> batch) => timings.addAll(batch);
  SchedulerBinding.instance.addTimingsCallback(collect);
  final wall = Stopwatch()..start();
  try {
    await action();
  } finally {
    wall.stop();
    // Timings are delivered in batches a little after the frames land.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    SchedulerBinding.instance.removeTimingsCallback(collect);
  }
  final build = timings.map((t) => t.buildDuration.inMicroseconds / 1000).toList()..sort();
  final raster = timings.map((t) => t.rasterDuration.inMicroseconds / 1000).toList()..sort();
  double avg(List<double> v) => v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;
  final over = timings.where((t) => (t.buildDuration + t.rasterDuration).inMicroseconds > 16700).length;
  final data = <String, Object>{
    'name': name,
    'frames': timings.length,
    'build_avg_ms': _round(avg(build)),
    'build_p90_ms': _round(_percentile(build, 0.9)),
    'build_max_ms': _round(build.isEmpty ? 0 : build.last),
    'raster_avg_ms': _round(avg(raster)),
    'raster_p90_ms': _round(_percentile(raster, 0.9)),
    'raster_max_ms': _round(raster.isEmpty ? 0 : raster.last),
    'frames_over_16_7ms': over,
    'wall_ms': wall.elapsedMilliseconds,
  };
  // The suite's output is read from the console, so print is the point.
  // ignore: avoid_print
  print('PERF ${jsonEncode(data)}');
  (binding.reportData ??= <String, dynamic>{})[name] = data;
}

final Finder _close = find.byIcon(Icons.close_rounded);
final Finder _back = find.byIcon(Icons.arrow_back_ios_new_rounded);

Future<void> launch(WidgetTester tester) async {
  await tester.pumpWidget(const ExampleApp());
  await settle(tester);
}

Future<void> openSheet(WidgetTester tester, String slug, Finder anchor) async {
  final button = find.byKey(ValueKey('demo-$slug'));
  await tester.ensureVisible(button);
  await settle(tester);
  await measure('$slug/open', () async {
    await tester.tap(button);
    await settle(tester);
  });
  expect(anchor, findsOneWidget, reason: '$slug sheet should be on screen');
}

Future<void> closeSheet(WidgetTester tester, String slug, Finder anchor) async {
  await measure('$slug/dismiss', () async {
    await tester.tap(_close);
    await settle(tester);
  });
  expect(anchor, findsNothing, reason: '$slug sheet should be gone');
}

Future<void> tapBarrier(WidgetTester tester) async {
  await tester.tapAt(Offset(tester.view.physicalSize.width / tester.view.devicePixelRatio / 2, 60));
  await settle(tester);
}

void expectResult(String value) {
  expect((find.byKey(const ValueKey('last-result')).evaluate().single.widget as Text).data, 'result: $value');
}

void expectClean(WidgetTester tester) => expect(tester.takeException(), isNull);

/// Top of the sheet's header, a proxy for the sheet's current height.
double sheetTop(WidgetTester tester, Finder anchor) => tester.getTopLeft(anchor).dy;

Future<void> dragBy(WidgetTester tester, String name, Finder from, Offset by) async {
  await measure(name, () async {
    await tester.timedDrag(from, by, const Duration(milliseconds: 400));
    await settle(tester);
  });
}

String fieldText(WidgetTester tester, String key) => tester
    .widget<EditableText>(find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(EditableText)))
    .controller
    .text;

void main() {
  binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('fit-large: drag up and down, dismiss via barrier', (tester) async {
    await launch(tester);
    final title = find.text('Sort by');
    await openSheet(tester, 'fit-large', title);
    final fitTop = sheetTop(tester, _close);
    await dragBy(tester, 'fit-large/drag-fit-to-large', _close, const Offset(0, -600));
    final largeTop = sheetTop(tester, _close);
    expect(largeTop, lessThan(fitTop), reason: 'sheet should grow when dragged up');
    await dragBy(tester, 'fit-large/drag-large-to-fit', _close, const Offset(0, 300));
    expect(title, findsOneWidget);
    expect(sheetTop(tester, _close), greaterThan(largeTop), reason: 'sheet should shrink when dragged down');
    await measure('fit-large/dismiss-barrier', () => tapBarrier(tester));
    expect(title, findsNothing);
    expectResult('null');
    expectClean(tester);
  });

  testWidgets('three-detents: opens at medium, fling at large, close', (tester) async {
    await launch(tester);
    final title = find.text('Tokens');
    await openSheet(tester, 'three-detents', title);
    final mediumTop = sheetTop(tester, _close);
    await dragBy(tester, 'three-detents/drag-medium-to-large', _close, const Offset(0, -700));
    expect(sheetTop(tester, _close), lessThan(mediumTop));
    final list = find.byType(ListView);
    await measure('three-detents/fling-large', () async {
      await tester.fling(list, const Offset(0, -500), 2500);
      await settle(tester);
    });
    expect(find.text('Token 0'), findsNothing, reason: 'list should have scrolled');
    await tester.fling(list, const Offset(0, 800), 3000);
    await settle(tester);
    await closeSheet(tester, 'three-detents', title);
    expectResult('null');
    expectClean(tester);
  });

  testWidgets('live-cta: CTA follows state and pops an int', (tester) async {
    await launch(tester);
    final title = find.text('Pick a number');
    await openSheet(tester, 'live-cta', title);
    expect(find.text('Pick one'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('live-cta-chip-3')));
    await settle(tester);
    expect(find.text('Apply 3'), findsOneWidget);
    await tester.tap(find.text('Clear'));
    await settle(tester);
    expect(find.text('Pick one'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('live-cta-chip-4')));
    await settle(tester);
    await measure('live-cta/dismiss-cta', () async {
      await tester.tap(find.text('Apply 4'));
      await settle(tester);
    });
    expect(title, findsNothing);
    expectResult('4');
    expectClean(tester);
  });

  testWidgets('dark: Done pops', (tester) async {
    await launch(tester);
    final title = find.text('Sort by');
    await openSheet(tester, 'dark', title);
    await measure('dark/dismiss-cta', () async {
      await tester.tap(find.text('Done'));
      await settle(tester);
    });
    expect(title, findsNothing);
    expectResult('null');
    expectClean(tester);
  });

  testWidgets('form: keyboard, CTA gating, field values', (tester) async {
    await launch(tester);
    final title = find.text('Profile');
    await openSheet(tester, 'form', title);
    // Save is disabled until the name has text: tapping it must not pop.
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(title, findsOneWidget);
    await measure('form/keyboard-focus', () async {
      await tester.tap(find.byKey(const ValueKey('form-field-0')));
      await settle(tester);
    });
    // Console output is the point here.
    // ignore: avoid_print
    print('INFO form keyboard viewInsets.bottom=${tester.view.viewInsets.bottom} (physical px)');
    await tester.enterText(find.byKey(const ValueKey('form-field-0')), 'Ada');
    await settle(tester);
    await tester.enterText(find.byKey(const ValueKey('form-field-1')), 'ada@example.com');
    await tester.enterText(find.byKey(const ValueKey('form-field-2')), 'hello');
    await tester.enterText(find.byKey(const ValueKey('form-field-3')), 'line one\nline two\nline three');
    await settle(tester);
    expect(fieldText(tester, 'form-field-0'), 'Ada');
    expect(fieldText(tester, 'form-field-1'), 'ada@example.com');
    expect(fieldText(tester, 'form-field-2'), 'hello');
    expect(fieldText(tester, 'form-field-3'), 'line one\nline two\nline three');
    await measure('form/keyboard-dismiss', () async {
      FocusManager.instance.primaryFocus?.unfocus();
      await settle(tester);
    });
    await measure('form/dismiss-cta', () async {
      await tester.tap(find.text('Save'));
      await settle(tester);
    });
    expect(title, findsNothing);
    expectResult('null');
    expectClean(tester);
  });

  testWidgets('form-autofocus: field focused on open, Add pops', (tester) async {
    await launch(tester);
    final field = find.byKey(const ValueKey('form-autofocus-field-0'));
    await openSheet(tester, 'form-autofocus', field);
    final editable = tester.state<EditableTextState>(find.descendant(of: field, matching: find.byType(EditableText)));
    expect(editable.widget.focusNode.hasFocus, isTrue, reason: 'autofocus should focus the field');
    await tester.enterText(field, 'milk');
    await settle(tester);
    expect(fieldText(tester, 'form-autofocus-field-0'), 'milk');
    // Put the keyboard away before tapping the CTA, so the tap measures the
    // dismiss itself rather than a keyboard collapsing underneath it.
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);
    // `settle` can return while the platform is still animating the keyboard
    // away, so wait for the inset itself to reach zero.
    for (var i = 0; i < 100 && tester.view.viewInsets.bottom > 0; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    await settle(tester);
    await measure('form-autofocus/dismiss-cta', () async {
      await tester.tap(find.text('Add'));
      await settle(tester);
    });
    expect(field, findsNothing);
    expectResult('null');
    expectClean(tester);
  });

  testWidgets(
    'form-autofocus: CTA stays above the keyboard',
    (tester) async {
      await launch(tester);
      await openSheet(tester, 'form-autofocus', find.byKey(const ValueKey('form-autofocus-field-0')));
      final keyboardTop =
          (tester.view.physicalSize.height - tester.view.viewInsets.bottom) / tester.view.devicePixelRatio;
      expect(tester.view.viewInsets.bottom, greaterThan(0), reason: 'software keyboard should be up');
      expect(tester.getBottomLeft(find.text('Add')).dy, lessThanOrEqualTo(keyboardTop));
    },
  );

  testWidgets('form-autofocus: barrier tap with keyboard up tears down cleanly', (tester) async {
    await launch(tester);
    final field = find.byKey(const ValueKey('form-autofocus-field-0'));
    await openSheet(tester, 'form-autofocus', field);
    await tapBarrier(tester);
    await settle(tester);
    expect(field, findsNothing);
    expectClean(tester);
  });

  testWidgets('fit-only: swipe down dismisses', (tester) async {
    await launch(tester);
    final content = find.byKey(const ValueKey('fit-only-text'));
    await openSheet(tester, 'fit-only', content);
    await measure('fit-only/dismiss-swipe', () async {
      await tester.fling(_close, const Offset(0, 500), 2500);
      await settle(tester);
    });
    expect(content, findsNothing);
    expectResult('null');
    expectClean(tester);
  });

  testWidgets('long-fit: content taller than the screen scrolls at large', (tester) async {
    await launch(tester);
    final content = find.byKey(const ValueKey('long-fit-row-0'));
    await openSheet(tester, 'long-fit', content);
    await dragBy(tester, 'long-fit/drag-fit-to-large', _close, const Offset(0, -700));
    await measure('long-fit/scroll-to-end', () async {
      await tester.fling(find.byType(SingleChildScrollView).last, const Offset(0, -2000), 4000);
      await settle(tester);
    });
    expect(find.byKey(const ValueKey('long-fit-row-29')), findsOneWidget, reason: 'last row should be reachable');
    await closeSheet(tester, 'long-fit', content);
    expectClean(tester);
  });

  testWidgets('large-list: scroll then drag hands off to the sheet', (tester) async {
    await launch(tester);
    final list = find.byKey(const ValueKey('large-list-list'));
    await openSheet(tester, 'large-list', list);
    final topAtLarge = sheetTop(tester, _close);
    await measure('large-list/fling', () async {
      await tester.fling(list, const Offset(0, -600), 3000);
      await settle(tester);
    });
    expect(find.byKey(const ValueKey('large-list-row-0')), findsNothing);
    await tester.fling(list, const Offset(0, 3000), 6000);
    await settle(tester);
    expect(find.byKey(const ValueKey('large-list-row-0')), findsOneWidget);
    // Hold the finger down: after release the sheet may legitimately snap back
    // to large, so the handoff is only visible mid-drag.
    final gesture = await tester.startGesture(tester.getCenter(list));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 25));
      await tester.pump(const Duration(milliseconds: 16));
    }
    final midDragTop = sheetTop(tester, _close);
    await gesture.up();
    await settle(tester);
    expect(midDragTop, greaterThan(topAtLarge), reason: 'dragging down at the top of the list should move the sheet');
    await dragBy(tester, 'large-list/drag-handoff-up', list, const Offset(0, -600));
    await closeSheet(tester, 'large-list', list);
    expectClean(tester);
  });

  testWidgets('grow: fit detent follows live content', (tester) async {
    await launch(tester);
    final anchor = find.byKey(const ValueKey('grow-add'));
    await openSheet(tester, 'grow', anchor);
    final before = sheetTop(tester, _close);
    await measure('grow/add-rows', () async {
      for (var i = 0; i < 4; i++) {
        await tester.tap(anchor);
        await settle(tester);
      }
    });
    expect(find.byKey(const ValueKey('grow-row-5')), findsOneWidget);
    expect(sheetTop(tester, _close), lessThan(before), reason: 'fit sheet should grow with its content');
    final grown = sheetTop(tester, _close);
    await measure('grow/remove-rows', () async {
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const ValueKey('grow-remove')));
        await settle(tester);
      }
    });
    expect(find.byKey(const ValueKey('grow-row-5')), findsNothing);
    expect(sheetTop(tester, _close), greaterThan(grown), reason: 'fit sheet should shrink with its content');
    await closeSheet(tester, 'grow', anchor);
    expectClean(tester);
  });

  testWidgets('locked: only the CTA closes it', (tester) async {
    await launch(tester);
    final text = find.byKey(const ValueKey('locked-text'));
    await openSheet(tester, 'locked', text);
    expect(_close, findsNothing);
    await tapBarrier(tester);
    expect(text, findsOneWidget, reason: 'barrier tap must not dismiss');
    await tester.timedDrag(text, const Offset(0, 500), const Duration(milliseconds: 400));
    await settle(tester);
    expect(text, findsOneWidget, reason: 'swipe must not dismiss');
    await measure('locked/dismiss-cta', () async {
      await tester.tap(find.text('Close'));
      await settle(tester);
    });
    expect(text, findsNothing);
    expectResult('null');
    expectClean(tester);
  });

  testWidgets('footer: Cancel and Delete pop; disabled action is inert', (tester) async {
    await launch(tester);
    final text = find.byKey(const ValueKey('footer-text'));
    await openSheet(tester, 'footer', text);
    await tester.tap(find.text('Edit'));
    await settle(tester);
    expect(text, findsOneWidget);
    await measure('footer/dismiss-cancel', () async {
      await tester.tap(find.byKey(const ValueKey('footer-cancel')));
      await settle(tester);
    });
    expect(text, findsNothing);
    expectResult('null');
    await openSheet(tester, 'footer', text);
    await measure('footer/dismiss-delete', () async {
      await tester.tap(find.byKey(const ValueKey('footer-delete')));
      await settle(tester);
    });
    expect(text, findsNothing);
    expectResult('true');
    expectClean(tester);
  });

  testWidgets('no-chrome: no handle, no close; barrier dismisses', (tester) async {
    await launch(tester);
    final text = find.byKey(const ValueKey('no-chrome-text'));
    await openSheet(tester, 'no-chrome', text);
    expect(_close, findsNothing);
    expect(find.bySemanticsLabel('Drag to dismiss'), findsNothing);
    await measure('no-chrome/dismiss-barrier', () => tapBarrier(tester));
    expect(text, findsNothing);
    expectResult('null');
    expectClean(tester);
  });

  testWidgets('paged: push, push, back, done', (tester) async {
    await launch(tester);
    final choose = find.text('Choose');
    await openSheet(tester, 'paged', choose);
    await measure('paged/push-details', () async {
      await tester.tap(find.byKey(const ValueKey('paged-row-1')));
      await settle(tester);
    });
    expect(find.text('Details'), findsWidgets);
    await tester.enterText(find.byKey(const ValueKey('paged-field-0')), 'note');
    await settle(tester);
    await measure('paged/push-confirm', () async {
      await tester.tap(find.byKey(const ValueKey('paged-next')));
      await settle(tester);
    });
    expect(find.text('Confirm'), findsWidgets);
    await measure('paged/pop-back', () async {
      await tester.tap(_back.last);
      await settle(tester);
    });
    expect(find.text('Details'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('paged-next')));
    await settle(tester);
    await measure('paged/dismiss-done', () async {
      await tester.tap(find.byKey(const ValueKey('paged-done')));
      await settle(tester);
    });
    expect(find.byKey(const ValueKey('paged-done')), findsNothing);
    expectResult('null');
    expectClean(tester);
  });
}
