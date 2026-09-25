import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';

class OtpVerifyScreen extends ConsumerStatefulWidget {
  const OtpVerifyScreen({super.key, required this.phone});

  final String phone;

  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends ConsumerState<OtpVerifyScreen> {
  final _controller = TextEditingController();
  bool _verifying = false;
  String? _error;

  Future<void> _verify() async {
    final code = _controller.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code');
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).verifyOtp(widget.phone, code);
      if (mounted) context.go('/home');
    } catch (error) {
      setState(() => _error = 'Invalid code. Please try again.');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Text(
                'Enter the code sent to +91 ${widget.phone}',
                style: const TextStyle(color: AppColors.muted, fontSize: 14),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 8),
                decoration: const InputDecoration(counterText: '', hintText: '123456'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _verifying ? null : _verify,
                child: _verifying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.surface),
                      )
                    : const Text('Verify & Sign In'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
