import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/network/api_client.dart';
import '../../data/profile_api.dart';

// ── Vendor business profile (Business Info / Tax & Licenses / Notifications) ─

class VendorProfileState {
  const VendorProfileState({this.profile, this.loading = false, this.error, this.saveMessage});

  final VendorProfile? profile;
  final bool loading;
  final String? error;
  final String? saveMessage;

  VendorProfileState copyWith({VendorProfile? profile, bool? loading, String? error, String? saveMessage}) {
    return VendorProfileState(
      profile: profile ?? this.profile,
      loading: loading ?? this.loading,
      error: error,
      saveMessage: saveMessage,
    );
  }
}

class VendorProfileNotifier extends StateNotifier<VendorProfileState> {
  VendorProfileNotifier(this._api, this._vendorId) : super(const VendorProfileState());

  final ProfileApi _api;
  final String? _vendorId;

  Future<void> load() async {
    final vendorId = _vendorId;
    if (vendorId == null) {
      state = const VendorProfileState(error: 'No vendor context yet — try again in a moment.');
      return;
    }
    state = state.copyWith(loading: true, error: null);
    try {
      final profile = await _api.getVendorProfile(vendorId);
      state = VendorProfileState(profile: profile);
    } catch (error) {
      state = VendorProfileState(error: _friendly(error));
    }
  }

  Future<bool> saveBusinessInfo({
    required String legalName,
    required String tradeLicenseNumber,
    required String addressLine1,
    required String addressLine2,
    required String city,
    required String state_,
    required String pincode,
  }) =>
      _save(() => _api.updateBusinessInfo(
            _vendorId!,
            legalName: legalName,
            tradeLicenseNumber: tradeLicenseNumber,
            addressLine1: addressLine1,
            addressLine2: addressLine2,
            city: city,
            state: state_,
            pincode: pincode,
          ));

  Future<bool> saveTaxAndLicenses({
    required String gstin,
    required String fssaiLicense,
    required String panNumber,
  }) =>
      _save(() => _api.updateTaxAndLicenses(
            _vendorId!,
            gstin: gstin,
            fssaiLicense: fssaiLicense,
            panNumber: panNumber,
          ));

  Future<bool> saveNotificationSettings({
    required String notificationEmail,
    required String notificationPhone,
  }) =>
      _save(() => _api.updateNotificationSettings(
            _vendorId!,
            notificationEmail: notificationEmail,
            notificationPhone: notificationPhone,
          ));

  Future<bool> _save(Future<VendorProfile> Function() action) async {
    if (_vendorId == null) return false;
    state = state.copyWith(loading: true, error: null);
    try {
      final profile = await action();
      state = VendorProfileState(profile: profile, saveMessage: 'Saved');
      return true;
    } catch (error) {
      state = state.copyWith(loading: false, error: _friendly(error));
      return false;
    }
  }

  String _friendly(Object error) {
    if (error is ApiException) return error.message;
    return error.toString();
  }
}

final vendorProfileProvider =
    StateNotifierProvider<VendorProfileNotifier, VendorProfileState>((ref) {
  final vendorId = ref.watch(authProvider).vendorId;
  final notifier = VendorProfileNotifier(ref.watch(profileApiProvider), vendorId);
  notifier.load();
  return notifier;
});

// ── Service profile (Service Areas / Categories) ────────────────────────────

class ServiceProfileState {
  const ServiceProfileState({this.profile, this.loading = false, this.error, this.saveMessage});

  final ServiceProfile? profile;
  final bool loading;
  final String? error;
  final String? saveMessage;
}

class ServiceProfileNotifier extends StateNotifier<ServiceProfileState> {
  ServiceProfileNotifier(this._api) : super(const ServiceProfileState());

  final ProfileApi _api;

  Future<void> load() async {
    state = const ServiceProfileState(loading: true);
    try {
      final profile = await _api.getServiceProfile();
      state = ServiceProfileState(profile: profile);
    } catch (error) {
      state = ServiceProfileState(error: _friendly(error));
    }
  }

