import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';

// ── Models ────────────────────────────────────────────────────────────────

/// The vendor's own business profile — `vendors` + `vendor_profiles` +
/// `vendor_settings`, as returned by `GET /vendors/:id`.
class VendorProfile {
  VendorProfile({
    required this.id,
    required this.name,
    required this.status,
    required this.isActive,
    this.legalName,
    this.tradeLicenseNumber,
    this.gstin,
    this.fssaiLicense,
    this.panNumber,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
    this.pincode,
    this.notificationEmail,
    this.notificationPhone,
  });

  final String id;
  final String name;
  final String status;
  final bool isActive;
  final String? legalName;
  final String? tradeLicenseNumber;
  final String? gstin;
  final String? fssaiLicense;
  final String? panNumber;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? state;
  final String? pincode;
  final String? notificationEmail;
  final String? notificationPhone;

  factory VendorProfile.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] is Map ? Map<String, dynamic>.from(json['profile']) : const {};
    final settings = json['settings'] is Map ? Map<String, dynamic>.from(json['settings']) : const {};
    return VendorProfile(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      isActive: json['is_active'] == true,
      legalName: profile['legal_name']?.toString(),
      tradeLicenseNumber: profile['trade_license_number']?.toString(),
      gstin: profile['gstin']?.toString(),
      fssaiLicense: profile['fssai_license']?.toString(),
      panNumber: profile['pan_number']?.toString(),
      addressLine1: profile['address_line1']?.toString(),
      addressLine2: profile['address_line2']?.toString(),
      city: profile['city']?.toString(),
      state: profile['state']?.toString(),
      pincode: profile['pincode']?.toString(),
      notificationEmail: settings['notification_email']?.toString(),
      notificationPhone: settings['notification_phone']?.toString(),
    );
  }
}

class VendorCategory {
  VendorCategory({required this.id, required this.name});

  final String id;
  final String name;

  factory VendorCategory.fromCategoriesJson(Map<String, dynamic> json) =>
      VendorCategory(id: json['id'].toString(), name: json['name']?.toString() ?? '');

  factory VendorCategory.fromServiceProfileJson(Map<String, dynamic> json) => VendorCategory(
        id: json['category_id'].toString(),
        name: json['category_name']?.toString() ?? '',
      );
}

class StoreAssignment {
  StoreAssignment({required this.shopId, required this.shopName, required this.shopCity});

  final String shopId;
  final String shopName;
  final String shopCity;

  factory StoreAssignment.fromJson(Map<String, dynamic> json) => StoreAssignment(
        shopId: json['shop_id'].toString(),
        shopName: json['shop_name']?.toString() ?? '',
        shopCity: json['shop_city']?.toString() ?? '',
      );
}

/// Categories/areas/stores a vendor is scoped to for procurement targeting —
/// `GET /vendor-procurement/vendor/service-profile`. `update()` on the
/// backend REPLACES all three lists at once, so every save must resend the
/// two fields not being edited on this particular screen unchanged.
class ServiceProfile {
  ServiceProfile({
    required this.categories,
    required this.servicePincodes,
    required this.storeAssignments,
  });

  final List<VendorCategory> categories;
  final List<String> servicePincodes;
  final List<StoreAssignment> storeAssignments;

  factory ServiceProfile.fromJson(Map<String, dynamic> json) => ServiceProfile(
        categories: (json['categories'] as List? ?? [])
            .map((e) => VendorCategory.fromServiceProfileJson(Map<String, dynamic>.from(e)))
            .toList(),
        servicePincodes:
            (json['service_pincodes'] as List? ?? []).map((e) => e.toString()).toList(),
        storeAssignments: (json['store_assignments'] as List? ?? [])
            .map((e) => StoreAssignment.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );

  List<String> get categoryIds => categories.map((c) => c.id).toList();
  List<String> get shopIds => storeAssignments.map((s) => s.shopId).toList();
}

class KycDocument {
  KycDocument({
    required this.documentType,
    this.documentNumber,
    this.fileUrl,
    this.status,
    this.createdAt,
  });

  final String documentType;
  final String? documentNumber;
  final String? fileUrl;
  final String? status;
  final DateTime? createdAt;

  factory KycDocument.fromJson(Map<String, dynamic> json) => KycDocument(
        documentType: json['document_type']?.toString() ?? 'OTHER',
        documentNumber: json['document_number']?.toString(),
        fileUrl: json['file_url']?.toString(),
        status: json['status']?.toString(),
        createdAt: json['created_at'] == null ? null : DateTime.tryParse(json['created_at'].toString()),
      );
}

class KycStatus {
  KycStatus({required this.status, required this.isActive, required this.documents});

  final String status;
  final bool isActive;
  final List<KycDocument> documents;

