import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/supplies_provider.dart';
import '../widgets/supply_card.dart';

/// Active supplies — every awarded order not yet closed (blueprint §15.7).
class ActiveScreen extends ConsumerWidget {
  const ActiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(suppliesProvider);
    final active = state.supplies.where((supply) => supply.isActive).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Active')),
      body: state.loading && state.supplies.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.brandRed))
          : active.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.local_shipping_outlined, size: 48, color: AppColors.subtle),
                      const SizedBox(height: 12),
                      const Text('No active supplies',
                          style: TextStyle(color: AppColors.inkSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      const Text(
                        'Supply orders you accept or win will appear here\nwith their next required action.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.subtle, fontSize: 12, height: 1.5),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.brandRed,
                  onRefresh: () => ref.read(suppliesProvider.notifier).load(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: active.length,
                    itemBuilder: (context, index) => SupplyCard(supply: active[index]),
                  ),
                ),
    );
  }
}
