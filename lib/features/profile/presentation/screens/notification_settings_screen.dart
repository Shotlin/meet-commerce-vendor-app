import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/profile_api.dart';
import '../providers/profile_provider.dart';

/// Notification Settings — where order/requirement notifications for this
/// business should go. Backed by `vendor_settings` via
/// `PATCH /vendors/:id/settings`. There is no granular per-category toggle
/// system on the backend today (no push-notification-preferences model for
/// vendors) — this screen only offers what's real: the contact channels.
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends ConsumerState<NotificationSettingsScreen> {
  final _email = TextEditingController();
  final _phone = TextEditingController();
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _seed(VendorProfile profile) {
    if (_initialized) return;
    _initialized = true;
    _email.text = profile.notificationEmail ?? '';
    _phone.text = profile.notificationPhone ?? '';
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await ref.read(vendorProfileProvider.notifier).saveNotificationSettings(
          notificationEmail: _email.text.trim(),
          notificationPhone: _phone.text.trim(),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification settings saved')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vendorProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notification Settings')),
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
                      const Text(
                        'New requirement and order alerts for this business go to these contacts. In-app alerts (the badge count on Requests) always stay on.',
                        style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Notification email'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Notification phone'),
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