  factory KycStatus.fromJson(Map<String, dynamic> json) => KycStatus(
        status: json['status']?.toString() ?? '',
        isActive: json['isActive'] == true,
        documents: (json['documents'] as List? ?? [])
            .map((e) => KycDocument.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );

  /// Matches the backend's own onboarding state machine
  /// (vendor-kyc.service.js#ALLOWED_TRANSITIONS) — document submission is
  /// only accepted from these two states.
  bool get canSubmitDocuments => status == 'PENDING_ONBOARDING' || status == 'CORRECTION_REQUIRED';
}

const kycDocumentTypes = <String, String>{
  'TRADE_LICENSE': 'Trade License',
  'GSTIN_CERTIFICATE': 'GSTIN Certificate',
  'FSSAI_LICENSE': 'FSSAI License',
  'PAN_CARD': 'PAN Card',
  'BANK_CANCELLED_CHEQUE': 'Cancelled Cheque',
  'OTHER': 'Other',
};

// ── Data layer ──────────────────────────────────────────────────────────────

class ProfileApi {
  ProfileApi(this._api);

  final ApiClient _api;

  Future<VendorProfile> getVendorProfile(String vendorId) async {
    final data = await _api.get(ApiConstants.vendorDetail(vendorId));
    return VendorProfile.fromJson(Map<String, dynamic>.from(data));
  }

  Future<VendorProfile> updateBusinessInfo(
    String vendorId, {
    String? legalName,
    String? tradeLicenseNumber,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? state,
    String? pincode,
  }) async {
    final data = await _api.patch(ApiConstants.vendorProfile(vendorId), body: {
      'legal_name': ?legalName,
      'trade_license_number': ?tradeLicenseNumber,
      'address_line1': ?addressLine1,
      'address_line2': ?addressLine2,
      'city': ?city,
      'state': ?state,
      'pincode': ?pincode,
    });
    return VendorProfile.fromJson(Map<String, dynamic>.from(data));
  }

  Future<VendorProfile> updateTaxAndLicenses(
    String vendorId, {
    String? gstin,
    String? fssaiLicense,
    String? panNumber,
  }) async {
    final data = await _api.patch(ApiConstants.vendorProfile(vendorId), body: {
      'gstin': ?gstin,
      'fssai_license': ?fssaiLicense,
      'pan_number': ?panNumber,
    });
    return VendorProfile.fromJson(Map<String, dynamic>.from(data));
  }

  Future<VendorProfile> updateNotificationSettings(
    String vendorId, {
    String? notificationEmail,
    String? notificationPhone,
  }) async {
    final data = await _api.patch(ApiConstants.vendorSettings(vendorId), body: {
      'notification_email': ?notificationEmail,
      'notification_phone': ?notificationPhone,
    });
    return VendorProfile.fromJson(Map<String, dynamic>.from(data));
  }

  Future<ServiceProfile> getServiceProfile() async {
    final data = await _api.get(ApiConstants.vendorServiceProfile);
    return ServiceProfile.fromJson(Map<String, dynamic>.from(data));
  }

  /// The backend REPLACES all three lists on every call — always pass the
  /// full intended set for each, not just the one the user is editing.
  Future<ServiceProfile> updateServiceProfile({
    required List<String> categoryIds,
    required List<String> servicePincodes,
    required List<String> shopIds,
  }) async {
    final data = await _api.put(ApiConstants.vendorServiceProfile, body: {
      'category_ids': categoryIds,
      'service_pincodes': servicePincodes,
      'shop_ids': shopIds,
    });
    return ServiceProfile.fromJson(Map<String, dynamic>.from(data));
  }

  /// Every real category in the catalog (public endpoint, no auth) — the
  /// picklist for the Categories screen.
  Future<List<VendorCategory>> listAllCategories() async {
    final data = await _api.get('/categories');
    final rows = data is List ? data : const [];
    return rows.map((e) => VendorCategory.fromCategoriesJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<KycStatus> getKycStatus(String vendorId) async {
    final data = await _api.get(ApiConstants.vendorKycStatus(vendorId));
    return KycStatus.fromJson(Map<String, dynamic>.from(data));
  }

  /// Uploads one document photo then registers it against the vendor's KYC
  /// record. Only succeeds while the vendor is still mid-onboarding — the
  /// backend's own state machine rejects this once a vendor is ACTIVE (see
  /// KycStatus.canSubmitDocuments); the caller should check that first and
  /// only offer this action when it can actually succeed.
  Future<KycStatus> submitDocument(
    String vendorId, {
    required String documentType,
    required String filePath,
    String? documentNumber,
  }) async {
    final fileName = filePath.split('/').last;
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    final uploadResponse = await _api.dio.post('/uploads/image', data: form);
    final uploadPayload = uploadResponse.data;
    final uploaded = uploadPayload is Map ? (uploadPayload['data'] ?? uploadPayload) : null;
    if (uploaded is! Map) {
      throw ApiException('Upload succeeded but no file info was returned', statusCode: 500);
    }
    await _api.post(ApiConstants.vendorKycSubmit(vendorId), body: {
      'documents': [
        {
          'document_type': documentType,
          if (documentNumber != null && documentNumber.isNotEmpty) 'document_number': documentNumber,
          'file_key': uploaded['publicId']?.toString() ?? '',
          if (uploaded['url'] != null) 'file_url': uploaded['url'].toString(),
        },
      ],
    });
    // submitKyc's response isn't the same shape as getOnboardingStatus's —
    // re-fetch so the screen always renders from one consistent shape.
    return getKycStatus(vendorId);
  }
}

final profileApiProvider = Provider<ProfileApi>((ref) => ProfileApi(ref.watch(apiClientProvider)));
