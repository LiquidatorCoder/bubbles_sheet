import 'dart:ui';

import 'package:bubbles_sheet/src/bubbles_sheet_actions.dart';
import 'package:bubbles_sheet/src/bubbles_sheet_theme.dart';
import 'package:bubbles_sheet/src/device_corner_radius.dart';
import 'package:bubbles_sheet/src/flush_offset.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

/// iOS-26-style modal sheet detent.
///
/// - [fit]: content-sized snap. The sheet sizes to its content. Visually inset
///   from the screen edges so it floats above the dimmed background — unless
///   the content is so tall that the sheet effectively fills the screen, in
///   which case the chrome flushes to the device edges automatically.
/// - [medium]: fixed half-height snap (~55% of viewport). Useful for picker
///   sheets with long content where the user is expected to browse.
/// - [large]: full-screen snap (~95%). The sheet anchors flush to the device
///   edges; bottom corners adopt the device's screen corner radius so the
///   curve continues smoothly into the bezel.
sealed class BubblesSheetDetent {
  const BubblesSheetDetent();

  static const BubblesSheetDetent fit = _FitDetent();
  static const BubblesSheetDetent medium = _MediumDetent();
  static const BubblesSheetDetent large = _LargeDetent();
}

class _FitDetent extends BubblesSheetDetent {
  const _FitDetent();
}

class _MediumDetent extends BubblesSheetDetent {
  const _MediumDetent();
}

class _LargeDetent extends BubblesSheetDetent {
  const _LargeDetent();
}

const SheetOffset _kMediumOffset = SheetOffset.proportionalToViewport(0.55);

/// The fit detent, resolved from the sheet's live content height on every
/// layout — `contentSize.height + contentBaseline`.
///
/// It must stay live rather than being measured once at present time: a sheet
/// body can grow while the sheet is open. A one-shot measurement pins the sheet
/// at its old height and the new content spills past the bottom of the screen,
/// unreachable.
///
/// Reading `contentSize` is safe at any detent: `SheetSize.stretch` stretches
/// the sheet's own render box, not its content, so `contentSize` stays the
/// natural content height even while the sheet is parked at large.
const SheetOffset _kFitOffset = SheetOffset(1);

class _TopInsetAwareViewportOffset implements SheetOffset {
  const _TopInsetAwareViewportOffset();

  @override
  double resolve(ViewportLayout metrics) {
    final viewportHeight = metrics.viewportSize.height;
    if (viewportHeight <= 0) return 0;
    final factor = (viewportHeight - metrics.viewportPadding.top) / viewportHeight;
    return viewportHeight * factor.clamp(0.0, 1.0);
  }
}

