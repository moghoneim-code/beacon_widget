// Test harness: exercises the real `beacon` package — including the Phase 4
// select-mode overlay — against a wide matrix of widget shapes (PLAN.md
// §3.2 asks for ~15). Tap the FAB to enter select mode, then tap anything
// below; long-press the FAB to broadcast everything selected since the
// last broadcast as one combined reference (PLAN.md §6).
import 'package:beacon_widget/beacon_widget.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const BeaconTestApp());
}

class BeaconTestApp extends StatelessWidget {
  const BeaconTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Beacon Widget Matrix',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      builder: (context, child) => Beacon.attach(child!),
      home: const WidgetMatrixScreen(),
    );
  }
}

class WidgetMatrixScreen extends StatefulWidget {
  const WidgetMatrixScreen({super.key});

  @override
  State<WidgetMatrixScreen> createState() => _WidgetMatrixScreenState();
}

class _WidgetMatrixScreenState extends State<WidgetMatrixScreen> {
  bool _switchValue = false;
  bool? _checkboxValue = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Beacon Widget Matrix'),
        actions: const [_BeaconVisibilityToggle(), SizedBox(width: 8)],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _Section('1. Custom widget'),
          const BeaconCard(label: 'Custom widget (BeaconCard)'),
          const SizedBox(height: 16),

          const _Section('2. Material buttons'),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton(onPressed: () {}, child: const Text('Elevated')),
              OutlinedButton(onPressed: () {}, child: const Text('Outlined')),
              TextButton(onPressed: () {}, child: const Text('Text')),
              IconButton(onPressed: () {}, icon: const Icon(Icons.favorite)),
            ],
          ),
          const SizedBox(height: 16),

          const _Section('3. Button wrapped in framework noise'),
          Semantics(
            label: 'wrapped button',
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: const AlwaysStoppedAnimation(0),
                builder: (context, child) => child!,
                child: const WrappedButton(),
              ),
            ),
          ),
          const SizedBox(height: 16),

          const _Section('4. Text inside a standard ListTile'),
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Text inside ListTile'),
              subtitle: Text('tap the title, subtitle, or leading icon'),
            ),
          ),
          const SizedBox(height: 16),

          const _Section('5. Widget behind a Stack'),
          SizedBox(
            height: 80,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  child: Container(
                    width: 100,
                    height: 80,
                    color: Colors.grey.shade300,
                  ),
                ),
                const Positioned(
                  left: 20,
                  top: 20,
                  child: BeaconCard(label: 'Behind Stack'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          const _Section('6. Items inside ListView.builder'),
          SizedBox(
            height: 150,
            child: ListView.builder(
              itemCount: 3,
              itemBuilder: (context, index) => ProductRow(index: index),
            ),
          ),
          const SizedBox(height: 16),

          const _Section('7. Form controls'),
          Row(
            children: [
              Checkbox(
                value: _checkboxValue,
                onChanged: (v) => setState(() => _checkboxValue = v),
              ),
              Switch(
                value: _switchValue,
                onChanged: (v) => setState(() => _switchValue = v),
              ),
              const SizedBox(width: 12),
              Chip(label: const Text('A chip')),
            ],
          ),
          const SizedBox(height: 12),
          const TextField(
            decoration: InputDecoration(
              labelText: 'A text field',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          const _Section('8. Deeply nested custom widget'),
          const Padding(
            padding: EdgeInsets.all(4),
            child: Center(
              child: BeaconCard(label: 'Nested in Padding > Center'),
            ),
          ),
          const SizedBox(height: 16),

          const _Section('9. Theme-literal color (no token match expected)'),
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF123456),
            child: const Text('Literal color container'),
          ),
        ],
      ),
    );
  }
}

/// A debug settings toggle for `Beacon.visible` (`Beacon.hide`/`.show`) — a
/// developer wires this into whatever settings UI their own app already
/// has; this is just the example app's version of that. Rebuilds only
/// itself off `Beacon.visible`, not the whole screen.
class _BeaconVisibilityToggle extends StatelessWidget {
  const _BeaconVisibilityToggle();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: Beacon.visible,
      builder: (context, visible, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Beacon'),
            Switch(value: visible, onChanged: Beacon.setVisible),
          ],
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label, style: Theme.of(context).textTheme.labelLarge),
    );
  }
}

/// Custom widget the resolver should land on exactly, at the line below.
class BeaconCard extends StatelessWidget {
  const BeaconCard({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label),
    );
  }
}

class WrappedButton extends StatelessWidget {
  const WrappedButton({super.key});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () {},
      child: const Text('Wrapped in Semantics/RepaintBoundary'),
    );
  }
}

class ProductRow extends StatelessWidget {
  const ProductRow({super.key, required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.inventory_2_outlined),
      title: Text('Product #$index'),
    );
  }
}
