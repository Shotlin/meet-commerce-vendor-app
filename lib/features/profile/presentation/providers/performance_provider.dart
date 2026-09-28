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
      final merged = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      // `/performance` returns {vendor, performance} only — `reviews` lives
      // on the separate `/reviews` endpoint and was never actually fetched
      // here, so "Recent store feedback" always showed its empty state
      // regardless of real reviews. Fetched second and merged in under the
      // same `reviews` key the UI already reads; a failure here (network
      // blip, etc.) never blocks the metrics that already loaded above —
      // it just leaves the feedback list empty for this refresh.
      try {
        final reviews = await _api.get(ApiConstants.vendorReviews, query: {'limit': 5});
        merged['reviews'] = reviews is List ? reviews : const [];
      } catch (_) {
        merged['reviews'] = const [];
      }
      state = PerformanceState(data: merged);
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