  /// Saves a new set of service pincodes, preserving the vendor's current
  /// categories/store assignments exactly as last fetched — the backend
  /// replaces all three together, so this screen must never silently drop
  /// the other two.
  Future<bool> saveServicePincodes(List<String> pincodes) async {
    final current = state.profile;
    if (current == null) return false;
    return _save(() => _api.updateServiceProfile(
          categoryIds: current.categoryIds,
          servicePincodes: pincodes,
          shopIds: current.shopIds,
        ));
  }

  /// Saves a new set of categories, preserving pincodes/store assignments.
  Future<bool> saveCategories(List<String> categoryIds) async {
    final current = state.profile;
    if (current == null) return false;
    return _save(() => _api.updateServiceProfile(
          categoryIds: categoryIds,
          servicePincodes: current.servicePincodes,
          shopIds: current.shopIds,
        ));
  }

  Future<bool> _save(Future<ServiceProfile> Function() action) async {
    state = ServiceProfileState(profile: state.profile, loading: true);
    try {
      final profile = await action();
      state = ServiceProfileState(profile: profile, saveMessage: 'Saved');
      return true;
    } catch (error) {
      state = ServiceProfileState(profile: state.profile, error: _friendly(error));
      return false;
    }
  }

  String _friendly(Object error) {
    if (error is ApiException) return error.message;
    return error.toString();
  }
}

final serviceProfileProvider =
    StateNotifierProvider<ServiceProfileNotifier, ServiceProfileState>((ref) {
  final notifier = ServiceProfileNotifier(ref.watch(profileApiProvider));
  notifier.load();
  return notifier;
});

final allCategoriesProvider = FutureProvider<List<VendorCategory>>((ref) {
  return ref.watch(profileApiProvider).listAllCategories();
});

// ── KYC / Documents ──────────────────────────────────────────────────────

class KycState {
  const KycState({this.status, this.loading = false, this.error, this.uploading = false});

  final KycStatus? status;
  final bool loading;
  final String? error;
  final bool uploading;

  KycState copyWith({KycStatus? status, bool? loading, String? error, bool? uploading}) {
    return KycState(
      status: status ?? this.status,
      loading: loading ?? this.loading,
      error: error,
      uploading: uploading ?? this.uploading,
    );
  }
}

class KycNotifier extends StateNotifier<KycState> {
  KycNotifier(this._api, this._vendorId) : super(const KycState());

  final ProfileApi _api;
  final String? _vendorId;

  Future<void> load() async {
    final vendorId = _vendorId;
    if (vendorId == null) {
      state = const KycState(error: 'No vendor context yet — try again in a moment.');
      return;
    }
    state = state.copyWith(loading: true, error: null);
    try {
      final status = await _api.getKycStatus(vendorId);
      state = KycState(status: status);
    } catch (error) {
      state = KycState(error: _friendly(error));
    }
  }

  Future<bool> submitDocument({
    required String documentType,
    required String filePath,
    String? documentNumber,
  }) async {
    final vendorId = _vendorId;
    if (vendorId == null) return false;
    state = state.copyWith(uploading: true, error: null);
    try {
      final status = await _api.submitDocument(
        vendorId,
        documentType: documentType,
        filePath: filePath,
        documentNumber: documentNumber,
      );
      state = KycState(status: status);
      return true;
    } catch (error) {
      state = state.copyWith(uploading: false, error: _friendly(error));
      return false;
    }
  }

  String _friendly(Object error) {
    if (error is ApiException) {
      if (error.code == 'INVALID_STATE_TRANSITION') {
        return "Document updates aren't available once your account is fully active — contact FreshCuts support to update your documents.";
      }
      return error.message;
    }
    return error.toString();
  }
}

final kycProvider = StateNotifierProvider<KycNotifier, KycState>((ref) {
  final vendorId = ref.watch(authProvider).vendorId;
  final notifier = KycNotifier(ref.watch(profileApiProvider), vendorId);
  notifier.load();
  return notifier;
});
