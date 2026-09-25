import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/procurement_api.dart';

/// Status chip for the request card (never color alone — text always shown).
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.color, required this.background});

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class RequestCard extends StatelessWidget {
  const RequestCard({super.key, required this.request});

  final VendorRequest request;

  @override
  Widget build(BuildContext context) {
    final deadline = request.responseDeadline;
    final countdown = deadline?.difference(DateTime.now());
    final countdownText = countdown == null
        ? null
        : countdown.isNegative
            ? 'Closed'
            : countdown.inHours >= 1
                ? 'Closes in ${countdown.inHours} h'
                : 'Closes in ${countdown.inMinutes.clamp(0, 59)} min';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/requests/${request.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      request.shopName,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
                    ),
                  ),
                  StatusChip(
                    label: request.isFixedOffer ? 'Fixed Offer' : 'RFQ',
                    color: request.isFixedOffer ? AppColors.brandRed : AppColors.info,
                    background: request.isFixedOffer ? AppColors.brandRedSurface : AppColors.infoSurface,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                request.requestNumber,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.subtle),
              ),
              const SizedBox(height: 10),
              Text(
                request.items
                    .map((item) => '${item.itemName} ${_fmt(item.requestedQuantity)} ${item.unit}')
                    .join('  |  '),
                style: const TextStyle(fontSize: 12, color: AppColors.inkSecondary, height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 13, color: AppColors.muted),
                  const SizedBox(width: 4),
                  Text(
                    'Required: ${_dateLabel(request.requiredDeliveryAt)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                  const Spacer(),
                  if (countdownText != null)
                    Text(
                      countdownText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: countdown != null && !countdown.isNegative && countdown.inMinutes < 60
                            ? AppColors.brandRed
                            : AppColors.muted,
                      ),
                    ),
                ],
              ),
              if (request.isFixedOffer && request.offerTotal != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Offer: ₹${NumberFormat('#,##0.##').format(request.offerTotal)}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.brandRed),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(num value) => NumberFormat('#,##0.##').format(value);

  String _dateLabel(DateTime? date) {
    if (date == null) return '—';
    final now = DateTime.now();
    final sameDay = date.year == now.year && date.month == now.month && date.day == now.day;
    if (sameDay) return 'Today, ${DateFormat('h:mm a').format(date)}';
    return DateFormat('dd MMM, h:mm a').format(date);
  }
}