/// Push a modal sheet with the Bubbles chrome.
///
/// Built on `ModalSheetRoute` with `BouncingSheetPhysics` and the iOS-style
/// scroll-to-drag handoff (`SheetScrollHandlingBehavior.onlyFromTop`). The
/// parent route stays put — this doesn't recede the underlying screen.
///
/// All sheets default to two detents — [BubblesSheetDetent.fit] (initial,
/// content-sized) and [BubblesSheetDetent.large] (drag up to ~95% of screen).
/// Pass [BubblesSheetDetent.medium] in [detents] to add a half-screen stop.
///
/// - [trailingAction] renders a text action in the header's trailing slot,
///   opposite the close button.
/// - [showCloseButton] toggles the top-leading close glyph (default on). Pass
///   `false` on sheets that rely on drag-to-dismiss only.
/// - [showDragHandle] toggles the centered grab handle.
/// - [primaryCtaBuilder] configures a sticky primary action at the bottom.
///   Pair it with [primaryCtaListenable] when the CTA depends on state the body
///   owns, so the CTA rebuilds without rebuilding the route.
/// - [footer] renders below the body, sticky to the bottom of the sheet.
/// - [dismissKeyboardOnDrag] dismisses focus before the sheet starts moving
///   when the user drags down — matches iOS keyboard behavior.
/// - [dark] swaps the sheet chrome (surface, title, drag handle, close button)
///   to `BubblesSheetThemeData.dark`. It is an explicit choice, not a read of
///   the ambient brightness. Body content is responsible for its own colours.
Future<T?> showBubblesSheet<T extends Object?>(
  BuildContext context, {
  required WidgetBuilder builder,
  List<BubblesSheetDetent> detents = const [BubblesSheetDetent.fit, BubblesSheetDetent.large],
  BubblesSheetDetent? initialDetent,
  String? title,
  BubblesSheetAction? trailingAction,
  bool showCloseButton = true,
  bool showDragHandle = true,
  bool barrierDismissible = true,
  bool swipeDismissible = true,
  bool dismissKeyboardOnDrag = false,
  Color barrierColor = const Color(0x52000000),
  BubblesSheetCta? primaryCta,
  BubblesSheetCtaBuilder? primaryCtaBuilder,
  Listenable? primaryCtaListenable,
  Widget? footer,
  bool useRootNavigator = true,
  bool dark = false,
}) {
  assert(detents.isNotEmpty, 'detents must contain at least one entry');
  assert(
    (primaryCta == null && primaryCtaBuilder == null) || footer == null,
    'Use either a primary CTA or footer, not both.',
  );
  assert(
    primaryCta == null || primaryCtaBuilder == null,
    'Use either primaryCta or primaryCtaBuilder, not both.',
  );
  assert(
    primaryCtaListenable == null || primaryCtaBuilder != null,
    'primaryCtaListenable requires primaryCtaBuilder.',
  );
  BubblesSheetThemeData.of(context).haptics.onPresent?.call();
  final initial = initialDetent ?? detents.first;
  final hasLarge = detents.contains(BubblesSheetDetent.large);
  final fitOnly = detents.length == 1 && detents.single == BubblesSheetDetent.fit;
  final controller = SheetController();
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  return navigator.push<T>(
    _BubblesSheetRoute<T>(
      // The route owns the controller and disposes it in `Route.dispose`; see
      // [_BubblesSheetRoute] for why that, and not the route's future, is the
      // moment it is safe to.
      controller: controller,
      // Stronger barrier than the Cupertino route default since there's no
      // parent-recede effect to do the visual layering.
      barrierColor: barrierColor,
      barrierDismissible: barrierDismissible,
      swipeDismissible: swipeDismissible,
      transitionDuration: const Duration(milliseconds: 360),
      transitionCurve: const Cubic(0.16, 1, 0.3, 1),
      viewportBuilder: (ctx, child) => _BubblesSheetViewport(controller: controller, child: child),
      builder: (ctx) {
        final sheet = _BubblesSheet(
          controller: controller,
          detents: detents,
          initialDetent: initial,
          hasLarge: hasLarge,
          fitOnly: fitOnly,
          title: title,
          trailingAction: trailingAction,
          showCloseButton: showCloseButton,
          showDragHandle: showDragHandle,
          primaryCta: primaryCta,
          primaryCtaBuilder: primaryCtaBuilder,
          primaryCtaListenable: primaryCtaListenable,
          footer: footer,
          dark: dark,
          body: Builder(builder: builder),
        );
        if (!dismissKeyboardOnDrag) return sheet;
        return SheetKeyboardDismissible(
          dismissBehavior: const SheetKeyboardDismissBehavior.onDragDown(isContentScrollAware: true),
          child: sheet,
        );
      },
    ),
  );
}

