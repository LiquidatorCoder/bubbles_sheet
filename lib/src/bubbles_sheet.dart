import 'dart:ui';

import 'package:bubbles_sheet/src/bubbles_sheet_actions.dart';
import 'package:bubbles_sheet/src/bubbles_sheet_theme.dart';
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

/// Flush threshold proportional to the viewport, shifted up by the bottom
/// viewport inset (the software keyboard). When the keyboard lifts the sheet,
/// this keeps the lift from spuriously engaging the edge-flush — the sheet
/// holds its floating inset and rounded corners while a field is focused, and
/// only kisses the device edges when the user actually drags it toward large.
class _FlushOffset implements SheetOffset {
  const _FlushOffset(this.fraction);

  final double fraction;

  @override
  double resolve(ViewportLayout metrics) => metrics.viewportSize.height * fraction + metrics.viewportPadding.bottom;
}

// The sheet floats on its inset everywhere except right at the top of the large
// detent — there it lerps the inset to 0 and the bottom corners up to the
// device's screen radius so the curve continues smoothly into the bezel.
const double _kFlushBegin = 0.6;
const double _kFlushEnd = 0.9;

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
  assert(primaryCta == null || primaryCtaBuilder == null, 'Use either primaryCta or primaryCtaBuilder, not both.');
  assert(primaryCtaListenable == null || primaryCtaBuilder != null, 'primaryCtaListenable requires primaryCtaBuilder.');
  BubblesSheetThemeData.of(context).haptics.onPresent?.call();
  final initial = initialDetent ?? detents.first;
  final hasLarge = detents.contains(BubblesSheetDetent.large);
  final fitOnly = detents.length == 1 && detents.single == BubblesSheetDetent.fit;
  final controller = SheetController();
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  return navigator
      .push<T>(
        ModalSheetRoute<T>(
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
      )
      .whenComplete(() {
        // Defer dispose by one frame so widgets inside the popped sheet finish
        // unmounting before the controller is torn down. Without this, a
        // follow-up route push (e.g. sheets that pop with a route path and then
        // push it) triggers a MediaQuery rebuild on the still-mounted sheet
        // subtree — `AnimatedBuilder.didUpdateWidget` then calls `addListener`
        // on a disposed controller and throws.
        WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
      });
}

