import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';

class PerformanceState {
  const PerformanceState({this.data, this.loading = false, this.error});

  final Map<String, dynamic>? data;
  final bool loading;
  final String? error;
}

class PerformanceNotifier extends StateNotifier<PerformanceState> {
  PerformanceNotifier(this._api) : super(const PerformanceState());

  final ApiClient _api;

  Future<void> load() async {
    state = const PerformanceState(loading: true);
    try {
      final data = await _api.get(ApiConstants.vendorPerformance);
      state = PerformanceState(data: data is Map ? Map<String, dynamic>.from(data) : {});
    } catch (error) {
      state = PerformanceState(error: error.toString());
    }
  }
}

final performanceProvider =
    StateNotifierProvider<PerformanceNotifier, PerformanceState>((ref) {
  final notifier = PerformanceNotifier(ref.watch(apiClientProvider));
  notifier.load();
  return notifier;
});
