import 'dart:ui';

import 'package:bubbles_sheet/src/bubbles_sheet_theme.dart';
import 'package:bubbles_sheet/src/device_corner_radius.dart';
import 'package:flutter/material.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

/// Top chrome for a page inside a `PagedSheet`. Drag handle + circular leading
/// button + centered title.
///
/// - [showClose] uses the theme's close icon and pops the root navigator
///   (dismisses the whole sheet).
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
                    child: showClose
                        ? BubblesPagedSheetCircleButton(
                            icon: theme.closeIcon,
                            onTap: () {
                              theme.haptics.onDismiss?.call();
                              Navigator.of(context, rootNavigator: true).pop();
                            },
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
      decoration: BoxDecoration(color: theme.light.dragHandle, borderRadius: BorderRadius.circular(size.height / 2)),
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
      child: Container(
        width: theme.metrics.closeButtonSize,
        height: theme.metrics.closeButtonSize,
        decoration: BoxDecoration(color: palette.closeButtonBackground, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Icon(icon, size: 14, color: palette.closeButtonIcon),
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
/// recreating the animation on those frames makes `AnimatedBuilder`'s
/// `didUpdateWidget` swap listeners onto the [SheetController]. Once the route's
/// `whenComplete` has disposed that controller (which happens as the sheet pops
/// with the keyboard still collapsing), the swap calls `addListener` on a
/// disposed controller and throws "A SheetController was used after being
/// disposed.", cascading into a `_dependents.isEmpty` crash. Caching the
/// animation in State keeps `didUpdateWidget` seeing the same instance, so no
/// listener swap fires during teardown.
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
      startOffset: const SheetOffset.proportionalToViewport(0.6),
      endOffset: const SheetOffset.proportionalToViewport(0.9),
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
/// bottom corners lerp from `deviceCornerRadius - inset` (floating) up to
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
  // build would make AnimatedBuilder swap listeners onto the SheetController and
  // throw "used after disposed" during a teardown relayout. (See
  // BubblesPagedSheetViewport for the full explanation.)
  late final SheetOffsetDrivenAnimation _flushAnim;
  late final Listenable _repaint;

  @override
  void initState() {
    super.initState();
    _flushAnim = SheetOffsetDrivenAnimation(
      controller: widget.controller,
      initialValue: 0,
      startOffset: const SheetOffset.proportionalToViewport(0.6),
      endOffset: const SheetOffset.proportionalToViewport(0.9),
    );
    // BubblesDeviceCornerRadius resolves over a platform channel, so a sheet
    // opened before that lands would paint square corners and never revisit
    // them. Merging its listenable in — once, here, never per build — makes the
    // surface repaint the moment the radius arrives.
    _repaint = Listenable.merge([_flushAnim, widget.controller, BubblesDeviceCornerRadius.listenable]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = BubblesSheetThemeData.of(context);
    final palette = theme.light;
    final topRadius = Radius.circular(theme.metrics.topRadius);
    return AnimatedBuilder(
      animation: _repaint,
      builder: (context, _) {
        // Inside the builder, not captured outside it — see the note in
        // bubbles_sheet.dart: the radius can land after the first paint.
        final deviceR = theme.metrics.resolveDeviceCornerRadius(context);
        final t = _flushAnim.value;
        final lerped = lerpDouble(deviceR - theme.metrics.inset, deviceR, t)!.clamp(0.0, deviceR);
        // Only zero the radius once the sheet is actually flush with the
        // viewport top — not when a content-fit sheet sits at its single snap
        // (where offset == maxOffset trivially).
        final isFlush = t >= 0.99;
        final bottomR = Radius.circular(isFlush ? 0.0 : lerped);
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
