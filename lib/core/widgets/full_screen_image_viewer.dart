import 'package:flutter/material.dart';

/// A modal, pinch-to-zoom image viewer with an explicit close (X) button.
///
/// The app has no Android-style back button on iOS, so every screen that
/// opens this must be closable without relying on a system back gesture —
/// the X button is always visible, top-right, inside the safe area.
class FullScreenImageViewer extends StatelessWidget {
  const FullScreenImageViewer({super.key, required this.imageUrl, this.heroTag, this.title});

  final String imageUrl;
  final Object? heroTag;
  final String? title;

  static void show(BuildContext context, {required String imageUrl, Object? heroTag, String? title}) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (context, animation, secondaryAnimation) =>
            FullScreenImageViewer(imageUrl: imageUrl, heroTag: heroTag, title: title),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Hero(
                  tag: heroTag ?? imageUrl,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stack) => const Center(
                      child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 56),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    if (title != null)
                      Expanded(
                        child: Text(
                          title!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      )
                    else
                      const Spacer(),
                    _CloseButton(onTap: () => Navigator.of(context).pop()),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(Icons.close, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
