import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/procurement_api.dart';

/// Async state per inbox tab: NEW | RESPONDED | CLOSED.
class RequestListState {
  const RequestListState({this.requests = const [], this.loading = false, this.error});

  final List<VendorRequest> requests;
  final bool loading;
  final String? error;
}

class RequestListNotifier extends StateNotifier<RequestListState> {
  RequestListNotifier(this._api) : super(const RequestListState());

  final ProcurementApi _api;

  Future<void> load({String filter = 'NEW'}) async {
    state = RequestListState(requests: state.requests, loading: true);
    try {
      final requests = await _api.listRequests(filter: filter);
      state = RequestListState(requests: requests);
    } catch (error) {
      state = RequestListState(error: error.toString());
    }
  }
}

final requestListProvider =
    StateNotifierProvider.family<RequestListNotifier, RequestListState, String>(
  (ref, filter) {
    final notifier = RequestListNotifier(ref.watch(procurementApiProvider));
    notifier.load(filter: filter);
    return notifier;
  },
);
