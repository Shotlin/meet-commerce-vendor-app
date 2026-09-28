import 'package:flutter/material.dart';

/// The FreshCuts Vendor mark (the "FC" + storefront logo). One widget so the
/// splash, login, app bars and profile all render the same asset instead of
/// each screen improvising its own text/icon stand-in.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.height = 32});

  /// Rendered height in logical pixels; width follows the logo's aspect.
  final double height;

  static const assetPath = 'assets/images/vendor_logo.png';

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: 'FreshCuts Vendor',
    );
  }
}