/// The modal route's viewport chrome: floats the sheet on its inset, lerps to
/// flush as it nears the large detent, and lifts the whole sheet above the
/// software keyboard.
///
/// The [SheetOffsetDrivenAnimation] is created ONCE in `initState` — never
/// inside the build closure. The viewport rebuilds whenever the keyboard inset
/// changes; rebuilding the animation on each of those frames makes
/// `AnimatedBuilder.didUpdateWidget` swap listeners onto the [SheetController].
/// Once the route's `whenComplete` has disposed that controller (which happens
/// as the sheet pops with the keyboard still collapsing), the swap calls
/// `addListener` on a disposed controller and throws "A SheetController was
/// used after being disposed.", cascading into a `_dependents.isEmpty` crash.
/// Caching the animation in State keeps `didUpdateWidget` seeing the same
/// instance, so no listener swap fires during teardown.
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
      startOffset: const _FlushOffset(_kFlushBegin),
      endOffset: const _FlushOffset(_kFlushEnd),
    );
  }

  @override
  Widget build(BuildContext context) {
    final metrics = BubblesSheetThemeData.of(context).metrics;
    final view = MediaQuery.viewPaddingOf(context);
    // Lift the whole floating sheet above the software keyboard so its content
    // (fields, CTA) stays reachable. _FlushOffset absorbs this inset, so the
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

class _BubblesSheetState extends State<_BubblesSheet> {
  late final SheetOffsetDrivenAnimation _flushAnim;

  @override
  void initState() {
    super.initState();
    _flushAnim = SheetOffsetDrivenAnimation(
      controller: widget.controller,
      initialValue: 0,
      startOffset: const _FlushOffset(_kFlushBegin),
      endOffset: const _FlushOffset(_kFlushEnd),
    );
  }

  SheetOffset _toOffset(BubblesSheetDetent detent) {
    return switch (detent) {
      _FitDetent() => _kFitOffset,
      _MediumDetent() => _kMediumOffset,
      _LargeDetent() => const _TopInsetAwareViewportOffset(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final snaps = widget.detents.map(_toOffset).toList();
    final snapGrid = snaps.length == 1 ? SheetSnapGrid.single(snap: snaps.single) : SheetSnapGrid(snaps: snaps);

    // Fit-only sheets shouldn't bounce up past their natural size — bouncing
    // would expose the barrier above the sheet for no reason. Multi-detent
    // sheets get the iOS-style bounce + spring snap.
    final physics = widget.fitOnly ? const ClampingSheetPhysics() : const BouncingSheetPhysics(bounceExtent: 16);

    // onlyFromTop: the iOS handoff. Inner scrollables consume drag until they
    // hit the top, then the sheet starts moving. Removes the "I scrolled up but
    // the sheet jumped down" bug.
    final scrollConfig = widget.fitOnly
        ? SheetScrollConfiguration.disabled
        : const SheetScrollConfiguration(
            scrollSyncMode: SheetScrollHandlingBehavior.onlyFromTop,
            delegateUnhandledOverscrollToChild: true,
          );

    return Sheet(
      controller: widget.controller,
      initialOffset: _toOffset(widget.initialDetent),
      snapGrid: snapGrid,
      physics: physics,
      scrollConfiguration: scrollConfig,
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
  // this surface on every layout tick; a fresh Listenable.merge each time makes
  // AnimatedBuilder.didUpdateWidget swap listeners onto the SheetController,
  // which throws "used after disposed" once the route's whenComplete has torn
  // the controller down during a teardown relayout. (Same hazard the hoisted
  // _BubblesSheetViewport guards against.)
  late final Listenable _repaint;

  @override
  void initState() {
    super.initState();
    _repaint = Listenable.merge([widget.flushAnim, widget.controller]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = BubblesSheetThemeData.of(context);
    final palette = theme.paletteFor(dark: widget.dark);
    final deviceR = theme.metrics.deviceCornerRadius;
    final topRadius = Radius.circular(theme.metrics.topRadius);
    return AnimatedBuilder(
      animation: _repaint,
      builder: (context, _) {
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
          decoration: BoxDecoration(color: palette.surface, borderRadius: shape, boxShadow: palette.surfaceShadow),
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
        ? _BottomChrome(cta: cta, ctaListenable: ctaListenable, ctaBuilder: primaryCtaBuilder, footer: footer)
        : null;

    return SheetContentScaffold(
      backgroundColor: Colors.transparent,
      bottomBarVisibility: const BottomBarVisibility.always(),
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
  const _BottomChrome({required this.cta, required this.ctaListenable, required this.ctaBuilder, required this.footer});

  final BubblesSheetCta? cta;
  final Listenable? ctaListenable;
  final BubblesSheetCtaBuilder? ctaBuilder;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final metrics = BubblesSheetThemeData.of(context).metrics;
    return Material(
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
    final handleH = (showDragHandle || hasHeaderRow) ? metrics.dragHandleSize.height + 10 : 0.0;
    final rowH = hasHeaderRow ? metrics.headerRowHeight + metrics.headerPadding.vertical : 0.0;
    final h = handleH + rowH;
    return Size.fromHeight(h <= 0 ? 16 : h);
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
    final slotWidth = metrics.headerRowHeight;

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
                        ? _CloseButton(
                            palette: palette,
                            icon: theme.closeIcon,
                            size: metrics.closeButtonSize,
                            onTap: () => _onClose(context),
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
  const _TrailingAction({required this.action, required this.palette, required this.style, required this.height});

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

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap, required this.palette, required this.icon, required this.size});

  final VoidCallback? onTap;
  final BubblesSheetPalette palette;
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Close',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: palette.closeButtonBackground, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Icon(icon, size: 14, color: palette.closeButtonIcon),
        ),
      ),
    );
  }
}
