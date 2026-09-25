import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/profile_api.dart';
import '../providers/profile_provider.dart';

/// Tax & Licenses — GSTIN, FSSAI license, PAN number.
/// Backed by `vendor_profiles` via `PATCH /vendors/:id/profile`.
class TaxLicensesScreen extends ConsumerStatefulWidget {
  const TaxLicensesScreen({super.key});

  @override
  ConsumerState<TaxLicensesScreen> createState() => _TaxLicensesScreenState();
}

class _TaxLicensesScreenState extends ConsumerState<TaxLicensesScreen> {
  final _gstin = TextEditingController();
  final _fssai = TextEditingController();
  final _pan = TextEditingController();
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _gstin.dispose();
    _fssai.dispose();
    _pan.dispose();
    super.dispose();
  }

  void _seed(VendorProfile profile) {
    if (_initialized) return;
    _initialized = true;
    _gstin.text = profile.gstin ?? '';
    _fssai.text = profile.fssaiLicense ?? '';
    _pan.text = profile.panNumber ?? '';
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await ref.read(vendorProfileProvider.notifier).saveTaxAndLicenses(
          gstin: _gstin.text.trim(),
          fssaiLicense: _fssai.text.trim(),
          panNumber: _pan.text.trim(),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tax & license details saved')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vendorProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tax & Licenses')),
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
                        onPressed: () => ref.read(vendorProfileProvider.notifier).load(),
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : Builder(builder: (context) {
                  _seed(state.profile!);
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      TextField(
                        controller: _gstin,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(labelText: 'GSTIN'),
                      ),
                      const SizedBox(height: 12),
                      TextField(controller: _fssai, decoration: const InputDecoration(labelText: 'FSSAI license number')),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _pan,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(labelText: 'PAN number'),
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
