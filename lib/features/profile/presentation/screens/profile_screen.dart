import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Profile — business info, KYC status, documents, service areas, account
/// controls (§15.12). Sections wire to the service-profile APIs in Phase 10+.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.brandRedSurface,
                  child: const Icon(Icons.storefront, color: AppColors.brandRed),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        auth.vendorName ?? 'FreshCuts Vendor',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        auth.vendorStatus ?? 'Status unknown',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Section(icon: Icons.badge_outlined, title: 'Business Info', onTap: () => context.push('/profile/business-info')),
          _Section(icon: Icons.verified_outlined, title: 'Tax & Licenses', onTap: () => context.push('/profile/tax-licenses')),
          _Section(icon: Icons.folder_outlined, title: 'Documents', onTap: () => context.push('/profile/documents')),
          _Section(icon: Icons.storefront_outlined, title: 'Store Allotment', onTap: () => context.push('/profile/store-allotment')),
          _Section(icon: Icons.category_outlined, title: 'Categories', onTap: () => context.push('/profile/categories')),
          _Section(
            icon: Icons.trending_up_outlined,
            title: 'My Performance',
            onTap: () async {
              context.push('/performance');
            },
          ),
          _Section(
            icon: Icons.notifications_outlined,
            title: 'Notification Settings',
            onTap: () => context.push('/profile/notification-settings'),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/phone');
            },
            icon: const Icon(Icons.logout, color: AppColors.error),
            label: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
            style: OutlinedButton.styleFrom(side: BorderSide(color: AppColors.error.withValues(alpha: 0.3))),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: AppColors.inkSecondary),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.subtle),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
