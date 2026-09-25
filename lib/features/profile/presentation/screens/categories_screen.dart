import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/profile_api.dart';
import '../providers/profile_provider.dart';

/// Categories — what this vendor supplies (Chicken, Mutton, Fish & Seafood,
/// Eggs, …). Backed by `vendor_supply_categories` via the shared
/// service-profile endpoint — see ServiceProfileNotifier.saveCategories for
/// why pincodes/store assignments are preserved unchanged on every save.
class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  Set<String>? _selectedIds;
  bool _saving = false;

  void _seed(ServiceProfile profile) {
    _selectedIds ??= profile.categoryIds.toSet();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await ref.read(serviceProfileProvider.notifier).saveCategories(_selectedIds!.toList());
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Categories saved')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(serviceProfileProvider);
    final categoriesAsync = ref.watch(allCategoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      body: profileState.loading && profileState.profile == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.brandRed))
          : profileState.error != null && profileState.profile == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off, size: 48, color: AppColors.subtle),
                      const SizedBox(height: 12),
                      Text(profileState.error!, style: const TextStyle(color: AppColors.inkSecondary, fontSize: 13)),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => ref.read(serviceProfileProvider.notifier).load(),
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : categoriesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.brandRed)),
                  error: (error, _) => Center(
                    child: Text('Could not load categories', style: const TextStyle(color: AppColors.inkSecondary, fontSize: 13)),
                  ),
                  data: (allCategories) {
                    _seed(profileState.profile!);
                    return Column(
                      children: [
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              const Text(
                                'You\'ll only receive requirements for the categories checked below.',
                                style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4),
                              ),
                              const SizedBox(height: 12),
                              ...allCategories.map((category) {
                                final checked = _selectedIds!.contains(category.id);
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: CheckboxListTile(
                                    value: checked,
                                    onChanged: (value) {
                                      setState(() {
                                        if (value == true) {
                                          _selectedIds!.add(category.id);
                                        } else {
                                          _selectedIds!.remove(category.id);
                                        }
                                      });
                                    },
                                    activeColor: AppColors.brandRed,
                                    title: Text(category.name,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
                                    controlAffinity: ListTileControlAffinity.leading,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                );
                              }),
                              if (profileState.error != null) ...[
                                const SizedBox(height: 12),
                                Text(profileState.error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
                              ],
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: FilledButton(
                            onPressed: _saving ? null : _save,
                            child: _saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.surface),
                                  )
                                : const Text('Save'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
    );
  }
}
