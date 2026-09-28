import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'full_screen_image_viewer.dart';

/// A small, rounded product image used on request/quote item rows and the
/// Home overview's Top Selling Products list. Tapping it opens
/// [FullScreenImageViewer]. When [imageUrl] is null/empty (a legacy line
/// item with no catalog product link) it renders a neutral placeholder
/// instead — never a broken-image icon or blank space.
class ProductThumbnail extends StatelessWidget {
  const ProductThumbnail({
    super.key,
    required this.imageUrl,
    this.size = 52,
    this.borderRadius = 12,
    this.heroTag,
    this.title,
  });

  final String? imageUrl;
  final double size;
  final double borderRadius;
  final Object? heroTag;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url == null || url.isEmpty) {
      return _placeholder();
    }

    final tag = heroTag ?? url;
    return GestureDetector(
      onTap: () => FullScreenImageViewer.show(context, imageUrl: url, heroTag: tag, title: title),
      child: Hero(
        tag: tag,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Image.network(
            url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                width: size,
                height: size,
                color: AppColors.canvas,
                alignment: Alignment.center,
                child: SizedBox(
                  width: size * 0.3,
                  height: size * 0.3,
                  child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.brandRed),
                ),
              );
            },
            errorBuilder: (context, error, stack) => _placeholder(),
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: AppColors.border),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.image_outlined, color: AppColors.subtle, size: size * 0.42),
    );
  }
}
