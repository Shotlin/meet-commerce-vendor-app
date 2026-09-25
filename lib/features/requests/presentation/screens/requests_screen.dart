import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/request_list_provider.dart';
import '../widgets/request_card.dart';

/// Requests inbox — tabs New / Responded / Closed (blueprint §15.4).
class RequestsScreen extends ConsumerWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Requests'),
          bottom: TabBar(
            labelColor: AppColors.brandRed,
            unselectedLabelColor: AppColors.muted,
            indicatorColor: AppColors.brandRed,
            dividerColor: AppColors.divider,
            tabs: const [Tab(text: 'New'), Tab(text: 'Responded'), Tab(text: 'Closed')],
          ),
        ),
        body: TabBarView(
          children: [
            _RequestsTab(filter: 'NEW'),
            _RequestsTab(filter: 'RESPONDED'),
            _RequestsTab(filter: 'CLOSED'),
          ],
        ),
      ),
    );
  }
}

class _RequestsTab extends ConsumerWidget {
  const _RequestsTab({required this.filter});

  final String filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(requestListProvider(filter));

    if (state.loading && state.requests.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.brandRed));
    }
    if (state.error != null) {
      return _ErrorView(message: state.error!, onRetry: () => ref.read(requestListProvider(filter).notifier).load(filter: filter));
    }
    if (state.requests.isEmpty) {
      return _EmptyView(filter: filter);
    }
    return RefreshIndicator(
      color: AppColors.brandRed,
      onRefresh: () => ref.read(requestListProvider(filter).notifier).load(filter: filter),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.requests.length,
        itemBuilder: (context, index) => RequestCard(request: state.requests[index]),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.filter});

  final String filter;

  @override
  Widget build(BuildContext context) {
    final (icon, title, subtitle) = switch (filter) {
      'NEW' => (
          Icons.inbox_outlined,
          'No new requirements right now',
          'New store requirements will appear here when they match\nyour service area and categories.',
        ),
      'RESPONDED' => (
          Icons.reply_outlined,
          'No responded requirements',
          'Requirements you have quoted on or declined will appear here.',
        ),
      _ => (
          Icons.history_outlined,
          'Nothing closed or expired',
          'Closed and expired requirements will appear here.',
        ),
    };
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: AppColors.subtle),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: AppColors.inkSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.subtle, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, size: 48, color: AppColors.subtle),
            const SizedBox(height: 12),
            const Text(
              'No internet connection',
              style: TextStyle(color: AppColors.ink, fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Check your connection and try again.',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
