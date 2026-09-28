import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/brand_logo.dart';

/// Shown only while the session is being restored on cold start
/// (`AuthStatus.booting`) — a neutral holding screen so a genuinely
/// logged-in vendor never sees a flash of the login screen while the app
/// checks whether their token is still valid. See `app_router.dart`'s
/// `redirect` for how this is enforced (booting always lands here, never
/// on `/phone`, regardless of `initialLocation`).
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandLogo(height: 88),
            const SizedBox(height: 24),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.brandRed),
            ),
          ],
        ),
      ),
    );
  }
}
