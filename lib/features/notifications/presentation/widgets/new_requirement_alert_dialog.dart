import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/socket/socket_service.dart';
import '../../../../core/theme/app_colors.dart';

/// Full-screen "new requirement" alert — shown the moment a
/// `request_published` event arrives over the socket for this vendor,
/// deliberately loud/hard to miss (mirrors a ride-hailing driver app's
/// new-job alert): the caller starts the looping sound before this opens
/// and stops it when the dialog closes, however it closes.
Future<void> showNewRequirementAlert(
  BuildContext context,
  ProcurementSocketEvent event,
) {
  HapticFeedback.heavyImpact();
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black87,
    builder: (context) => _NewRequirementAlertDialog(event: event),
  );
}

class _NewRequirementAlertDialog extends StatelessWidget {
  const _NewRequirementAlertDialog({required this.event});

  final ProcurementSocketEvent event;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        insetPadding: const EdgeInsets.all(24),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppColors.brandRedSurface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.campaign_rounded, color: AppColors.brandRed, size: 36),
              ),
              const SizedBox(height: 20),
              const Text(
                'New Requirement',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink),
              ),
              const SizedBox(height: 8),
              Text(
                event.body.isNotEmpty ? event.body : event.title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: AppColors.inkSecondary, height: 1.4),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandRed,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    if (event.requestId != null) {
                      context.push('/requests/${event.requestId}');
                    } else {
                      context.go('/requests');
                    }
                  },
                  child: const Text('View Requirement', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Dismiss', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
