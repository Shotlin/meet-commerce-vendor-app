import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../active/presentation/providers/supplies_provider.dart';
import '../../../active/presentation/widgets/supply_card.dart';

/// Completed/cancelled supply history with search (blueprint §15.10).
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(suppliesProvider);
    final finished = state.supplies
        .where((supply) => !supply.isActive)
        .where((supply) =>
            _query.isEmpty ||
            supply.supplyNumber.toLowerCase().contains(_query.toLowerCase()) ||
            supply.shopName.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by order or store',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: finished.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.history_outlined, size: 48, color: AppColors.subtle),
                        const SizedBox(height: 12),
                        const Text('No completed supplies yet',
                            style: TextStyle(color: AppColors.inkSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        const Text(
                          'Delivered and closed supply orders will appear here.',
                          style: TextStyle(color: AppColors.subtle, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    color: AppColors.brandRed,
                    onRefresh: () => ref.read(suppliesProvider.notifier).load(),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: finished.length,
                      itemBuilder: (context, index) => SupplyCard(supply: finished[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
