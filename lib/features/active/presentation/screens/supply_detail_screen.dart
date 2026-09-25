import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/supplies_api.dart';
import '../providers/supplies_provider.dart';
import '../widgets/supply_card.dart' show supplyChip;

/// Supply detail — vertical timeline stepper, items, commercial summary,
/// evidence section, processing history (blueprint §15.8, §12). The primary
/// CTA becomes active in Big Phase 11's state machine.
class SupplyDetailScreen extends ConsumerWidget {
  const SupplyDetailScreen({super.key, required this.supplyId});

  final String supplyId;

  static const _stages = [
    'AWARDED',
    'ACCEPTED',
    'PROCESSING',
    'CLEANING',
    'VIDEO_SUBMITTED',
    'PACKED',
    'DISPATCHED',
    'RECEIVED',
    'CLOSED',
  ];

  int _stageIndex(String status) {
    final idx = _stages.indexOf(status);
    if (idx >= 0) return idx;
    switch (status) {
      case 'READY_FOR_DISPATCH':
        return _stages.indexOf('PACKED');
      case 'DELIVERED_PENDING_RECEIPT':
        return _stages.indexOf('DISPATCHED');
      case 'REJECTED_AT_RECEIPT':
        return _stages.indexOf('RECEIVED');
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(supplyDetailProvider(supplyId));
    final supply = state.supply;

    String? nextAction;
    if (supply != null) {
      nextAction = switch (supply.status) {
        'AWARDED' => 'Mark Accepted',
        'ACCEPTED' => 'Mark Processing Started',
        'PROCESSING' => 'Mark Cleaning Started',
        'CLEANING' => null, // handled below: upload video or mark packed
        'PACKED' => 'Mark Ready for Dispatch',
        'READY_FOR_DISPATCH' => 'Mark Dispatched',
        _ => null,
      };
      if (supply.status == 'CLEANING' && supply.evidence.isNotEmpty) {
        nextAction = 'Mark Packed';
      }
    }

    if (state.loading && supply == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.brandRed)),
      );
    }
    if (supply == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_off, size: 48, color: AppColors.subtle),
              const SizedBox(height: 12),
              Text(state.error ?? 'Supply order unavailable',
                  textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: () => context.pop(), child: const Text('Go Back')),
            ],
          ),
        ),
      );
    }

    final currentIndex = _stageIndex(supply.status);

    return Scaffold(
      appBar: AppBar(title: Text(supply.supplyNumber)),
      bottomNavigationBar: _stickyActions(context, ref, supply, nextAction),
      body: ListView(
        padding: const EdgeInsets.all(16).copyWith(bottom: 40),
        children: [
          Row(
            children: [
              supplyChip(supply.status),
              const SizedBox(width: 8),
              Text(
                supply.sourceMode == 'FIXED_OFFER' ? 'Fixed Offer' : 'RFQ',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Vertical progress stepper (blueprint §12: clearer than compressed
          // horizontal nodes on small devices).
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                for (var i = 0; i < _stages.length; i++)
                  _StageRow(
                    label: _stages[i].replaceAll('_', ' '),
                    isDone: i < currentIndex,
                    isCurrent: i == currentIndex,
                    isLast: i == _stages.length - 1,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Card(
            title: 'Items',
            child: Column(
              children: [
                for (final item in supply.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(item['item_name']?.toString() ?? 'Item',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
                        ),
                        Text(
                          '${_fmt(item['agreed_quantity'])} ${item['unit'] ?? ''} × ₹${_fmt(item['agreed_unit_price'])}',
                          style: const TextStyle(fontSize: 12, color: AppColors.inkSecondary),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          _Card(
            title: 'Commercial summary',
            child: Column(
              children: [
                _kv('Award value', '₹${NumberFormat('#,##0.##').format(supply.awardAmount)}'),
                _kv('Destination', '${supply.shopName} · ${supply.shopCity}'),
                _kv('Deliver by', supply.promisedDeliveryAt == null
                    ? '—'
                    : DateFormat('dd MMM, h:mm a').format(supply.promisedDeliveryAt!)),
              ],
            ),
          ),
          _Card(
            title: 'Quality evidence',
            child: supply.evidence.isEmpty
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.warningSurface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Quality evidence required\nRecord the cleaned product before packing.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink, height: 1.5),
                        ),
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: () => _uploadVideo(context, ref),
                        icon: const Icon(Icons.videocam, size: 18),
                        label: const Text('Record / Upload Video'),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Mark Packed is disabled until a valid quality video is uploaded and accepted.',
                        style: TextStyle(fontSize: 11, color: AppColors.muted),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      for (final item in supply.evidence)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.videocam, size: 16, color: AppColors.success),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Evidence submitted · ${DateFormat('dd MMM, h:mm a').format(DateTime.tryParse('${item['created_at']}') ?? DateTime.now())}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.ink),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
          if (supply.events.isNotEmpty)
            _Card(
              title: 'Processing history',
              child: Column(
                children: [
                  for (final event in supply.events)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 5),
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(color: AppColors.brandRed, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${event['to_status']}'.replaceAll('_', ' '),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink)),
                                Text(
                                  DateFormat('dd MMM, h:mm a')
                                      .format(DateTime.tryParse('${event['created_at']}') ?? DateTime.now()),
                                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _uploadVideo(BuildContext context, WidgetRef ref) async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(minutes: 3),
    );
    final file = picked ?? await picker.pickVideo(source: ImageSource.gallery);
    if (file == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const _UploadProgressDialog(),
    ));

    try {
      final suppliesApi = ref.read(suppliesApiProvider);
      await suppliesApi.uploadQualityVideo(supplyId, file.path, onProgress: (sent, total) {
        final progress = total > 0 ? sent / total : 0.0;
        _uploadProgress.value = progress;
      });
      await ref.read(supplyDetailProvider(supplyId).notifier).load(supplyId);
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Evidence submitted — you can now mark the supply packed.')),
      );
    } catch (error) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Video upload failed. Check your connection and try again. (${error.toString().split(':').last.trim()})')),
      );
    }
  }

  static final ValueNotifier<double> _uploadProgress = ValueNotifier(0);

  Widget _stickyActions(
    BuildContext context,
    WidgetRef ref,
    SupplyOrderModel? supply,
    String? nextAction,
  ) {
    if (supply == null || nextAction == null) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: FilledButton(
        onPressed: () async {
          final notifier = ref.read(supplyDetailProvider(supplyId).notifier);
          final target = switch (nextAction) {
            'Mark Accepted' => 'ACCEPTED',
            'Mark Processing Started' => 'PROCESSING',
            'Mark Cleaning Started' => 'CLEANING',
            'Mark Packed' => 'PACKED',
            'Mark Ready for Dispatch' => 'READY_FOR_DISPATCH',
            'Mark Dispatched' => 'DISPATCHED',
            _ => null,
          };
          if (target == null) return;

          Map<String, dynamic> body = {'status': target};
          if (target == 'DISPATCHED') {
            final reference = await _promptText(context, title: 'Dispatch', label: 'Delivery note / challan reference (optional)');
            if (reference == null) return; // cancelled
            if (reference.isNotEmpty) body['delivery_reference'] = reference;
          }
          final ok = await notifier.updateStatus(supply.id, body);
          if (ok && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(target == 'ACCEPTED' ? 'Order accepted' : 'Marked ${target.replaceAll('_', ' ').toLowerCase()}')),
            );
          } else if (!ok && context.mounted) {
            final error = ref.read(supplyDetailProvider(supplyId)).error;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? 'Update failed')));
          }
        },
        child: Text(nextAction),
      ),
    );
  }

  Future<String?> _promptText(BuildContext context, {required String title, required String label}) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(onPressed: () => dialogContext.pop(null), child: const Text('Cancel')),
          FilledButton(onPressed: () => dialogContext.pop(controller.text.trim()), child: const Text('Confirm')),
        ],
      ),
    );
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.muted)),
          Text(value, style: const TextStyle(fontSize: 12, color: AppColors.ink)),
        ],
      ),
    );
  }

  String _fmt(dynamic value) => NumberFormat('#,##0.##').format(num.tryParse('$value') ?? 0);
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 0.4)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({
    required this.label,
    required this.isDone,
    required this.isCurrent,
    required this.isLast,
  });

  final String label;
  final bool isDone;
  final bool isCurrent;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isDone
                    ? AppColors.success
                    : isCurrent
                        ? AppColors.brandRed
                        : AppColors.canvas,
                shape: BoxShape.circle,
              ),
              child: isDone
                  ? const Icon(Icons.check, size: 14, color: AppColors.surface)
                  : Center(
                      child: Text(
                        '',
                        style: const TextStyle(fontSize: 10, color: AppColors.muted),
                      ),
                    ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 18,
                color: isDone ? AppColors.success : AppColors.border,
              ),
          ],
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
            color: isCurrent ? AppColors.ink : AppColors.muted,
          ),
        ),
      ],
    );
  }
}

class _UploadProgressDialog extends StatelessWidget {
  const _UploadProgressDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: ValueListenableBuilder<double>(
        valueListenable: SupplyDetailScreen._uploadProgress,
        builder: (context, value, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Uploading quality video…',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink),
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(value: value <= 0 ? null : value, color: AppColors.brandRed),
          ],
        ),
      ),
    );
  }
}
