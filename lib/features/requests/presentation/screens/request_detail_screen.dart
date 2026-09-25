import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/procurement_api.dart';
import '../providers/request_detail_provider.dart';
import '../widgets/request_card.dart' show StatusChip;

/// Request detail — fixed offer: sticky Decline / Accept Offer; RFQ: sticky
/// Submit/Edit Quote. After award to another vendor the actions disappear
/// (blueprint §15.5, §15.6, §5.4 sticky bottom actions).
class RequestDetailScreen extends ConsumerStatefulWidget {
  const RequestDetailScreen({super.key, required this.requestId});

  final String requestId;

  @override
  ConsumerState<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends ConsumerState<RequestDetailScreen> {
  @override
  void initState() {
    super.initState();
    // requestDetailProvider is a per-id family that starts empty until
    // something explicitly loads it. Nothing did: request_card.dart's
    // onTap just pushes this route with no pre-fetch, so opening a request
    // straight from the list always showed "Requirement unavailable" —
    // even for a real, existing, correctly-targeted request. Load on
    // every open (not just when never-loaded before), since the request's
    // own state (recipientStatus, myQuote, deadline) can genuinely change
    // between visits.
    Future.microtask(
      () => ref.read(requestDetailProvider(widget.requestId).notifier).load(widget.requestId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final requestId = widget.requestId;
    final state = ref.watch(requestDetailProvider(requestId));
    final notifier = ref.read(requestDetailProvider(requestId).notifier);

    if (state.loading && state.request == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.brandRed)),
      );
    }
    if (state.request == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_off, size: 48, color: AppColors.subtle),
              const SizedBox(height: 12),
              Text(
                state.error ?? 'Requirement unavailable',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: () => context.pop(), child: const Text('Go Back')),
            ],
          ),
        ),
      );
    }

    final request = state.request!;

    return Scaffold(
      appBar: AppBar(title: Text(request.requestNumber)),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16).copyWith(bottom: 120),
            children: [
              Row(
                children: [
                  StatusChip(
                    label: request.isFixedOffer ? 'Fixed Offer' : 'RFQ',
                    color: request.isFixedOffer ? AppColors.brandRed : AppColors.info,
                    background: request.isFixedOffer ? AppColors.brandRedSurface : AppColors.infoSurface,
                  ),
                  const SizedBox(width: 8),
                  StatusChip(label: request.status, color: AppColors.muted, background: AppColors.canvas),
                ],
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Store & destination',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.shopName,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink)),
                    const SizedBox(height: 2),
                    Text(request.shopCity, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.local_shipping_outlined, size: 14, color: AppColors.muted),
                        const SizedBox(width: 4),
                        Text(
                          'Deliver by ${_fmtDate(request.requiredDeliveryAt)}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.inkSecondary),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 14, color: AppColors.muted),
                        const SizedBox(width: 4),
                        Text(
                          request.isFixedOffer ? 'Offer expires ${_fmtDate(request.responseDeadline)}' : 'Quotes close ${_fmtDate(request.responseDeadline)}',
                          style: const TextStyle(fontSize: 12, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _SectionCard(
                title: 'Items required',
                child: Column(
                  children: [
                    for (final item in request.items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.itemName,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
                                  if (item.categoryName != null)
                                    Text(item.categoryName!,
                                        style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                                ],
                              ),
                            ),
                            Text(
                              '${_fmtNum(item.requestedQuantity)} ${item.unit}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink),
                            ),
                            if (request.isFixedOffer && item.fixedUnitPrice != null) ...[
                              const SizedBox(width: 10),
                              Text(
                                '₹${_fmtNum(item.fixedUnitPrice!)}',
                                style: const TextStyle(fontSize: 13, color: AppColors.inkSecondary),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (request.isFixedOffer && request.offerTotal != null)
                _SectionCard(
                  title: 'Commercial offer',
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total offer value',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.inkSecondary)),
                      Text('₹${_fmtNum(request.offerTotal!)}',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.brandRed)),
                    ],
                  ),
                ),
              if (request.qualityInstructions != null && request.qualityInstructions!.isNotEmpty)
                _SectionCard(
                  title: 'Quality & preparation',
                  child: Text(
                    request.qualityInstructions!,
                    style: const TextStyle(fontSize: 12, color: AppColors.inkSecondary, height: 1.5),
                  ),
                ),
              if (request.notes != null && request.notes!.isNotEmpty)
                _SectionCard(
                  title: 'Notes',
                  child: Text(
                    request.notes!,
                    style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.5),
                  ),
                ),
              if (state.actionMessage != null)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.infoSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(state.actionMessage!,
                      style: const TextStyle(fontSize: 12, color: AppColors.info, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          // Sticky bottom action area above the safe area (blueprint §5.4).
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  16, 12, 16, 16 + MediaQuery.of(context).padding.bottom),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: _buildActions(context, ref, request, notifier),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(
    BuildContext context,
    WidgetRef ref,
    VendorRequest request,
    RequestDetailNotifier notifier,
  ) {
    if (!request.isPublished) {
      return Text(
        request.awardedElsewhereLabel,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted),
      );
    }

    if (request.deadlinePassed && request.isOpenToRespond) {
      return const Text(
        'The response deadline has passed.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.error),
      );
    }

    if (!request.isOpenToRespond) {
      final label = switch (request.recipientStatus) {
        'AWARDED' => 'You won this requirement — see Active supplies.',
        'RESPONDED' => request.isFixedOffer ? 'You already responded.' : 'You have a live quote — edit or withdraw it.',
        'DECLINED' => 'You declined this requirement.',
        'NOT_SELECTED' => 'Awarded to another vendor.',
        'EXPIRED' => 'This requirement expired.',
        _ => 'No action available.',
      };
      final hasLiveQuote = request.recipientStatus == 'RESPONDED' && !request.isFixedOffer && request.myQuote != null;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: request.recipientStatus == 'RESPONDED' && request.isFixedOffer
                      ? null
                      : () => context.push('/requests/${request.id}/quote'),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.ink),
                  child: Text(request.recipientStatus == 'RESPONDED' ? 'Edit Quote' : 'View',
                      style: const TextStyle(fontSize: 14)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 0,
                child: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              ),
            ],
          ),
          if (hasLiveQuote) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  final confirmed = await _confirm(
                    context,
                    title: 'Withdraw quote?',
                    body: 'The store will no longer see your quote for this requirement.',
                    confirmLabel: 'Withdraw',
                    destructive: true,
                  );
                  if (confirmed) await notifier.withdrawQuote(request.id, request.myQuote!.id);
                },
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Withdraw Quote'),
              ),
            ),
          ],
        ],
      );
    }

    if (request.isFixedOffer) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () async {
                final confirmed = await _confirm(
                  context,
                  title: 'Decline requirement?',
                  body: 'You will no longer be able to respond to this requirement.',
                  confirmLabel: 'Decline',
                  destructive: true,
                );
                if (confirmed) await notifier.decline(request.id);
              },
              child: const Text('Decline'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: () async {
                final confirmed = await _confirm(
                  context,
                  title: 'Accept offer?',
                  body:
                      'Accepting commits you to supply this order for ₹${_fmtNum(request.offerTotal ?? 0)}. The first eligible vendor to accept wins.',
                  confirmLabel: 'Accept Offer',
                );
                if (confirmed) await notifier.accept(request.id);
              },
              child: const Text('Accept Offer'),
            ),
          ),
        ],
      );
    }

    return FilledButton(
      onPressed: () => context.push('/requests/${request.id}/quote'),
      child: const Text('Submit Quote'),
    );
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
        content: Text(body, style: const TextStyle(fontSize: 13, color: AppColors.inkSecondary, height: 1.5)),
        actions: [
          TextButton(onPressed: () => dialogContext.pop(false), child: const Text('Cancel')),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: AppColors.error)
                : null,
            onPressed: () => dialogContext.pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  String _fmtDate(DateTime? date) {
    if (date == null) return '—';
    return DateFormat('dd MMM, h:mm a').format(date);
  }

  String _fmtNum(num value) => NumberFormat('#,##0.##').format(value);
}

extension on VendorRequest {
  String get awardedElsewhereLabel {
    if (status == 'AWARDED') return 'Closed — awarded to another vendor.';
    if (status == 'CANCELLED') return 'This requirement was cancelled by the store.';
    if (status == 'EXPIRED') return 'This requirement expired.';
    if (status == 'COMPLETED') return 'This requirement is complete.';
    return 'Closed.';
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

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
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
