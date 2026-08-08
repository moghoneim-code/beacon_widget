import 'package:flutter/material.dart';

/// A product in the demo storefront.
class Product {
  const Product({
    required this.name,
    required this.category,
    required this.price,
    required this.rating,
    required this.reviews,
    required this.accent,
    required this.icon,
    this.badge,
  });

  final String name;
  final String category;
  final double price;
  final double rating;
  final int reviews;
  final Color accent;
  final IconData icon;
  final String? badge;
}

const List<Product> demoProducts = <Product>[
  Product(
    name: 'Aurora Headphones',
    category: 'Audio',
    price: 249.00,
    rating: 4.8,
    reviews: 1284,
    accent: Color(0xFF7C5CFF),
    icon: Icons.headphones_rounded,
    badge: 'New',
  ),
  Product(
    name: 'Lumen Desk Lamp',
    category: 'Home',
    price: 89.50,
    rating: 4.5,
    reviews: 412,
    accent: Color(0xFFFF8A5C),
    icon: Icons.light_mode_rounded,
  ),
  Product(
    name: 'Tide Water Bottle',
    category: 'Outdoor',
    price: 34.00,
    rating: 4.9,
    reviews: 2310,
    accent: Color(0xFF37C2C4),
    icon: Icons.water_drop_rounded,
    badge: 'Sale',
  ),
  Product(
    name: 'Grove Backpack',
    category: 'Outdoor',
    price: 168.00,
    rating: 4.6,
    reviews: 688,
    accent: Color(0xFF6FCF6B),
    icon: Icons.backpack_rounded,
  ),
  Product(
    name: 'Pulse Smartwatch',
    category: 'Wearables',
    price: 329.00,
    rating: 4.4,
    reviews: 903,
    accent: Color(0xFFE05C8A),
    icon: Icons.watch_rounded,
  ),
  Product(
    name: 'Ember Coffee Press',
    category: 'Home',
    price: 58.00,
    rating: 4.7,
    reviews: 1547,
    accent: Color(0xFFD9A441),
    icon: Icons.coffee_rounded,
  ),
];

const List<String> demoCategories = <String>[
  'All',
  'Audio',
  'Home',
  'Outdoor',
  'Wearables',
];