/// A [ModalSheetRoute] that owns the [SheetController] its sheet is driven by,
/// and disposes it only once the sheet is gone.
///
/// The controller has to outlive the sheet subtree, and the route's future is
/// the wrong place to end its life: that future completes at *pop*, the start
/// of the exit transition, while the sheet is still mounted, still attached to
/// the controller and still relaying out (the keyboard collapsing as the route
/// leaves is enough). Disposed there, the controller sits under a live sheet,
/// and smooth_sheets' `SheetController.notifyListeners` — which defers a
/// notification raised during layout to a post-frame callback — then fires on a
/// dead controller ("A SheetController was used after being disposed."). The
/// sheet also loses its `controller.metrics` mid-exit, so a sheet parked at the
/// large detent would see its flush bottom corners jump back to the device
/// radius.
///
/// `Navigator` only calls [dispose] once the route's overlay entries have
/// unmounted: `_RouteEntry.dispose` waits for them, since an overlay entry is
/// the root of the route's subtree and unmounts last. So by then the sheet's
/// model has detached from the controller. A notification deferred earlier in that same
/// frame can still be pending, so the controller is disposed in a post-frame
/// callback registered from here: callbacks run in registration order, which
/// puts it behind any deferred notify.
class _BubblesSheetRoute<T> extends ModalSheetRoute<T> {
  _BubblesSheetRoute({
    required SheetController controller,
    required super.builder,
    required super.viewportBuilder,
    required super.barrierColor,
    required super.barrierDismissible,
    required super.swipeDismissible,
    required super.transitionDuration,
    required super.transitionCurve,
  }) : _sheetController = controller;

  final SheetController _sheetController;

  @override
  void dispose() {
    super.dispose();
    final binding = WidgetsBinding.instance;
    binding.addPostFrameCallback((_) => _sheetController.dispose());
    // Disposal waits on a frame; make sure one is coming so the controller
    // never lingers on an otherwise idle app.
    binding.ensureVisualUpdate();
  }
}

/// The modal route's viewport chrome: floats the sheet on its inset, lerps to
/// flush as it nears the large detent, and lifts the whole sheet above the
/// software keyboard.
///
/// The [SheetOffsetDrivenAnimation] is created ONCE in `initState` — never
/// inside the build closure. The viewport rebuilds whenever the keyboard inset
/// changes; rebuilding the animation on each of those frames would make
/// `AnimatedBuilder.didUpdateWidget` unsubscribe from the old animation and
/// subscribe to a new one on the [SheetController] every time, for no benefit.
/// Caching it in State keeps one subscription for the sheet's life.
class _BubblesSheetViewport extends StatefulWidget {
  const _BubblesSheetViewport({required this.controller, required this.child});

  final SheetController controller;
  final Widget child;

  @override
  State<_BubblesSheetViewport> createState() => _BubblesSheetViewportState();
}

class _BubblesSheetViewportState extends State<_BubblesSheetViewport> {
  late final SheetOffsetDrivenAnimation _flushAnim;

  @override
  void initState() {
    super.initState();
    _flushAnim = SheetOffsetDrivenAnimation(
      controller: widget.controller,
      initialValue: 0,
      startOffset: const BubblesFlushOffset(kBubblesFlushBegin),
      endOffset: const BubblesFlushOffset(kBubblesFlushEnd),
    );
  }

  @override
  Widget build(BuildContext context) {
    final metrics = BubblesSheetThemeData.of(context).metrics;
    final view = MediaQuery.viewPaddingOf(context);
    // Lift the whole floating sheet above the software keyboard so its content
    // (fields, CTA) stays reachable. BubblesFlushOffset absorbs this inset, so the
    // lift never triggers the edge-flush.
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    // Float at the configured inset everywhere; lerp to flush as the sheet
    // approaches the large detent so it kisses the device edges.
    return AnimatedBuilder(
      animation: _flushAnim,
      builder: (_, _) {
        final inset = lerpDouble(metrics.inset, 0, _flushAnim.value)!;
        return Padding(
          padding: EdgeInsets.fromLTRB(inset, 0, inset, inset),
          child: SheetViewport(
            padding: EdgeInsets.only(top: view.top + metrics.topInset, bottom: bottomInset),
            child: widget.child,
          ),
        );
      },
    );
  }
}

class _BubblesSheet extends StatefulWidget {
  const _BubblesSheet({
    required this.controller,
    required this.detents,
    required this.initialDetent,
    required this.hasLarge,
    required this.fitOnly,
    required this.title,
    required this.trailingAction,
    required this.showCloseButton,
    required this.showDragHandle,
    required this.primaryCta,
    required this.primaryCtaBuilder,
    required this.primaryCtaListenable,
    required this.footer,
    required this.dark,
    required this.body,
  });

