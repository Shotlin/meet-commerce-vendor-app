import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../data/procurement_api.dart';

class RequestDetailState {
  const RequestDetailState({this.request, this.loading = false, this.error, this.actionMessage});

  final VendorRequest? request;
  final bool loading;
  final String? error;
  final String? actionMessage;

  RequestDetailState copyWith({
    VendorRequest? request,
    bool? loading,
    String? error,
    String? actionMessage,
  }) {
    return RequestDetailState(
      request: request ?? this.request,
      loading: loading ?? this.loading,
      error: error,
      actionMessage: actionMessage ?? this.actionMessage,
    );
  }
}

class RequestDetailNotifier extends StateNotifier<RequestDetailState> {
  RequestDetailNotifier(this._api) : super(const RequestDetailState());

  final ProcurementApi _api;

  /// Public read accessor for widgets (state itself is protected).
  VendorRequest? get currentRequest => state.request;

  Future<void> load(String requestId) async {
    state = const RequestDetailState(loading: true);
    try {
      final request = await _api.getRequestDetail(requestId);
      state = RequestDetailState(request: request);
    } catch (error) {
      state = RequestDetailState(error: error.toString());
    }
  }

  Future<bool> accept(String requestId) async {
    try {
      await _api.acceptOffer(requestId);
      state = state.copyWith(actionMessage: 'Offer accepted — supply order created');
      await load(requestId);
      return true;
    } catch (error) {
      state = state.copyWith(actionMessage: _friendly(error));
      return false;
    }
  }

  Future<bool> decline(String requestId) async {
    try {
      await _api.declineRequest(requestId);
      state = state.copyWith(actionMessage: 'Requirement declined');
      await load(requestId);
      return true;
    } catch (error) {
      state = state.copyWith(actionMessage: _friendly(error));
      return false;
    }
  }

  /// Submits a brand-new RFQ quote (create).
  Future<bool> submitQuote(String requestId, Map<String, dynamic> body) async {
    try {
      await _api.submitQuote(requestId, body);
      state = state.copyWith(actionMessage: 'Quote submitted');
      await load(requestId);
      return true;
    } catch (error) {
      state = state.copyWith(actionMessage: _friendly(error));
      return false;
    }
  }

  /// Edits the vendor's own already-live quote (update).
  Future<bool> updateQuote(String requestId, String quoteId, Map<String, dynamic> body) async {
    try {
      await _api.updateQuote(quoteId, body);
      state = state.copyWith(actionMessage: 'Quote updated');
      await load(requestId);
      return true;
    } catch (error) {
      state = state.copyWith(actionMessage: _friendly(error));
      return false;
    }
  }

  /// Saves a quote, dispatching to create or update depending on whether the
  /// vendor already has a live quote on this request — the caller never has
  /// to track which one applies.
  Future<bool> saveQuote(String requestId, Map<String, dynamic> body) {
    final existingQuoteId = currentRequest?.myQuote?.id;
    return existingQuoteId == null
        ? submitQuote(requestId, body)
        : updateQuote(requestId, existingQuoteId, body);
  }

  Future<bool> withdrawQuote(String requestId, String quoteId) async {
    try {
      await _api.withdrawQuote(quoteId);
      state = state.copyWith(actionMessage: 'Quote withdrawn');
      await load(requestId);
      return true;
    } catch (error) {
      state = state.copyWith(actionMessage: _friendly(error));
      return false;
    }
  }

  void clearMessage() {
    state = state.copyWith(actionMessage: null);
  }

  String _friendly(Object error) {
    final code = error is ApiException ? error.code : null;
    if (code == 'ALREADY_AWARDED') return 'This offer has already been awarded to another vendor.';
    if (code == 'PROCUREMENT_QUOTE_EXISTS') return 'You already have a live quote — edit it instead.';
    if (code == 'PROCUREMENT_QUOTE_LOCKED') return 'This quote is locked and can no longer be changed.';
    if (code == 'PROCUREMENT_REQUEST_CLOSED') return 'This request is no longer open.';
    final message = error.toString();
    if (message.contains('DEADLINE')) return 'The response deadline for this requirement has passed.';
    if (message.contains('No internet')) return 'No internet connection. Check your network and try again.';
    return message;
  }
}

final requestDetailProvider =
    StateNotifierProvider.family<RequestDetailNotifier, RequestDetailState, String>(
  (ref, requestId) => RequestDetailNotifier(ref.watch(procurementApiProvider)),
);
