import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/brand_logo.dart';
import '../../../active/presentation/providers/supplies_provider.dart';
import '../../../profile/presentation/providers/performance_provider.dart';
import '../../../profile/presentation/widgets/performance_insights.dart';
import '../../../requests/presentation/providers/request_list_provider.dart';

/// Home — greeting, KPI cards, a monthly earnings chart and top-selling
/// products, all backed by the real `/vendor-procurement/vendor/performance`
/// endpoint (blueprint §8, extended with `monthly_trend`/`top_products`).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newRequests = ref.watch(requestListProvider('NEW')).requests.length;
    final activeSupplies = ref.watch(suppliesProvider).supplies.where((s) => s.isActive).length;
    final performanceState = ref.watch(performanceProvider);
    final summary = PerformanceSummary.fromState(performanceState);

    Future<void> refresh() async {
      await Future.wait([
        ref.read(requestListProvider('NEW').notifier).load(filter: 'NEW'),
        ref.read(suppliesProvider.notifier).load(),
        ref.read(performanceProvider.notifier).load(),
      ]);
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const Row(
          children: [
            BrandLogo(height: 30),
            SizedBox(width: 10),
            Text('FreshCuts Vendor'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
            tooltip: 'Notifications',
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.brandRed,
        onRefresh: refresh,
        child: ListView(
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
                    value: summary.monthValueLabel,
                    icon: Icons.payments_outlined,
                    iconColor: AppColors.success,
                    iconSurface: AppColors.successSurface,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _KpiCard(
                    title: 'Rating',
                    value: summary.ratingLabel,
                    icon: Icons.star_outline,
                    iconColor: AppColors.warning,
                    iconSurface: AppColors.warningSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Earnings Overview',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink)),
                TextButton(
                  onPressed: () => context.push('/performance'),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
                  child: const Text('Full report', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            EarningsChartCard(state: performanceState, summary: summary),
            const SizedBox(height: 20),
            const Text('Top Selling Products',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 10),
            TopProductsCard(state: performanceState, summary: summary),
            const SizedBox(height: 12),
          ],
        ),
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
