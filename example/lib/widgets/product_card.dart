import 'package:flutter/material.dart';

import '../data/products.dart';
import 'rating_stars.dart';

/// One product tile in the storefront grid.
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF17171C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ProductThumbnail(product: product),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  product.category.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                RatingStars(rating: product.rating, reviews: product.reviews),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    PriceTag(price: product.price),
                    const Spacer(),
                    AddToCartButton(accent: product.accent),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The tinted artwork area at the top of a [ProductCard].
class ProductThumbnail extends StatelessWidget {
  const ProductThumbnail({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Container(
          height: 128,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                product.accent.withValues(alpha: 0.34),
                product.accent.withValues(alpha: 0.10),
              ],
            ),
          ),
          child: Center(
            child: Icon(product.icon, size: 52, color: product.accent),
          ),
        ),
        if (product.badge != null)
          Positioned(
            top: 12,
            left: 12,
            child: ProductBadge(label: product.badge!, accent: product.accent),
          ),
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            onPressed: () {},
            icon: const Icon(Icons.favorite_border_rounded, size: 18),
            color: Colors.white.withValues(alpha: 0.85),
            style: IconButton.styleFrom(
              backgroundColor: Colors.black.withValues(alpha: 0.25),
            ),
          ),
        ),
      ],
    );
  }
}

/// The "New" / "Sale" flag on a product thumbnail.
class ProductBadge extends StatelessWidget {
  const ProductBadge({super.key, required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// The formatted price on a [ProductCard].
class PriceTag extends StatelessWidget {
  const PriceTag({super.key, required this.price});

  final double price;

  @override
  Widget build(BuildContext context) {
    return Text(
      '\$${price.toStringAsFixed(2)}',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// The compact "+" action on a [ProductCard].
class AddToCartButton extends StatelessWidget {
  const AddToCartButton({super.key, required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: FilledButton(
        onPressed: () {},
        style: FilledButton.styleFrom(
          backgroundColor: accent.withValues(alpha: 0.18),
          foregroundColor: accent,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Icon(Icons.add_rounded, size: 20),
      ),
    );
  }
}
