import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/supplies_api.dart';
import '../../../requests/presentation/widgets/request_card.dart' show StatusChip;

/// Status → chip colors, shared by list and detail.
StatusChip supplyChip(String status) {
  final (color, background) = switch (status) {
    'AWARDED' => (AppColors.brandRed, AppColors.brandRedSurface),
    'PROCESSING' || 'CLEANING' => (AppColors.warning, AppColors.warningSurface),
    'VIDEO_SUBMITTED' || 'PACKED' || 'READY_FOR_DISPATCH' || 'DISPATCHED' => (AppColors.info, AppColors.infoSurface),
    'RECEIVED' || 'CLOSED' => (AppColors.success, AppColors.successSurface),
    'CANCELLED' || 'REJECTED_AT_RECEIPT' => (AppColors.error, AppColors.errorSurface),
    _ => (AppColors.muted, AppColors.canvas),
  };
  return StatusChip(
    label: status.replaceAll('_', ' '),
    color: color,
    background: background,
  );
}

class SupplyCard extends StatelessWidget {
  const SupplyCard({super.key, required this.supply});

  final SupplyOrderModel supply;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/supplies/${supply.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      supply.shopName,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
                    ),
                  ),
                  supplyChip(supply.status),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${supply.supplyNumber}${supply.requestNumber != null ? ' · ${supply.requestNumber}' : ''}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.subtle),
              ),
              const SizedBox(height: 10),
              Text(
                supply.itemSummary
                    .map((item) => '${_fmt(item['agreed_quantity'] ?? 0)} ${item['unit'] ?? ''} ${item['item_name'] ?? ''}')
                    .join('  |  '),
                style: const TextStyle(fontSize: 12, color: AppColors.inkSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    '₹${NumberFormat('#,##0.##').format(supply.awardAmount)}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink),
                  ),
                  const Spacer(),
                  if (supply.promisedDeliveryAt != null)
                    Text(
                      'Deliver by ${DateFormat('dd MMM, h:mm a').format(supply.promisedDeliveryAt!)}',
                      style: const TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(dynamic value) => NumberFormat('#,##0.##').format(num.tryParse('$value') ?? 0);
}
