import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/profile_api.dart';
import '../providers/profile_provider.dart';

/// Store Allotment — which real store(s) (branches) this vendor is
/// assigned to supply, shown by name/city rather than a raw pincode. Backed
/// by `vendor_store_assignments` via the shared service-profile endpoint.
///
/// Store assignment itself is intentionally READ-ONLY here — which store a
/// vendor supplies is the store's/admin's decision (set from the dashboard
/// or at onboarding), not something a vendor self-assigns. This matches
/// vendor-eligibility.js's `assigned_to_shop` fast path: an explicit
/// assignment always makes a vendor eligible for that store's requirements
/// regardless of pincode.
///
/// Delivery pincodes are a SEPARATE, secondary mechanism — a vendor can
/// still be matched to a store's requirements by pincode even with no
/// explicit assignment (area_match in vendor-eligibility.js) — kept below
/// as an editable, clearly-labeled section so that capability isn't lost,
/// but store allotment is the primary, most useful thing on this screen.
class StoreAllotmentScreen extends ConsumerStatefulWidget {
  const StoreAllotmentScreen({super.key});

  @override
  ConsumerState<StoreAllotmentScreen> createState() => _StoreAllotmentScreenState();
}

class _StoreAllotmentScreenState extends ConsumerState<StoreAllotmentScreen> {
  final _pincodeController = TextEditingController();
  List<String>? _pincodes;
  bool _saving = false;
  String? _fieldError;

  @override
  void dispose() {
    _pincodeController.dispose();
    super.dispose();
  }

  void _seed(ServiceProfile profile) {
    _pincodes ??= List<String>.from(profile.servicePincodes);
  }

  void _addPincode() {
    final value = _pincodeController.text.trim();
    if (!RegExp(r'^[1-9][0-9]{5}$').hasMatch(value)) {
      setState(() => _fieldError = 'Enter a valid 6-digit pincode');
      return;
    }
    if (_pincodes!.contains(value)) {
      setState(() => _fieldError = 'Already added');
      return;
    }
    setState(() {
      _pincodes = [..._pincodes!, value];
      _pincodeController.clear();
      _fieldError = null;
    });
  }

  void _removePincode(String pincode) {
    setState(() => _pincodes = _pincodes!.where((p) => p != pincode).toList());
  }

  Future<void> _savePincodes() async {
    setState(() => _saving = true);
    final ok = await ref.read(serviceProfileProvider.notifier).saveServicePincodes(_pincodes!);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delivery pincodes saved')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(serviceProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Store Allotment')),
      body: state.loading && state.profile == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.brandRed))
          : state.error != null && state.profile == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off, size: 48, color: AppColors.subtle),
                      const SizedBox(height: 12),
                      Text(state.error!, style: const TextStyle(color: AppColors.inkSecondary, fontSize: 13)),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => ref.read(serviceProfileProvider.notifier).load(),
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : Builder(builder: (context) {
                  _seed(state.profile!);
                  final stores = state.profile!.storeAssignments;
                  return Column(
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            const Text(
                              'Stores you\'re allotted to supply. Procurement requirements from these stores land in your Requests tab automatically.',
                              style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4),
                            ),
                            const SizedBox(height: 14),
                            if (stores.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.warningSurface,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Text(
                                  "You haven't been allotted to a store yet — contact FreshCuts support, or make sure you're serving one of your added delivery pincodes below.",
                                  style: TextStyle(fontSize: 12, color: AppColors.warning, height: 1.4),
                                ),
                              )
                            else
                              ...stores.map((store) => _StoreCard(store: store)),
                            const SizedBox(height: 24),
                            const Divider(color: AppColors.divider),
                            const SizedBox(height: 12),
                            const Text('Delivery Pincodes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
                            const SizedBox(height: 6),
                            const Text(
                              'An additional way to be matched to nearby requirements even without a direct store allotment above.',
                              style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _pincodeController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(6),
                                    ],
                                    decoration: InputDecoration(labelText: 'Add pincode', errorText: _fieldError),
                                    onSubmitted: (_) => _addPincode(),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                FilledButton(onPressed: _addPincode, child: const Text('Add')),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_pincodes!.isEmpty)
                              const Text('No delivery pincodes added yet.', style: TextStyle(fontSize: 12, color: AppColors.muted))
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _pincodes!
                                    .map((p) => Chip(
                                          label: Text(p),
                                          onDeleted: () => _removePincode(p),
                                          backgroundColor: AppColors.brandRedSurface,
                                          labelStyle: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600),
                                          deleteIconColor: AppColors.brandRed,
                                        ))
                                    .toList(),
                              ),
                            if (state.error != null) ...[
                              const SizedBox(height: 12),
                              Text(state.error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
                            ],
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: FilledButton(
                          onPressed: _saving ? null : _savePincodes,
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.surface),
                                )
                              : const Text('Save Pincodes'),
                        ),
                      ),
                    ],
                  );
                }),
    );
  }
}

class _StoreCard extends StatelessWidget {
  const _StoreCard({required this.store});

  final StoreAssignment store;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.brandRedSurface, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.storefront, color: AppColors.brandRed, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(store.shopName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink)),
                if (store.shopCity.isNotEmpty)
                  Text(store.shopCity, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: AppColors.successSurface, borderRadius: BorderRadius.circular(8)),
            child: const Text('Allotted', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.success)),
          ),
        ],
      ),
    );
  }
}
