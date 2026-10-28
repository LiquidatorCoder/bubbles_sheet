import 'dart:ui';

import 'package:bubbles_sheet/src/bubbles_sheet_theme.dart';
import 'package:bubbles_sheet/src/device_corner_radius.dart';
import 'package:bubbles_sheet/src/flush_offset.dart';
import 'package:bubbles_sheet/src/sheet_route.dart';
import 'package:bubbles_sheet/src/sheet_surface.dart';
import 'package:flutter/material.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

/// Push a paged modal sheet: a multi-page flow inside one Bubbles sheet.
///
/// [builder] builds the first page. Push further pages from inside it with the
/// inner navigator, using smooth_sheets' `PagedSheetRoute` (re-exported by this
/// package):
///
/// ```dart
/// showBubblesPagedSheet<void>(
///   context,
///   builder: (_) => const ChoosePage(),
/// );
///
/// // Inside ChoosePage:
/// Navigator.of(context).push(
///   PagedSheetRoute<void>(builder: (_) => const DetailsPage()),
/// );
/// ```
///
/// Give each page a [BubblesPagedSheetHeader]; its close button dismisses the
/// whole sheet and its back button pops the inner navigator. To dismiss the
/// sheet from your own widgets, pop the navigator that hosts it:
/// `Navigator.of(context, rootNavigator: true).pop(result)` when the sheet was
/// pushed on the root navigator (the default), or the navigator the sheet was
/// pushed on when [useRootNavigator] is false. The inner `Navigator.of(context)`
/// pops a page, not the sheet.
///
/// Unlike a hand-assembled `ModalSheetRoute`, the route owns its
/// `SheetController` and disposes it only once the sheet has left the screen,
/// and it shares the modal sheets' snap spring, swipe-dismiss sensitivity,
/// transition, barrier and present haptic.
///
/// Pages are fit-to-content: the sheet grows and shrinks to the current page.
Future<T?> showBubblesPagedSheet<T extends Object?>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  bool swipeDismissible = true,
  Color barrierColor = const Color(0x52000000),
  bool useRootNavigator = true,
}) {
  BubblesSheetThemeData.of(context).haptics.onPresent?.call();
  final controller = SheetController();
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  return navigator.push<T>(
    BubblesSheetRoute<T>(
      // Disposed by the route once the sheet is gone; see [BubblesSheetRoute].
      controller: controller,
      barrierColor: barrierColor,
      barrierDismissible: barrierDismissible,
      swipeDismissible: swipeDismissible,
      viewportBuilder: (ctx, child) => BubblesPagedSheetViewport(controller: controller, child: child),
      builder: (ctx) => PagedSheet(
        controller: controller,
        physics: ClampingSheetPhysics(spring: kBubblesSnapSpring),
        decoration: SheetDecorationBuilder(
          size: SheetSize.stretch,
          builder: (ctx, child) => BubblesPagedSheetSurface(controller: controller, child: child),
        ),
        navigator: Navigator(
          onGenerateInitialRoutes: (navigator, initialRoute) => [PagedSheetRoute<void>(builder: builder)],
        ),
      ),
    ),
  );
}

/// Top chrome for a page inside a `PagedSheet`. Drag handle + circular leading
/// button + centered title.
///
/// - [showClose] uses the theme's close icon and pops the route that hosts the
///   paged sheet (dismisses the whole sheet), honouring its `PopScope`.
/// - [showBack] uses the theme's back icon and pops the inner navigator
///   (returns to the previous page in the paged sheet).
class BubblesPagedSheetHeader extends StatelessWidget implements PreferredSizeWidget {
  const BubblesPagedSheetHeader({
    required this.title,
    this.showClose = false,
    this.showBack = false,
    this.metrics = const BubblesSheetMetrics(),
    super.key,
  });

  final String title;
  final bool showClose;
  final bool showBack;

  /// This header's geometry.
  ///
  /// It comes from the widget rather than the ambient theme because
  /// [preferredSize] is read before there is a [BuildContext] to look a theme
  /// up from, and the size the header reserves has to be the size it paints.
  /// Reading geometry from the theme in `build` while reserving the default
  /// here would let the two drift apart silently — the same wart [AppBar] has
  /// with `AppBarTheme.toolbarHeight`. Colours, icons, type and haptics still
  /// come from the theme; only measurements live here.
  ///
  /// Pass the metrics registered on [BubblesSheetThemeData] if they aren't the
  /// defaults.
  final BubblesSheetMetrics metrics;

