import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/profile_api.dart';
import '../providers/profile_provider.dart';

/// Business Info — legal name, trade license number, registered address.
/// Backed by `vendor_profiles` via `PATCH /vendors/:id/profile`.
class BusinessInfoScreen extends ConsumerStatefulWidget {
  const BusinessInfoScreen({super.key});

  @override
  ConsumerState<BusinessInfoScreen> createState() => _BusinessInfoScreenState();
}

class _BusinessInfoScreenState extends ConsumerState<BusinessInfoScreen> {
  final _legalName = TextEditingController();
  final _tradeLicense = TextEditingController();
  final _addressLine1 = TextEditingController();
  final _addressLine2 = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _pincode = TextEditingController();
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_legalName, _tradeLicense, _addressLine1, _addressLine2, _city, _state, _pincode]) {
      c.dispose();
    }
    super.dispose();
  }

  void _seed(VendorProfile profile) {
    if (_initialized) return;
    _initialized = true;
    _legalName.text = profile.legalName ?? '';
    _tradeLicense.text = profile.tradeLicenseNumber ?? '';
    _addressLine1.text = profile.addressLine1 ?? '';
    _addressLine2.text = profile.addressLine2 ?? '';
    _city.text = profile.city ?? '';
    _state.text = profile.state ?? '';
    _pincode.text = profile.pincode ?? '';
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await ref.read(vendorProfileProvider.notifier).saveBusinessInfo(
          legalName: _legalName.text.trim(),
          tradeLicenseNumber: _tradeLicense.text.trim(),
          addressLine1: _addressLine1.text.trim(),
          addressLine2: _addressLine2.text.trim(),
          city: _city.text.trim(),
          state_: _state.text.trim(),
          pincode: _pincode.text.trim(),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Business info saved')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vendorProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Business Info')),
      body: state.loading && state.profile == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.brandRed))
          : state.error != null && state.profile == null
              ? _ErrorState(
                  message: state.error!,
                  onRetry: () => ref.read(vendorProfileProvider.notifier).load(),
                )
              : Builder(builder: (context) {
                  _seed(state.profile!);
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      TextField(controller: _legalName, decoration: const InputDecoration(labelText: 'Legal business name')),
                      const SizedBox(height: 12),
                      TextField(controller: _tradeLicense, decoration: const InputDecoration(labelText: 'Trade license number')),
                      const SizedBox(height: 12),
                      TextField(controller: _addressLine1, decoration: const InputDecoration(labelText: 'Address line 1')),
                      const SizedBox(height: 12),
                      TextField(controller: _addressLine2, decoration: const InputDecoration(labelText: 'Address line 2 (optional)')),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: _city, decoration: const InputDecoration(labelText: 'City'))),
                          const SizedBox(width: 12),
                          Expanded(child: TextField(controller: _state, decoration: const InputDecoration(labelText: 'State'))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _pincode,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Pincode'),
                      ),
                      if (state.error != null) ...[
                        const SizedBox(height: 12),
                        Text(state.error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.surface),
                              )
                            : const Text('Save'),
                      ),
                    ],
                  );
                }),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, size: 48, color: AppColors.subtle),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.inkSecondary, fontSize: 13)),
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Try Again')),
        ],
      ),
    );
  }
}
