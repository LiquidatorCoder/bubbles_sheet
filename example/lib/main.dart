import 'package:bubbles_sheet/bubbles_sheet.dart';
import 'package:flutter/material.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'bubbles_sheet',
      theme: ThemeData.light(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFFFAF9F5),
        colorScheme: const ColorScheme.light(primary: Color(0xFFD97757), surface: Color(0xFFFAF9F5)),
        // Nothing to configure. The sheet resolves the display's own corner
        // radius, so its bottom corners stay concentric with the bezel.
        extensions: const [BubblesSheetThemeData()],
      ),
      home: const _Home(),
    );
  }
}

class _Home extends StatefulWidget {
  const _Home();

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  final _result = ValueNotifier<String>('result: none');

  @override
  void dispose() {
    _result.dispose();
    super.dispose();
  }

  /// Shows [future]'s pop value under the buttons once the sheet completes.
  Future<T?> _track<T>(Future<T?> future) => future.then((value) {
    _result.value = 'result: $value';
    return value;
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Button(slug: 'fit-large', label: 'Fit + large', onTap: () => _showBasic(context)),
                _Button(slug: 'three-detents', label: 'Three detents, scrolling', onTap: () => _showScrolling(context)),
                _Button(slug: 'live-cta', label: 'Trailing action + live CTA', onTap: () => _showCounter(context)),
                _Button(slug: 'dark', label: 'Dark chrome', onTap: () => _showDark(context)),
                _Button(slug: 'form', label: 'Form with keyboard', onTap: () => _showForm(context)),
                _Button(slug: 'form-autofocus', label: 'Autofocus form', onTap: () => _showAutofocus(context)),
                _Button(slug: 'fit-only', label: 'Fit only', onTap: () => _showFitOnly(context)),
                _Button(slug: 'long-fit', label: 'Long content, fit + large', onTap: () => _showLongFit(context)),
                _Button(slug: 'large-list', label: 'Large list', onTap: () => _showLargeList(context)),
                _Button(slug: 'grow', label: 'Growing content', onTap: () => _showGrow(context)),
                _Button(slug: 'locked', label: 'Locked sheet', onTap: () => _showLocked(context)),
                _Button(slug: 'footer', label: 'Footer buttons', onTap: () => _showFooter(context)),
                _Button(slug: 'no-chrome', label: 'No chrome', onTap: () => _showNoChrome(context)),
                _Button(slug: 'paged', label: 'Paged flow', onTap: () => _showPaged(context)),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: ValueListenableBuilder<String>(
                    valueListenable: _result,
                    builder: (context, value, _) => Text(value, key: const ValueKey('last-result')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showBasic(BuildContext context) {
    _track(
      showBubblesSheet<void>(
        context,
        title: 'Sort by',
        primaryCta: BubblesSheetCta(title: 'Done', onTap: () => Navigator.of(context).pop()),
        builder: (context) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final option in ['Value · high to low', 'Value · low to high', 'Name · A to Z'])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    option,
                    style: const TextStyle(fontSize: 16, color: Color(0xFF111111)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// The dark sheet starts with Done disabled until a sort option is picked, so
  /// the disabled CTA can be seen against the charcoal surface on a device.
  void _showDark(BuildContext context) {
    const options = ['Value · high to low', 'Value · low to high', 'Name · A to Z'];
    final selected = ValueNotifier<int?>(null);
    _track(
      showBubblesSheet<void>(
        context,
        title: 'Sort by',
        dark: true,
        primaryCtaListenable: selected,
        primaryCtaBuilder: (context) => BubblesSheetCta(
          title: 'Done',
          enabled: selected.value != null,
          onTap: selected.value == null ? null : () => Navigator.of(context).pop(),
        ),
        builder: (context) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ValueListenableBuilder<int?>(
            valueListenable: selected,
            builder: (context, value, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < options.length; i++)
                  GestureDetector(
                    key: ValueKey('dark-option-$i'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => selected.value = i,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              options[i],
                              style: const TextStyle(fontSize: 16, color: Color(0xFFFAF9F5)),
                            ),
                          ),
                          if (value == i) const Icon(Icons.check, size: 18, color: Color(0xFFFAF9F5)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() => _disposeAfterExit([selected]));
  }

  void _showScrolling(BuildContext context) {
    _track(
      showBubblesSheet<void>(
        context,
        title: 'Tokens',
        detents: const [BubblesSheetDetent.fit, BubblesSheetDetent.medium, BubblesSheetDetent.large],
        initialDetent: BubblesSheetDetent.medium,
        builder: (context) => ListView.builder(
          shrinkWrap: true,
          itemCount: 40,
          itemBuilder: (context, i) => ListTile(title: Text('Token $i')),
        ),
      ),
    );
  }

  void _showCounter(BuildContext context) {
    final count = ValueNotifier<int>(0);
    _track(
      showBubblesSheet<int>(
        context,
        title: 'Pick a number',
        trailingAction: BubblesSheetAction(label: 'Clear', onTap: () => count.value = 0),
        primaryCtaListenable: count,
        primaryCtaBuilder: (context) => BubblesSheetCta(
          title: count.value == 0 ? 'Pick one' : 'Apply ${count.value}',
          enabled: count.value != 0,
          onTap: count.value == 0 ? null : () => Navigator.of(context).pop(count.value),
        ),
        builder: (context) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: ValueListenableBuilder<int>(
            valueListenable: count,
            builder: (context, value, _) => Wrap(
              spacing: 8,
              children: [
                for (var i = 1; i <= 6; i++)
                  ChoiceChip(
                    key: ValueKey('live-cta-chip-$i'),
                    label: Text('$i'),
                    selected: value == i,
                    onSelected: (_) => count.value = i,
                  ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() => _disposeAfterExit([count]));
  }

  void _showForm(BuildContext context) {
    final name = TextEditingController();
    final email = TextEditingController();
    final note = TextEditingController();
    final details = TextEditingController();
    _track(
      showBubblesSheet<void>(
        context,
        title: 'Profile',
        dismissKeyboardOnDrag: true,
        primaryCtaListenable: name,
        primaryCtaBuilder: (context) => BubblesSheetCta(
          title: 'Save',
          enabled: name.text.isNotEmpty,
          onTap: name.text.isEmpty ? null : () => Navigator.of(context).pop(),
        ),
        builder: (context) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const ValueKey('form-field-0'),
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                key: const ValueKey('form-field-1'),
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                key: const ValueKey('form-field-2'),
                controller: note,
                decoration: const InputDecoration(labelText: 'Note'),
              ),
              TextField(
                key: const ValueKey('form-field-3'),
                controller: details,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Details'),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() => _disposeAfterExit([name, email, note, details]));
  }

  void _showAutofocus(BuildContext context) {
    _track(
      showBubblesSheet<void>(
        context,
        title: 'New item',
        detents: const [BubblesSheetDetent.fit],
        primaryCta: BubblesSheetCta(title: 'Add', onTap: () => Navigator.of(context).pop()),
        builder: (context) => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: TextField(
            key: ValueKey('form-autofocus-field-0'),
            autofocus: true,
            decoration: InputDecoration(labelText: 'Item'),
          ),
        ),
      ),
    );
  }

  void _showFitOnly(BuildContext context) {
    _track(
      showBubblesSheet<void>(
        context,
        title: 'Fit only',
        detents: const [BubblesSheetDetent.fit],
        builder: (context) => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Text('Short content, no CTA.', key: ValueKey('fit-only-text')),
        ),
      ),
    );
  }

  void _showLongFit(BuildContext context) {
    _track(
      showBubblesSheet<void>(
        context,
        title: 'Long content',
        builder: (context) => SingleChildScrollView(
          child: Column(
            children: [
              for (var i = 0; i < 30; i++) ListTile(key: ValueKey('long-fit-row-$i'), title: Text('Row $i')),
            ],
          ),
        ),
      ),
    );
  }

  void _showLargeList(BuildContext context) {
    _track(
      showBubblesSheet<void>(
        context,
        title: 'Large list',
        initialDetent: BubblesSheetDetent.large,
        builder: (context) => ListView.builder(
          key: const ValueKey('large-list-list'),
          itemCount: 100,
          itemBuilder: (context, i) => ListTile(key: ValueKey('large-list-row-$i'), title: Text('Item $i')),
        ),
      ),
    );
  }

  void _showGrow(BuildContext context) {
    var rows = 2;
    _track(
      showBubblesSheet<void>(
        context,
        title: 'Growing content',
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      key: const ValueKey('grow-add'),
                      onPressed: () => setState(() => rows++),
                      child: const Text('Add row'),
                    ),
                    TextButton(
                      key: const ValueKey('grow-remove'),
                      onPressed: () => setState(() => rows = rows > 0 ? rows - 1 : 0),
                      child: const Text('Remove row'),
                    ),
                  ],
                ),
                for (var i = 0; i < rows; i++) ListTile(key: ValueKey('grow-row-$i'), title: Text('Row $i')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLocked(BuildContext context) {
    _track(
      showBubblesSheet<void>(
        context,
        title: 'Locked',
        barrierDismissible: false,
        swipeDismissible: false,
        showCloseButton: false,
        primaryCta: BubblesSheetCta(title: 'Close', onTap: () => Navigator.of(context).pop()),
        builder: (context) => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Text('Only the button closes this sheet.', key: ValueKey('locked-text')),
        ),
      ),
    );
  }

  void _showFooter(BuildContext context) {
    _track(
      showBubblesSheet<bool>(
        context,
        title: 'Delete item',
        trailingAction: const BubblesSheetAction(label: 'Edit', onTap: null, enabled: false),
        footer: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const ValueKey('footer-cancel'),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                key: const ValueKey('footer-delete'),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ),
          ],
        ),
        builder: (context) => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Text('This cannot be undone.', key: ValueKey('footer-text')),
        ),
      ),
    );
  }

  void _showNoChrome(BuildContext context) {
    _track(
      showBubblesSheet<void>(
        context,
        showDragHandle: false,
        showCloseButton: false,
        builder: (context) => const Padding(
          padding: EdgeInsets.all(20),
          child: Text('No handle, no close button, no title.', key: ValueKey('no-chrome-text')),
        ),
      ),
    );
  }

  void _showPaged(BuildContext context) {
    // A fresh controller per flow, disposed with the route, as the package's own
    // paged-sheet regression test does.
    final controller = SheetController();
    _track(
      Navigator.of(context, rootNavigator: true).push<void>(
        ModalSheetRoute<void>(
          transitionDuration: const Duration(milliseconds: 360),
          viewportBuilder: (ctx, child) => BubblesPagedSheetViewport(controller: controller, child: child),
          builder: (_) => PagedSheet(
            controller: controller,
            decoration: SheetDecorationBuilder(
              size: SheetSize.stretch,
              builder: (ctx, child) => BubblesPagedSheetSurface(controller: controller, child: child),
            ),
            navigator: Navigator(
              onGenerateInitialRoutes: (navigator, initialRoute) => [
                PagedSheetRoute<void>(builder: (_) => const _PagedChoose()),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() => _disposeAfterExit([controller]));
  }
}

/// Disposes [notifiers] once a popped sheet's exit animation has finished.
///
/// The route's future completes when it is popped, not when it has left the
/// screen, so disposing straight away would hand the still-mounted text fields
/// a dead controller.
void _disposeAfterExit(List<ChangeNotifier> notifiers) {
  Future<void>.delayed(const Duration(milliseconds: 600), () {
    for (final notifier in notifiers) {
      notifier.dispose();
    }
  });
}

class _PagedChoose extends StatelessWidget {
  const _PagedChoose();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BubblesPagedSheetHeader(title: 'Choose', showClose: true),
          for (var i = 0; i < 3; i++)
            ListTile(
              key: ValueKey('paged-row-$i'),
              title: Text('Option $i'),
              onTap: () => Navigator.of(context).push(PagedSheetRoute<void>(builder: (_) => const _PagedDetails())),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _PagedDetails extends StatelessWidget {
  const _PagedDetails();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BubblesPagedSheetHeader(title: 'Details', showBack: true),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              key: ValueKey('paged-field-0'),
              decoration: InputDecoration(labelText: 'Details'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              key: const ValueKey('paged-next'),
              onPressed: () => Navigator.of(context).push(PagedSheetRoute<void>(builder: (_) => const _PagedConfirm())),
              child: const Text('Next'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PagedConfirm extends StatelessWidget {
  const _PagedConfirm();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BubblesPagedSheetHeader(title: 'Confirm', showBack: true),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              key: const ValueKey('paged-done'),
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Button extends StatelessWidget {
  const _Button({required this.slug, required this.label, required this.onTap});

  final String slug;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: FilledButton(key: ValueKey('demo-$slug'), onPressed: onTap, child: Text(label)),
    );
  }
}
