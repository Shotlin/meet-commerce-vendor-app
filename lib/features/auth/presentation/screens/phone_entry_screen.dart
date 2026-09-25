import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';

class PhoneEntryScreen extends ConsumerStatefulWidget {
  const PhoneEntryScreen({super.key});

  @override
  ConsumerState<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends ConsumerState<PhoneEntryScreen> {
  final _controller = TextEditingController();
  bool _sending = false;
  String? _error;

  Future<void> _sendCode() async {
    final phone = _controller.text.trim();
    if (phone.length < 10) {
      setState(() => _error = 'Enter a valid mobile number');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).sendOtp(phone);
      if (mounted) context.push('/otp/$phone');
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text(
                'FreshCuts\nVendor',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                      height: 1.1,
                    ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Sign in with your registered vendor mobile number to view store requirements and manage supplies.',
                style: TextStyle(color: AppColors.muted, fontSize: 14, height: 1.4),
              ),
              const Spacer(),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Mobile number',
                  hintText: '9000000001',
                  prefixText: '+91 ',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _sending ? null : _sendCode,
                child: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.surface),
                      )
                    : const Text('Send Code'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
