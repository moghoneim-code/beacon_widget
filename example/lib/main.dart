// A small storefront, wired up with beacon_widget.
//
// Tap the beacon button, then tap anything on screen: the widget's file and
// line land on your clipboard, ready to paste into a coding agent. The UI is
// deliberately built from small named widgets spread across several files, so
// the references it produces look like the ones you'd get in a real app.
import 'package:beacon_widget/beacon_widget.dart';
import 'package:flutter/material.dart';

import 'data/products.dart';
import 'widgets/category_chip.dart';
import 'widgets/checkout_bar.dart';
import 'widgets/product_card.dart';
import 'widgets/promo_banner.dart';

void main() {
  runApp(const BeaconDemoApp());
}

class BeaconDemoApp extends StatelessWidget {
  const BeaconDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Beacon Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0D11),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C5CFF),
          brightness: Brightness.dark,
        ),
      ),
      // The one line that installs beacon.
      builder: (BuildContext context, Widget? child) => Beacon.attach(child!),
      home: const StorefrontScreen(),
    );
  }
}

class StorefrontScreen extends StatefulWidget {
  const StorefrontScreen({super.key});

  @override
  State<StorefrontScreen> createState() => _StorefrontScreenState();
}

class _StorefrontScreenState extends State<StorefrontScreen> {
  String _category = 'All';

  List<Product> get _visible => _category == 'All'
      ? demoProducts
      : demoProducts.where((Product p) => p.category == _category).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D11),
        elevation: 0,
        titleSpacing: 20,
        title: const StoreHeader(),
        actions: const <Widget>[BeaconVisibilityToggle(), SizedBox(width: 12)],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: <Widget>[
                const PromoBanner(),
                const SizedBox(height: 28),
                const SectionHeading(title: 'Browse', action: 'See all'),
                const SizedBox(height: 14),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: demoCategories.length,
                    separatorBuilder: (BuildContext context, int i) =>
                        const SizedBox(width: 10),
                    itemBuilder: (BuildContext context, int i) => CategoryChip(
                      label: demoCategories[i],
                      selected: demoCategories[i] == _category,
                      onTap: () =>
                          setState(() => _category = demoCategories[i]),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _visible.length,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 320,
                    mainAxisExtent: 284,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemBuilder: (BuildContext context, int i) =>
                      ProductCard(product: _visible[i]),
                ),
              ],
            ),
          ),
          const CheckoutBar(itemCount: 3, total: 372.50),
        ],
      ),
    );
  }
}

/// The store's wordmark in the app bar.
class StoreHeader extends StatelessWidget {
  const StoreHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            gradient: const LinearGradient(
              colors: <Color>[Color(0xFF7C5CFF), Color(0xFFE05C8A)],
            ),
          ),
          child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        const Text(
          'Northwind',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

/// A titled section divider with a trailing text action.
class SectionHeading extends StatelessWidget {
  const SectionHeading({super.key, required this.title, required this.action});

  final String title;
  final String action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        TextButton(
          onPressed: () {},
          child: Text(
            action,
            style: const TextStyle(
              color: Color(0xFF9B86FF),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Shows off `Beacon.visible` — flip it off before taking a screenshot, or
/// wire it into whatever debug settings your own app already has.
class BeaconVisibilityToggle extends StatelessWidget {
  const BeaconVisibilityToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: Beacon.visible,
      builder: (BuildContext context, bool visible, Widget? child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'beacon',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 13,
              ),
            ),
            Switch(value: visible, onChanged: Beacon.setVisible),
          ],
        );
      },
    );
  }
}