  @override
  Size get preferredSize => Size.fromHeight(metrics.headerHeight);

  /// The navigator the paged sheet's route lives on.
  ///
  /// A page's nearest navigator is the sheet's inner page navigator; the sheet
  /// itself sits on whichever navigator it was pushed to, which is the root one
  /// only by default. That is the navigator above the inner one.
  ///
  /// `Navigator.of` returns the navigator itself when handed its own context, so
  /// the lookup has to start from the inner navigator's parent.
  static NavigatorState _hostNavigator(BuildContext context) {
    final inner = Navigator.of(context);
    return inner.context.findAncestorStateOfType<NavigatorState>() ?? Navigator.of(context, rootNavigator: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = BubblesSheetThemeData.of(context);
    final palette = theme.light;
    return Material(
      type: MaterialType.transparency,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 4),
            // Sized from this header's metrics, not the theme's: the handle's
            // height is part of what preferredSize reserved above.
            child: BubblesPagedSheetDragHandle(size: metrics.dragHandleSize),
          ),
          Padding(
            padding: metrics.headerPadding,
            child: SizedBox(
              height: metrics.headerRowHeight,
              child: Row(
                children: [
                  SizedBox(
                    width: metrics.headerSlotWidth,
                    height: metrics.headerRowHeight,
                    child: showClose
                        ? theme.closeBuilder(
                            context,
                            BubblesSheetClose(
                              icon: theme.closeIcon,
                              onPressed: () {
                                theme.haptics.onDismiss?.call();
                                _hostNavigator(context).maybePop();
                              },
                              // A paged sheet has no `dark` flag of its own;
                              // its chrome has always been the light palette.
                              palette: theme.light,
                              size: theme.metrics.closeButtonSize,
                            ),
                          )
                        : showBack
                        ? BubblesPagedSheetCircleButton(
                            icon: theme.backIcon,
                            onTap: () {
                              theme.haptics.onBack?.call();
                              Navigator.of(context).pop();
                            },
                          )
                        : null,
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        title,
                        style: theme.titleStyle.copyWith(color: palette.title),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  SizedBox(width: metrics.headerSlotWidth),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BubblesPagedSheetDragHandle extends StatelessWidget {
  const BubblesPagedSheetDragHandle({this.size, super.key});

  /// Overrides the themed handle size. [BubblesPagedSheetHeader] passes its own
  /// so the handle matches the height the header reserved.
  final Size? size;

  @override
  Widget build(BuildContext context) {
    final theme = BubblesSheetThemeData.of(context);
    final size = this.size ?? theme.metrics.dragHandleSize;
    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        color: theme.light.dragHandle,
        borderRadius: BorderRadius.circular(size.height / 2),
      ),
    );
  }
}

class BubblesPagedSheetCircleButton extends StatelessWidget {
  const BubblesPagedSheetCircleButton({required this.icon, required this.onTap, super.key});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = BubblesSheetThemeData.of(context);
    final palette = theme.light;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      // Center for the same reason as the modal header's close button: the
      // enclosing slot's constraints must not decide the circle's size.
      child: Center(
        child: Container(
          width: theme.metrics.closeButtonSize,
          height: theme.metrics.closeButtonSize,
          decoration: BoxDecoration(color: palette.closeButtonBackground, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Icon(icon, size: 14, color: palette.closeButtonIcon),
        ),
      ),
    );
  }
}

/// Viewport chrome for a paged modal sheet: floats the sheet on its inset,
/// lerps to flush as it nears the large detent, and lifts the whole sheet above
/// the software keyboard. Drop into `ModalSheetRoute.viewportBuilder`.
///
/// The [SheetOffsetDrivenAnimation] is created ONCE in `initState` — never in
/// the build closure. The viewport rebuilds on every keyboard-inset change;
/// recreating the animation on those frames would make `AnimatedBuilder`'s
/// `didUpdateWidget` unsubscribe from the old animation and subscribe to a new
/// one on the [SheetController] every time, for no benefit. Caching it in State
/// keeps one subscription for the sheet's life.
///
/// The [SheetController] you pass must outlive this viewport's subtree: dispose
/// it from your route's `dispose` (after the sheet has unmounted), not when the
/// route's future completes at pop, while the sheet is still on screen exiting.
class BubblesPagedSheetViewport extends StatefulWidget {
  const BubblesPagedSheetViewport({required this.controller, required this.child, super.key});

  final SheetController controller;
  final Widget child;

  @override
  State<BubblesPagedSheetViewport> createState() => _BubblesPagedSheetViewportState();
}

class _BubblesPagedSheetViewportState extends State<BubblesPagedSheetViewport> {
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
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedBuilder(
      animation: _flushAnim,
      builder: (_, _) {
        final inset = lerpDouble(metrics.inset, 0, _flushAnim.value)!;
        return Padding(
          padding: EdgeInsets.fromLTRB(inset, 0, inset, inset),
          child: SheetViewport(
            padding: EdgeInsets.only(top: view.top + metrics.topInset, bottom: keyboard),
            child: widget.child,
          ),
        );
      },
    );
  }
}

/// Sheet decoration for paged sheets. Top corners hold the theme's top radius;
/// bottom corners lerp from `max(deviceCornerRadius - inset, topRadius)`
/// (floating; on a square or unknown display the bottom mirrors the top) to
/// `deviceCornerRadius` (flush) as the sheet approaches the large detent — and
/// snap to 0 once fully flush, since the device's own screen corner curve takes
/// over the clipping at that point.
class BubblesPagedSheetSurface extends StatefulWidget {
  const BubblesPagedSheetSurface({required this.controller, required this.child, super.key});

  final SheetController controller;
  final Widget child;

  @override
  State<BubblesPagedSheetSurface> createState() => _BubblesPagedSheetSurfaceState();
}

class _BubblesPagedSheetSurfaceState extends State<BubblesPagedSheetSurface> {
  // Built once in initState. SheetDecorationBuilder rebuilds this surface on
  // every layout tick; a fresh SheetOffsetDrivenAnimation / Listenable.merge per
  // build would make AnimatedBuilder resubscribe to the SheetController on every
  // one of them. (See BubblesPagedSheetViewport.)
  late final SheetOffsetDrivenAnimation _flushAnim;
  late final BubblesSurfaceRepaint _repaint;

  @override
  void initState() {
    super.initState();
    _flushAnim = SheetOffsetDrivenAnimation(
      controller: widget.controller,
      initialValue: 0,
      startOffset: const BubblesFlushOffset(kBubblesFlushBegin),
      endOffset: const BubblesFlushOffset(kBubblesFlushEnd),
    );
    _repaint = BubblesSurfaceRepaint([_flushAnim, widget.controller]);
    // BubblesDeviceCornerRadius resolves over a platform channel, so a sheet
    // opened before that lands would paint square corners and never revisit
    // them. The radius is an input to the geometry, so its arrival rebuilds
    // this surface once.
    BubblesDeviceCornerRadius.listenable.addListener(_onDeviceRadius);
  }

  @override
  void dispose() {
    BubblesDeviceCornerRadius.listenable.removeListener(_onDeviceRadius);
    _repaint.dispose();
    super.dispose();
  }

  void _onDeviceRadius() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final theme = BubblesSheetThemeData.of(context);
    final palette = theme.light;
    return BubblesSheetSurfaceBox(
      geometry: BubblesSurfaceGeometry(
        controller: widget.controller,
        flushAnim: _flushAnim,
        topRadius: theme.metrics.topRadius,
        deviceRadius: theme.metrics.resolveDeviceCornerRadius(context),
        inset: theme.metrics.inset,
        // Only zero the radius once the sheet is actually flush with the
        // viewport top — not when a content-fit sheet sits at its single snap
        // (where offset == maxOffset trivially), and not when the keyboard
        // merely lifts it (BubblesFlushOffset absorbs that inset, so the flush
        // animation stays at 0).
        squareWhenFlush: true,
      ),
      repaint: _repaint,
      color: palette.surface,
      shadows: palette.surfaceShadow,
      child: widget.child,
    );
  }
}
