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
        // Everything here has a default; this shows where the seams are.
        extensions: const [
          BubblesSheetThemeData(
            metrics: BubblesSheetMetrics(deviceCornerRadius: 44),
          ),
        ],
      ),
      home: const _Home(),
    );
  }
}

class _Home extends StatelessWidget {
  const _Home();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Button(label: 'Fit + large', onTap: () => _showBasic(context)),
            _Button(label: 'Three detents, scrolling', onTap: () => _showScrolling(context)),
            _Button(label: 'Trailing action + live CTA', onTap: () => _showCounter(context)),
            _Button(label: 'Dark chrome', onTap: () => _showBasic(context, dark: true)),
          ],
        ),
      ),
    );
  }

  void _showBasic(BuildContext context, {bool dark = false}) {
    showBubblesSheet<void>(
      context,
      title: 'Sort by',
      dark: dark,
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
                  style: TextStyle(fontSize: 16, color: dark ? const Color(0xFFFAF9F5) : const Color(0xFF111111)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showScrolling(BuildContext context) {
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
    );
  }

  void _showCounter(BuildContext context) {
    final count = ValueNotifier<int>(0);
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
                ChoiceChip(label: Text('$i'), selected: value == i, onSelected: (_) => count.value = i),
            ],
          ),
        ),
      ),
    ).whenComplete(count.dispose);
  }
}

class _Button extends StatelessWidget {
  const _Button({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: FilledButton(onPressed: onTap, child: Text(label)),
    );
  }
}