  final SheetController controller;
  final List<BubblesSheetDetent> detents;
  final BubblesSheetDetent initialDetent;
  final bool hasLarge;
  final bool fitOnly;
  final String? title;
  final BubblesSheetAction? trailingAction;
  final bool showCloseButton;
  final bool showDragHandle;
  final BubblesSheetCta? primaryCta;
  final BubblesSheetCtaBuilder? primaryCtaBuilder;
  final Listenable? primaryCtaListenable;
  final Widget? footer;
  final bool dark;
  final Widget body;

  @override
  State<_BubblesSheet> createState() => _BubblesSheetState();
}

/// Critically damped (ratio 1.0) and stiffer than smooth_sheets' default
/// (mass 0.5, stiffness 100, ratio 1.1 - overdamped, slow tail that "creeps"
/// into place). omega = 20 s^-1: ~0.4 s to settle 400 px to 1 px, no
/// overshoot of its own. The bounce at the ends still comes from the
/// overdrag in BouncingSheetPhysics.
final SpringDescription _kSnapSpring = SpringDescription.withDampingRatio(mass: 1, stiffness: 400, ratio: 1);

class _SnappyBouncingSheetPhysics extends BouncingSheetPhysics {
  const _SnappyBouncingSheetPhysics({super.bounceExtent});

  @override
  SpringDescription get spring => _kSnapSpring;
}

class _BubblesSheetState extends State<_BubblesSheet> {
  late final SheetOffsetDrivenAnimation _flushAnim;

  @override
  void initState() {
    super.initState();
    _configure();
    _flushAnim = SheetOffsetDrivenAnimation(
      controller: widget.controller,
      initialValue: 0,
      startOffset: const BubblesFlushOffset(kBubblesFlushBegin),
      endOffset: const BubblesFlushOffset(kBubblesFlushEnd),
    );
  }

  SheetOffset _toOffset(BubblesSheetDetent detent) {
    return switch (detent) {
      _FitDetent() => _kFitOffset,
      _MediumDetent() => _kMediumOffset,
      _LargeDetent() => const _TopInsetAwareViewportOffset(),
    };
  }

  // Everything below depends only on widget fields, so it is built once (and
  // again only if those fields change). Handing smooth_sheets a fresh snap
  // grid on every rebuild - the keyboard animation rebuilds each frame - makes
  // it recompute the sheet's boundaries for nothing.
  late SheetSnapGrid _snapGrid;
  late SheetPhysics _physics;
  late SheetScrollConfiguration _scrollConfig;

  void _configure() {
    final snaps = widget.detents.map(_toOffset).toList();
    _snapGrid = snaps.length == 1 ? SheetSnapGrid.single(snap: snaps.single) : SheetSnapGrid(snaps: snaps);

    // Fit-only sheets shouldn't bounce up past their natural size - bouncing
    // would expose the barrier above the sheet for no reason. Multi-detent
    // sheets get the iOS-style bounce + spring snap.
    _physics = widget.fitOnly
        ? ClampingSheetPhysics(spring: _kSnapSpring)
        : const _SnappyBouncingSheetPhysics(bounceExtent: 16);

    // onlyFromTop: the iOS handoff. Inner scrollables consume drag until they
    // hit the top, then the sheet starts moving. Removes the "I scrolled up but
    // the sheet jumped down" bug.
    _scrollConfig = widget.fitOnly
        ? SheetScrollConfiguration.disabled
        : const SheetScrollConfiguration(
            scrollSyncMode: SheetScrollHandlingBehavior.onlyFromTop,
            delegateUnhandledOverscrollToChild: true,
          );
  }

