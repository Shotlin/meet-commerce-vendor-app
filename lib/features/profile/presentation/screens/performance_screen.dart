import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/performance_provider.dart';

/// Vendor performance — transparent metrics (blueprint §15.11): rating,
/// monthly value/quantity, completed supplies, on-time rate, issues.
class PerformanceScreen extends ConsumerWidget {
  const PerformanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(performanceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Performance')),
      body: state.loading && state.data == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.brandRed))
          : state.error != null && state.data == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off, size: 48, color: AppColors.subtle),
                      const SizedBox(height: 12),
                      const Text('Could not load performance',
                          style: TextStyle(color: AppColors.inkSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => ref.read(performanceProvider.notifier).load(),
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.brandRed,
                  onRefresh: () => ref.read(performanceProvider.notifier).load(),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildMetrics(state),
                      const SizedBox(height: 16),
                      _RecentFeedback(state: state),
                    ],
                  ),
                ),
    );
  }

  Widget _buildMetrics(PerformanceState state) {
    final data = state.data ?? {};
    final performance = data['performance'] is Map ? data['performance'] as Map : {};
    final vendor = data['vendor'] is Map ? data['vendor'] as Map : {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${vendor['name'] ?? 'Your store'}',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink),
        ),
        const SizedBox(height: 4),
        Text(
          'This month: ₹${_fmt(performance['month_value'])} · ${_fmt(performance['month_quantity'])} kg supplied',
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _MetricCard(title: 'Rating', value: '${performance['avg_rating'] ?? '—'} ★', color: AppColors.warning, surface: AppColors.warningSurface, icon: Icons.star),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(title: 'On-time', value: performance['on_time_rate'] == null ? '—' : '${performance['on_time_rate']}%', color: AppColors.success, surface: AppColors.successSurface, icon: Icons.schedule),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricCard(title: 'Completed', value: '${performance['completed_supplies'] ?? 0}', color: AppColors.brandRed, surface: AppColors.brandRedSurface, icon: Icons.check_circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(title: 'Issues', value: '${performance['issue_count'] ?? 0}', color: AppColors.error, surface: AppColors.errorSurface, icon: Icons.report_problem),
            ),
          ],
        ),
      ],
    );
  }

  String _fmt(dynamic value) => NumberFormat('#,##0.##').format(num.tryParse('$value') ?? 0);
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.color,
    required this.surface,
    required this.icon,
  });

  final String title;
  final String value;
  final Color color;
  final Color surface;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink)),
              Text(title, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentFeedback extends StatelessWidget {
  const _RecentFeedback({required this.state});

  final PerformanceState state;

  @override
  Widget build(BuildContext context) {
    final reviews = (state.data?['reviews'] as List?) ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recent store feedback', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
        const SizedBox(height: 10),
        if (reviews.isEmpty)
          const Text('No feedback yet — completed supplies will collect store ratings here.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
        ...reviews.take(5).map((review) {
          final map = review is Map ? review : <dynamic, dynamic>{};
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('${map['rating_overall'] ?? '—'} ★', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.ink)),
                    const Spacer(),
                    Text('${map['shop_name'] ?? ''}', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                  ],
                ),
                if (map['comment'] != null && '${map['comment']}'.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('${map['comment']}', style: const TextStyle(fontSize: 12, color: AppColors.inkSecondary)),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }
}
