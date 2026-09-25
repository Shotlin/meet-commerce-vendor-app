import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../active/presentation/providers/supplies_provider.dart';
import '../../../requests/presentation/providers/request_list_provider.dart';

/// Home — greeting, KPI cards and quick actions (blueprint §8). Live data
/// (new requests, active supplies, monthly value) lands in Big Phase 14's
/// performance endpoint; the layout ships now.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newRequests = ref.watch(requestListProvider('NEW')).requests.length;
    final activeSupplies = ref.watch(suppliesProvider).supplies.where((s) => s.isActive).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('FreshCuts Vendor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
            tooltip: 'Notifications',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Good day 👋',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Here is what needs your attention today.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _KpiCard(
                  title: 'New Requests',
                  value: '$newRequests',
                  icon: Icons.inbox_outlined,
                  iconColor: AppColors.info,
                  iconSurface: AppColors.infoSurface,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _KpiCard(
                  title: 'Active Supplies',
                  value: '$activeSupplies',
                  icon: Icons.local_shipping_outlined,
                  iconColor: AppColors.brandRed,
                  iconSurface: AppColors.brandRedSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _KpiCard(
                  title: 'This Month Value',
                  value: '—',
                  icon: Icons.payments_outlined,
                  iconColor: AppColors.success,
                  iconSurface: AppColors.successSurface,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _KpiCard(
                  title: 'Rating',
                  value: '—',
                  icon: Icons.star_outline,
                  iconColor: AppColors.warning,
                  iconSurface: AppColors.warningSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconSurface,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconSurface;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: iconSurface, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ],
      ),
    );
  }
}
