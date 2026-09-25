import 'package:flutter_test/flutter_test.dart';
import 'package:freshcuts_vendor_app/features/profile/data/profile_api.dart';

void main() {
  group('VendorProfile.fromJson', () {
    test('parses profile and settings sub-objects from GET /vendors/:id', () {
      final profile = VendorProfile.fromJson({
        'id': 'v-1',
        'name': 'Kolkata Fresh Chicken Co.',
        'status': 'ACTIVE',
        'is_active': true,
        'profile': {
          'legal_name': 'Kolkata Fresh Chicken Pvt Ltd',
          'gstin': 'GST123',
          'city': 'Kolkata',
        },
        'settings': {
          'notification_email': 'ops@kolkatafreshchicken.test',
        },
      });

      expect(profile.name, 'Kolkata Fresh Chicken Co.');
      expect(profile.legalName, 'Kolkata Fresh Chicken Pvt Ltd');
      expect(profile.gstin, 'GST123');
      expect(profile.city, 'Kolkata');
      expect(profile.notificationEmail, 'ops@kolkatafreshchicken.test');
      expect(profile.notificationPhone, isNull);
    });

    test('tolerates missing profile/settings sub-objects (never-onboarded vendor)', () {
      final profile = VendorProfile.fromJson({
        'id': 'v-2',
        'name': 'Fresh Vendor',
        'status': 'PENDING_ONBOARDING',
        'is_active': true,
      });

      expect(profile.legalName, isNull);
      expect(profile.gstin, isNull);
      expect(profile.notificationEmail, isNull);
    });
  });

  group('ServiceProfile.fromJson', () {
    test('parses categories/pincodes/store assignments from the vendor-procurement service-profile response', () {
      final profile = ServiceProfile.fromJson({
        'vendor': {'id': 'v-1', 'name': 'Kolkata Fresh Chicken Co.', 'status': 'ACTIVE'},
        'categories': [
          {'category_id': 'cat-1', 'category_name': 'Chicken'},
        ],
        'service_pincodes': ['700001'],
        'store_assignments': [
          {'shop_id': 'shop-1', 'shop_name': 'FreshCuts — Kolkata', 'shop_city': 'Kolkata'},
        ],
      });

      expect(profile.categoryIds, ['cat-1']);
      expect(profile.servicePincodes, ['700001']);
      expect(profile.shopIds, ['shop-1']);
    });
  });

  group('KycStatus.canSubmitDocuments', () {
    // Mirrors the backend's own state machine
    // (vendor-kyc.service.js#ALLOWED_TRANSITIONS) — submission is only
    // accepted from these two states. Getting this wrong either hides the
    // upload button for a genuinely-new vendor who needs it, or shows it to
    // an already-active vendor who will always get INVALID_STATE_TRANSITION.
    test('allows submission while PENDING_ONBOARDING', () {
      final status = KycStatus.fromJson({'status': 'PENDING_ONBOARDING', 'isActive': false, 'documents': []});
      expect(status.canSubmitDocuments, isTrue);
    });

    test('allows submission while CORRECTION_REQUIRED', () {
      final status = KycStatus.fromJson({'status': 'CORRECTION_REQUIRED', 'isActive': false, 'documents': []});
      expect(status.canSubmitDocuments, isTrue);
    });

    for (final blockedStatus in ['ACTIVE', 'KYC_SUBMITTED', 'UNDER_REVIEW', 'VERIFIED', 'SUSPENDED', 'DEACTIVATED', 'REJECTED']) {
      test('blocks submission while $blockedStatus', () {
        final status = KycStatus.fromJson({'status': blockedStatus, 'isActive': true, 'documents': []});
        expect(status.canSubmitDocuments, isFalse);
      });
    }

    test('parses submitted documents', () {
      final status = KycStatus.fromJson({
        'status': 'ACTIVE',
        'isActive': true,
        'documents': [
          {'document_type': 'GSTIN_CERTIFICATE', 'file_url': 'https://cdn.test/doc.jpg', 'status': 'PENDING'},
        ],
      });

      expect(status.documents, hasLength(1));
      expect(status.documents.single.documentType, 'GSTIN_CERTIFICATE');
      expect(status.documents.single.fileUrl, 'https://cdn.test/doc.jpg');
    });
  });
}
