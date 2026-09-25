import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/profile_api.dart';
import '../providers/profile_provider.dart';

/// Documents — KYC document status + submission. The backend only accepts
/// new submissions while a vendor is still mid-onboarding
/// (PENDING_ONBOARDING / CORRECTION_REQUIRED — see KycStatus.canSubmitDocuments);
/// an already-ACTIVE vendor (like every current demo account) sees their
/// document history read-only with an honest explanation, not a broken
/// upload button.
class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  Future<void> _pickAndSubmit(String documentType) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 85) ??
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref.read(kycProvider.notifier).submitDocument(
          documentType: documentType,
          filePath: picked.path,
        );
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(ok ? 'Document submitted' : ref.read(kycProvider).error ?? 'Upload failed'),
    ));
  }

  Future<void> _chooseDocumentType() async {
    final type = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Choose document type', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink)),
              ),
            ),
            ...kycDocumentTypes.entries.map((entry) => ListTile(
                  title: Text(entry.value, style: const TextStyle(fontSize: 14, color: AppColors.ink)),
                  onTap: () => Navigator.of(sheetContext).pop(entry.key),
                )),
          ],
        ),
      ),
    );
    if (type != null) await _pickAndSubmit(type);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(kycProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Documents')),
      body: state.loading && state.status == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.brandRed))
          : state.error != null && state.status == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off, size: 48, color: AppColors.subtle),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(state.error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.inkSecondary, fontSize: 13)),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(onPressed: () => ref.read(kycProvider.notifier).load(), child: const Text('Try Again')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.brandRed,
                  onRefresh: () => ref.read(kycProvider.notifier).load(),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _StatusBanner(status: state.status!),
                      const SizedBox(height: 16),
                      const Text('Submitted documents', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
                      const SizedBox(height: 10),
                      if (state.status!.documents.isEmpty)
                        const Text('No documents submitted yet.', style: TextStyle(fontSize: 12, color: AppColors.muted))
                      else
                        ...state.status!.documents.map((doc) => _DocumentTile(doc: doc)),
                      if (state.error != null) ...[
                        const SizedBox(height: 12),
                        Text(state.error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
                      ],
                      const SizedBox(height: 20),
                      if (state.status!.canSubmitDocuments)
                        FilledButton.icon(
                          onPressed: state.uploading ? null : _chooseDocumentType,
                          icon: state.uploading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.surface),
                                )
                              : const Icon(Icons.add_a_photo_outlined, size: 18),
                          label: Text(state.uploading ? 'Uploading…' : 'Submit a Document'),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: AppColors.infoSurface, borderRadius: BorderRadius.circular(12)),
                          child: const Text(
                            "Document updates aren't available once your account is fully active — contact FreshCuts support to update your documents.",
                            style: TextStyle(fontSize: 12, color: AppColors.info, height: 1.4),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});

  final KycStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(status.isActive ? Icons.verified_outlined : Icons.hourglass_top_outlined,
              color: status.isActive ? AppColors.success : AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Onboarding status: ${status.status.replaceAll('_', ' ')}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.doc});

  final KycDocument doc;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.description_outlined, color: AppColors.muted, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(kycDocumentTypes[doc.documentType] ?? doc.documentType,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
                if (doc.createdAt != null)
                  Text(DateFormat('dd MMM yyyy').format(doc.createdAt!), style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              ],
            ),
          ),
          if (doc.status != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: AppColors.canvas, borderRadius: BorderRadius.circular(8)),
              child: Text(doc.status!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.muted)),
            ),
        ],
      ),
    );
  }
}
