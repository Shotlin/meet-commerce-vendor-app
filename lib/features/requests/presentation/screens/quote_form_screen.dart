import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/procurement_api.dart';
import '../providers/request_detail_provider.dart';

/// RFQ quote form (blueprint §11): per-item requested/quoted quantity, unit
/// price, computed read-only line totals, grand total, promised delivery,
/// note. Inline validation; numeric keyboards; totals computed client-side
/// mirror the backend's authoritative computation.
class QuoteFormScreen extends ConsumerStatefulWidget {
  const QuoteFormScreen({super.key, required this.requestId});

  final String requestId;

  @override
  ConsumerState<QuoteFormScreen> createState() => _QuoteFormScreenState();
}

class _QuoteFormScreenState extends ConsumerState<QuoteFormScreen> {
  late final RequestDetailNotifier _notifier;
  final List<num> _quantities = [];
  final List<num> _prices = [];
  final List<TextEditingController> _quantityControllers = [];
  final List<TextEditingController> _priceControllers = [];
  final _noteController = TextEditingController();
  DateTime? _promisedDelivery;
  bool _submitting = false;
  bool _initialized = false;
  String? _error;
  bool get _isEditingExistingQuote => _notifier.currentRequest?.myQuote != null;

  @override
  void initState() {
    super.initState();
    _notifier = ref.read(requestDetailProvider(widget.requestId).notifier);
    if (_notifier.currentRequest == null) {
      Future.microtask(() => _notifier.load(widget.requestId));
    }
  }

  @override
  void dispose() {
    for (final c in _quantityControllers) {
      c.dispose();
    }
    for (final c in _priceControllers) {
      c.dispose();
    }
    _noteController.dispose();
    super.dispose();
  }

  // Runs exactly once, the first time the request's real items are
  // available — persistent per-item controllers are created here rather
  // than inline in the build method, so typing in a field doesn't fight a
  // brand-new controller being re-seeded from the reformatted value on every
  // rebuild. Pre-fills from the vendor's own existing quote when editing.
  void _ensureControllers(VendorRequest request) {
    if (_initialized) return;
    _initialized = true;

    final quote = request.myQuote;
    for (final item in request.items) {
      final existing = quote?.itemFor(item.id);
      final quantity = existing?.quotedQuantity ?? item.requestedQuantity;
      final price = existing?.unitPrice ?? item.fixedUnitPrice ?? 0;
      _quantities.add(quantity);
      _prices.add(price);
      _quantityControllers.add(TextEditingController(text: _fmt(quantity)));
      _priceControllers.add(TextEditingController(text: price == 0 ? '' : _fmt(price)));
    }
    if (quote?.note != null) _noteController.text = quote!.note!;
    _promisedDelivery = quote?.promisedDeliveryAt;
  }

  num get _grandTotal {
    var total = 0.0;
    for (var i = 0; i < _quantities.length; i++) {
      total += _quantities[i] * _prices[i];
    }
    return total;
  }

  Future<void> _submit() async {
    final request = _notifier.currentRequest;
    if (request == null) return;

    for (var i = 0; i < _quantities.length; i++) {
      if (_quantities[i] <= 0) {
        setState(() => _error = 'Quoted quantity for ${request.items[i].itemName} must be greater than zero.');
        return;
      }
      if (_prices[i] < 0) {
        setState(() => _error = 'Unit price cannot be negative.');
        return;
      }
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final ok = await _notifier.saveQuote(widget.requestId, {
      'items': [
        for (var i = 0; i < request.items.length; i++)
          request.items[i].toQuoteInput(quotedQuantity: _quantities[i], unitPrice: _prices[i]),
      ],
      if (_promisedDelivery != null) 'promised_delivery_at': _promisedDelivery!.toIso8601String(),
      if (_noteController.text.trim().isNotEmpty) 'note': _noteController.text.trim(),
    });

    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(requestDetailProvider(widget.requestId));
    final request = state.request;

    if (request == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Submit Quote')),
        body: state.loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.brandRed))
            : Center(child: Text(state.error ?? 'Loading…', style: const TextStyle(color: AppColors.muted))),
      );
    }
    _ensureControllers(request);
    final editing = _isEditingExistingQuote;

    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit Quote' : 'Submit Quote')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '${request.shopName} · ${request.requestNumber}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < request.items.length; i++) _itemCard(request, i),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Delivery promise & note',
                  child: Column(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 30)),
                          );
                          if (picked != null && context.mounted) {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: const TimeOfDay(hour: 17, minute: 0),
                            );
                            if (time != null && context.mounted) {
                              setState(() {
                                _promisedDelivery =
                                    DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
                              });
                            }
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Promised delivery'),
                          child: Text(
                            _promisedDelivery == null
                                ? 'Select date & time'
                                : DateFormat('dd MMM, h:mm a').format(_promisedDelivery!),
                            style: TextStyle(
                              fontSize: 13,
                              color: _promisedDelivery == null ? AppColors.subtle : AppColors.ink,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _noteController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Note to store (optional)',
                          hintText: 'e.g. Includes delivery to your cold storage',
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.errorSurface, borderRadius: BorderRadius.circular(12)),
                    child: Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),
          // Sticky bottom action with grand total (blueprint §5.1/§11).
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.of(context).padding.bottom),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Grand total', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                    Text(
                      '₹${NumberFormat('#,##0.##').format(_grandTotal)}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.surface),
                          )
                        : Text(editing ? 'Save Changes' : 'Submit Quote'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemCard(VendorRequest request, int index) {
    final item = request.items[index];
    final lineTotal = _quantities[index] * _prices[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(item.itemName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink)),
              ),
              Text(
                'Requested: ${_fmt(item.requestedQuantity)} ${item.unit}',
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Quoted quantity'),
                  controller: _quantityControllers[index],
                  onChanged: (value) =>
                      setState(() => _quantities[index] = num.tryParse(value) ?? 0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Unit price (₹)'),
                  controller: _priceControllers[index],
                  onChanged: (value) => setState(() => _prices[index] = num.tryParse(value) ?? 0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Item total: ₹${NumberFormat('#,##0.##').format(lineTotal)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.inkSecondary),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(num value) => NumberFormat('#,##0.##').format(value);
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
