import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/supplies_api.dart';

class SuppliesState {
  const SuppliesState({this.supplies = const [], this.loading = false, this.error});

  final List<SupplyOrderModel> supplies;
  final bool loading;
  final String? error;
}

class SuppliesNotifier extends StateNotifier<SuppliesState> {
  SuppliesNotifier(this._api) : super(const SuppliesState());

  final SuppliesApi _api;

  Future<void> load() async {
    state = const SuppliesState(loading: true);
    try {
      final supplies = await _api.listSupplies();
      state = SuppliesState(supplies: supplies);
    } catch (error) {
      state = SuppliesState(error: error.toString());
    }
  }
}

final suppliesProvider =
    StateNotifierProvider<SuppliesNotifier, SuppliesState>((ref) {
  final notifier = SuppliesNotifier(ref.watch(suppliesApiProvider));
  notifier.load();
  return notifier;
});

class SupplyDetailState {
  const SupplyDetailState({this.supply, this.loading = false, this.error});

  final SupplyOrderModel? supply;
  final bool loading;
  final String? error;
}

class SupplyDetailNotifier extends StateNotifier<SupplyDetailState> {
  SupplyDetailNotifier(this._api) : super(const SupplyDetailState());

  final SuppliesApi _api;

  Future<void> load(String supplyId) async {
    state = const SupplyDetailState(loading: true);
    try {
      final supply = await _api.getSupply(supplyId);
      state = SupplyDetailState(supply: supply);
    } catch (error) {
      state = SupplyDetailState(error: error.toString());
    }
  }

  /// Returns true on success; surfaces a friendly message on failure.
  Future<bool> updateStatus(String supplyId, Map<String, dynamic> body) async {
    try {
      await _api.updateStatus(supplyId, body);
      await load(supplyId);
      return true;
    } catch (error) {
      final message = error.toString();
      state = SupplyDetailState(
        supply: state.supply,
        error: message.contains('EVIDENCE_REQUIRED')
            ? 'Quality video evidence is required before packing.'
            : message,
      );
      return false;
    }
  }
}

final supplyDetailProvider =
    StateNotifierProvider.family<SupplyDetailNotifier, SupplyDetailState, String>(
  (ref, supplyId) => SupplyDetailNotifier(ref.watch(suppliesApiProvider)),
);