  @override
  void didUpdateWidget(_BubblesSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fitOnly != oldWidget.fitOnly || !listEquals(widget.detents, oldWidget.detents)) {
      _configure();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Sheet(
      controller: widget.controller,
      initialOffset: _toOffset(widget.initialDetent),
      snapGrid: _snapGrid,
      physics: _physics,
      scrollConfiguration: _scrollConfig,
      dragConfiguration: const SheetDragConfiguration(),
      decoration: SheetDecorationBuilder(
        size: SheetSize.stretch,
        builder: (ctx, child) => _BubblesSheetSurface(
          controller: widget.controller,
          flushAnim: _flushAnim,
          hasLarge: widget.hasLarge,
          dark: widget.dark,
          child: child,
        ),
      ),
      child: _BubblesSheetChrome(
        title: widget.title,
        trailingAction: widget.trailingAction,
        showCloseButton: widget.showCloseButton,
        showDragHandle: widget.showDragHandle,
        primaryCta: widget.primaryCta,
        primaryCtaBuilder: widget.primaryCtaBuilder,
        primaryCtaListenable: widget.primaryCtaListenable,
        footer: widget.footer,
        dark: widget.dark,
        body: widget.body,
      ),
    );
  }
}

/// Renders the sheet background, shadow, and concentric corners. Bottom radius
/// lerps from `deviceCornerRadius - inset` (floating) up to
/// `deviceCornerRadius` (flush) as the sheet approaches the large detent — then
/// snaps to 0 once the sheet is parked at the large (flush) detent, since the
/// device's own screen corner curve takes over the clipping at that point.
/// The snap is gated on [hasLarge]: a fit-only (or medium-only) sheet is parked
/// at its max detent from the moment it opens yet still floats above the device
/// edge, so it must keep its rounded floating corners rather than squaring off.
class _BubblesSheetSurface extends StatefulWidget {
  const _BubblesSheetSurface({
    required this.controller,
    required this.flushAnim,
    required this.hasLarge,
    required this.dark,
    required this.child,
  });

  final SheetController controller;
  final Animation<double> flushAnim;
  final bool hasLarge;
  final bool dark;
  final Widget child;

  @override
  State<_BubblesSheetSurface> createState() => _BubblesSheetSurfaceState();
}

class _BubblesSheetSurfaceState extends State<_BubblesSheetSurface> {
  // Merge once in initState, never per build. SheetDecorationBuilder rebuilds
  // this surface on every layout tick; a fresh Listenable.merge each time would
  // make AnimatedBuilder.didUpdateWidget resubscribe to the SheetController on
  // every one of them. (Same reasoning as the hoisted _BubblesSheetViewport.)
  late final Listenable _repaint;

  @override
  void initState() {
    super.initState();
    // BubblesDeviceCornerRadius resolves over a platform channel, so a sheet
    // opened before that lands would paint square corners and never revisit
    // them. Merging its listenable in — once, here, never per build — makes the
    // surface repaint the moment the radius arrives.
    _repaint = Listenable.merge([widget.flushAnim, widget.controller, BubblesDeviceCornerRadius.listenable]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = BubblesSheetThemeData.of(context);
    final palette = theme.paletteFor(dark: widget.dark);
    final topRadius = Radius.circular(theme.metrics.topRadius);
    return AnimatedBuilder(
      animation: _repaint,
      builder: (context, _) {
        // Resolved inside the builder, not captured outside it: the radius can
        // arrive after this surface first painted, and _repaint only re-runs
        // this closure. Reading it in the outer build would pin the first
        // answer — 0, before the channel replies — for the sheet's whole life.
        final deviceR = theme.metrics.resolveDeviceCornerRadius(context);
        final m = widget.controller.metrics;
        final atMax = m != null && m.offset >= m.maxOffset - 0.5;
        final t = widget.flushAnim.value;
        final lerped = lerpDouble(deviceR - theme.metrics.inset, deviceR, t)!.clamp(0.0, deviceR);
        // Only square the bottom corners once the sheet is flush against the
        // device edge — i.e. parked at the large detent. A fit-only sheet is
        // "at max" while still floating, so it keeps its rounded corners.
        final bottomR = Radius.circular(atMax && widget.hasLarge ? 0.0 : lerped);
        final shape = BorderRadius.only(
          topLeft: topRadius,
          topRight: topRadius,
          bottomLeft: bottomR,
          bottomRight: bottomR,
        );
        return DecoratedBox(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: shape,
            boxShadow: palette.surfaceShadow,
          ),
          child: ClipRRect(borderRadius: shape, child: widget.child),
        );
      },
    );
  }
}

