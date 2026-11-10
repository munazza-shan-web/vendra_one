import 'package:flutter/material.dart';

/// Reusable VendraOne brand mark for app bars and other screens.
class VendraOneLogo extends StatelessWidget {
  const VendraOneLogo({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final secondary = Theme.of(context).colorScheme.secondary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 34 : 40,
          height: compact ? 34 : 40,
          decoration: BoxDecoration(
            color: primary,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.receipt_long_rounded,
                color: Colors.white,
                size: compact ? 22 : 26,
              ),
              Positioned(
                right: 2,
                bottom: 2,
                child: Container(
                  width: compact ? 14 : 16,
                  height: compact ? 14 : 16,
                  decoration: BoxDecoration(
                    color: secondary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Icon(
                    Icons.shopping_cart_rounded,
                    color: Colors.white,
                    size: compact ? 8 : 9,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'VendraOne',
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 18 : 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}