class _BubblesSheetChrome extends StatelessWidget {
  const _BubblesSheetChrome({
    required this.title,
    required this.trailingAction,
    required this.showCloseButton,
    required this.showDragHandle,
    required this.primaryCta,
    required this.primaryCtaBuilder,
    required this.primaryCtaListenable,
    required this.footer,
    required this.dark,
    required this.body,
  });

  final String? title;
  final BubblesSheetAction? trailingAction;
  final bool showCloseButton;
  final bool showDragHandle;
  final BubblesSheetCta? primaryCta;
  final BubblesSheetCtaBuilder? primaryCtaBuilder;
  final Listenable? primaryCtaListenable;
  final Widget? footer;
  final bool dark;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final ctaListenable = primaryCtaListenable;
    final cta = primaryCtaBuilder?.call(context) ?? primaryCta;
    final hasCta = cta != null || ctaListenable != null;

    final bottomBar = (hasCta || footer != null)
        ? _BottomChrome(
            cta: cta,
            ctaListenable: ctaListenable,
            ctaBuilder: primaryCtaBuilder,
            footer: footer,
            dark: dark,
          )
        : null;

    return SheetContentScaffold(
      backgroundColor: Colors.transparent,
      // The whole sheet is already lifted above the keyboard by the viewport's
      // bottom padding, so the bar rides up with the body. Left to react to
      // viewInsets itself it would be hidden twice over, behind the keyboard.
      bottomBarVisibility: const BottomBarVisibility.always(ignoreBottomInset: true),
      topBar: _Header(
        title: title,
        trailingAction: trailingAction,
        showDragHandle: showDragHandle,
        showCloseButton: showCloseButton,
        dark: dark,
        theme: BubblesSheetThemeData.of(context),
      ),
      bottomBar: bottomBar,
      body: Material(type: MaterialType.transparency, child: body),
    );
  }
}

class _BottomChrome extends StatelessWidget {
  const _BottomChrome({
    required this.cta,
    required this.ctaListenable,
    required this.ctaBuilder,
    required this.footer,
    required this.dark,
  });

  final BubblesSheetCta? cta;
  final Listenable? ctaListenable;
  final BubblesSheetCtaBuilder? ctaBuilder;
  final Widget? footer;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final theme = BubblesSheetThemeData.of(context);
    final metrics = theme.metrics;
    final appTheme = Theme.of(context);
    // The sheet is painted from the sheet palette, not the app's ColorScheme,
    // so a bar reading `onSurface` (the default CTA's disabled pill and label,
    // a custom ctaBuilder or footer) would contrast with the app rather than
    // the sheet: black-on-charcoal for `dark: true` in a light app, near-white
    // on cream for a light sheet in a dark app. Re-anchor `onSurface` and the
    // brightness to the sheet's palette; `primary`/`onPrimary` stay the app's.
    final barTheme = appTheme.copyWith(
      colorScheme: appTheme.colorScheme.copyWith(
        brightness: dark ? Brightness.dark : Brightness.light,
        onSurface: theme.paletteFor(dark: dark).title,
      ),
    );
    return Theme(
      data: barTheme,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (cta != null || ctaListenable != null)
              _PrimaryCtaSlot(
                cta: cta ?? const BubblesSheetCta(title: '', onTap: null),
                listenable: ctaListenable,
                builder: ctaBuilder,
              ),
            if (footer != null) Padding(padding: metrics.footerPadding, child: footer),
          ],
        ),
      ),
    );
  }
}

class _PrimaryCtaSlot extends StatelessWidget {
  const _PrimaryCtaSlot({required this.cta, required this.listenable, required this.builder});

  final BubblesSheetCta cta;
  final Listenable? listenable;
  final BubblesSheetCtaBuilder? builder;

  @override
  Widget build(BuildContext context) {
    final theme = BubblesSheetThemeData.of(context);
    return Padding(
      padding: theme.metrics.ctaPadding,
      child: listenable == null
          ? theme.ctaBuilder(context, cta)
          : AnimatedBuilder(
              animation: listenable!,
              builder: (context, _) {
                final current = builder?.call(context);
                return current == null ? const SizedBox.shrink() : theme.ctaBuilder(context, current);
              },
            ),
    );
  }
}

class _Header extends StatelessWidget implements PreferredSizeWidget {
  const _Header({
    required this.title,
    required this.trailingAction,
    required this.showDragHandle,
    required this.showCloseButton,
    required this.dark,
    required this.theme,
  });

  final String? title;
  final BubblesSheetAction? trailingAction;
  final bool showDragHandle;
  final bool showCloseButton;
  final bool dark;
  final BubblesSheetThemeData theme;

  @override
  Size get preferredSize {
    final metrics = theme.metrics;
    final hasHeaderRow = title != null || showCloseButton || trailingAction != null;
    if (!showDragHandle && !hasHeaderRow) return const Size.fromHeight(16);
    // The handle strip is drawn (or reserved) whenever any chrome shows, so the
    // full formula applies unless the row itself is absent.
    return Size.fromHeight(hasHeaderRow ? metrics.headerHeight : metrics.dragHandleSize.height + 10);
  }

  @override
  Widget build(BuildContext context) {
    final metrics = theme.metrics;
    final palette = theme.paletteFor(dark: dark);
    final hasTitle = title != null;
    final action = trailingAction;
    final hasHeaderRow = hasTitle || showCloseButton || action != null;
    final showAnything = showDragHandle || hasHeaderRow;
    if (!showAnything) return const SizedBox(height: 16);
    final slotWidth = metrics.headerSlotWidth;

    return Material(
      type: MaterialType.transparency,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 4),
            child: showDragHandle
                ? _DragHandle(size: metrics.dragHandleSize, color: palette.dragHandle)
                : SizedBox.fromSize(size: metrics.dragHandleSize),
          ),
          if (hasHeaderRow)
            Padding(
              padding: metrics.headerPadding,
              child: SizedBox(
                height: metrics.headerRowHeight,
                // NavigationToolbar rather than a three-slot Row: it keeps the
                // title centered on the row itself, so a wide trailing label
                // never drags the title off-center against the close slot.
                child: NavigationToolbar(
                  middleSpacing: 8,
                  leading: SizedBox(
                    width: slotWidth,
                    child: showCloseButton
                        ? theme.closeBuilder(
                            context,
                            BubblesSheetClose(
                              icon: theme.closeIcon,
                              onPressed: () => _onClose(context),
                              palette: palette,
                              size: metrics.closeButtonSize,
                            ),
                          )
                        : null,
                  ),
                  middle: hasTitle
                      ? Text(
                          title!,
                          textAlign: TextAlign.center,
                          style: theme.titleStyle.copyWith(color: palette.title),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                  trailing: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: slotWidth),
                    child: action == null
                        ? const SizedBox.shrink()
                        : _TrailingAction(
                            action: action,
                            palette: palette,
                            style: theme.actionStyle,
                            height: metrics.headerRowHeight,
                          ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _onClose(BuildContext context) {
    theme.haptics.onDismiss?.call();
    Navigator.of(context).maybePop();
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.size, required this.color});

  final Size size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Drag to dismiss',
      container: true,
      child: Container(
        width: size.width,
        height: size.height,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(size.height / 2)),
      ),
    );
  }
}

class _TrailingAction extends StatelessWidget {
  const _TrailingAction({
    required this.action,
    required this.palette,
    required this.style,
    required this.height,
  });

  final BubblesSheetAction action;
  final BubblesSheetPalette palette;
  final TextStyle style;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = action.enabled && action.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: action.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? action.onTap : null,
        // Align with a widthFactor, not a Container with an alignment: under
        // NavigationToolbar's loose constraints an aligned Container expands to
        // the full toolbar width, which pushes the centered title off the row.
        child: SizedBox(
          height: height,
          child: Align(
            alignment: Alignment.centerRight,
            widthFactor: 1,
            child: Padding(
              padding: const EdgeInsets.only(left: 8, right: 4),
              child: Text(
                action.label,
                style: style.copyWith(color: enabled ? palette.action : palette.disabledAction),
                maxLines: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
