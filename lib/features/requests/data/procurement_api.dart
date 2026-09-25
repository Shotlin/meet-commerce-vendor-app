import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';

// ── Models (mirror backend vendor-procurement responses) ────────────────────

class RequestItem {
  RequestItem({
    required this.id,
    required this.itemName,
    required this.requestedQuantity,
    required this.unit,
    this.fixedUnitPrice,
    this.categoryName,
  });

  final String id;
  final String itemName;
  final num requestedQuantity;
  final String unit;
  final num? fixedUnitPrice;
  final String? categoryName;

  factory RequestItem.fromJson(Map<String, dynamic> json) => RequestItem(
        id: json['id'].toString(),
        itemName: json['item_name']?.toString() ?? 'Item',
        requestedQuantity: num.tryParse('${json['requested_quantity']}') ?? 0,
        unit: json['unit']?.toString() ?? 'KG',
        fixedUnitPrice: json['fixed_unit_price'] == null
            ? null
            : num.tryParse('${json['fixed_unit_price']}'),
        categoryName: json['category_name']?.toString(),
      );

  Map<String, dynamic> toQuoteInput({required num quotedQuantity, required num unitPrice}) => {
        'request_item_id': id,
        'quoted_quantity': quotedQuantity,
        'unit_price': unitPrice,
      };
}

/// The vendor's own still-editable quote (SUBMITTED/UPDATED) for a request,
/// if any. Lets the app tell "submit a new quote" apart from "edit my live
/// quote" and pre-fill the edit form with real, persisted values.
class VendorQuoteItem {
  VendorQuoteItem({required this.requestItemId, required this.quotedQuantity, required this.unitPrice});

  final String requestItemId;
  final num quotedQuantity;
  final num unitPrice;

  factory VendorQuoteItem.fromJson(Map<String, dynamic> json) => VendorQuoteItem(
        requestItemId: json['request_item_id'].toString(),
        quotedQuantity: num.tryParse('${json['quoted_quantity']}') ?? 0,
        unitPrice: num.tryParse('${json['unit_price']}') ?? 0,
      );
}

class VendorQuote {
  VendorQuote({
    required this.id,
    required this.status,
    required this.grandTotal,
    required this.items,
    this.note,
    this.promisedDeliveryAt,
  });

  final String id;
  final String status;
  final num grandTotal;
  final List<VendorQuoteItem> items;
  final String? note;
  final DateTime? promisedDeliveryAt;

  VendorQuoteItem? itemFor(String requestItemId) {
    for (final item in items) {
      if (item.requestItemId == requestItemId) return item;
    }
    return null;
  }

  factory VendorQuote.fromJson(Map<String, dynamic> json) => VendorQuote(
        id: json['id'].toString(),
        status: json['status']?.toString() ?? 'SUBMITTED',
        grandTotal: num.tryParse('${json['grand_total']}') ?? 0,
        note: json['note']?.toString(),
        promisedDeliveryAt: json['promised_delivery_at'] == null
            ? null
            : DateTime.tryParse(json['promised_delivery_at'].toString()),
        items: (json['items'] as List? ?? [])
            .map((e) => VendorQuoteItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class VendorRequest {
  VendorRequest({
    required this.id,
    required this.requestNumber,
    required this.mode,
    required this.status,
    required this.title,
    required this.shopName,
    required this.shopCity,
    this.requiredDeliveryAt,
    this.responseDeadline,
    this.offerTotal,
    this.qualityInstructions,
    this.notes,
    this.recipientStatus,
    this.items = const [],
    this.myQuote,
  });

  final String id;
  final String requestNumber;
  final String mode; // FIXED_OFFER | RFQ
  final String status;
  final String title;
  final String shopName;
  final String shopCity;
  final DateTime? requiredDeliveryAt;
  final DateTime? responseDeadline;
  final num? offerTotal;
  final String? qualityInstructions;
  final String? notes;
  final String? recipientStatus;
  final List<RequestItem> items;
  final VendorQuote? myQuote;

  bool get isFixedOffer => mode == 'FIXED_OFFER';
  bool get isPublished => status == 'PUBLISHED';
  bool get isOpenToRespond => isPublished && (recipientStatus == 'NEW' || recipientStatus == 'VIEWED');
  bool get deadlinePassed =>
      responseDeadline != null && responseDeadline!.isBefore(DateTime.now());

  static DateTime? _date(dynamic value) =>
      value == null ? null : DateTime.tryParse(value.toString());

  factory VendorRequest.fromInboxJson(Map<String, dynamic> json) => VendorRequest(
        id: json['id'].toString(),
        requestNumber: json['request_number']?.toString() ?? '',
        mode: json['mode']?.toString() ?? 'RFQ',
        status: json['status']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        shopName: json['shop_name']?.toString() ?? '',
        shopCity: json['shop_city']?.toString() ?? '',
        requiredDeliveryAt: _date(json['required_delivery_at']),
        responseDeadline: _date(json['response_deadline']),
        offerTotal:
            json['offer_total'] == null ? null : num.tryParse('${json['offer_total']}'),
        qualityInstructions: json['quality_instructions']?.toString(),
        recipientStatus: json['recipient_status']?.toString(),
        items: (json['item_summary'] as List? ?? [])
            .map((e) => RequestItem(
                  id: '',
                  itemName: e['item_name']?.toString() ?? '',
                  requestedQuantity: num.tryParse('${e['requested_quantity']}') ?? 0,
                  unit: e['unit']?.toString() ?? 'KG',
                ))
            .toList(),
      );

  factory VendorRequest.fromDetailJson(
    Map<String, dynamic> json,
    Map<String, dynamic> recipient, {
    Map<String, dynamic>? quote,
  }) =>
      VendorRequest(
        id: json['id'].toString(),
        requestNumber: json['request_number']?.toString() ?? '',
        mode: json['mode']?.toString() ?? 'RFQ',
        status: json['status']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        shopName: json['shop_name']?.toString() ?? '',
        shopCity: json['shop_city']?.toString() ?? '',
        requiredDeliveryAt: _date(json['required_delivery_at']),
        responseDeadline: _date(json['response_deadline']),
        offerTotal:
            json['offer_total'] == null ? null : num.tryParse('${json['offer_total']}'),
        qualityInstructions: json['quality_instructions']?.toString(),
        notes: json['notes']?.toString(),
        recipientStatus: recipient['status']?.toString(),
        items: (json['items'] as List? ?? [])
            .map((e) => RequestItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        myQuote: quote == null ? null : VendorQuote.fromJson(quote),
      );
}

// ── Data layer ──────────────────────────────────────────────────────────────

class ProcurementApi {
  ProcurementApi(this._api);

  final ApiClient _api;

  Future<List<VendorRequest>> listRequests({required String filter}) async {
    final data = await _api.get(ApiConstants.vendorRequests, query: {'filter': filter});
    final rows = data is List ? data : (data?['requests'] as List? ?? []);
    return rows
        .map((row) => VendorRequest.fromInboxJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<VendorRequest> getRequestDetail(String requestId) async {
    final data = await _api.get(ApiConstants.requestDetail(requestId));
    final map = Map<String, dynamic>.from(data);
    // The backend sends `items` as a sibling of `request`, not nested inside
    // it — merge it in before parsing so `VendorRequest.fromDetailJson`'s
    // `json['items']` read actually finds the line items.
    final requestMap = Map<String, dynamic>.from(map['request'] ?? map);
    requestMap['items'] = map['items'] ?? requestMap['items'] ?? [];
    return VendorRequest.fromDetailJson(
      requestMap,
      Map<String, dynamic>.from(map['recipient'] ?? {}),
      quote: map['quote'] == null ? null : Map<String, dynamic>.from(map['quote']),
    );
  }

  Future<dynamic> acceptOffer(String requestId) =>
      _api.post(ApiConstants.acceptOffer(requestId));

  Future<dynamic> declineRequest(String requestId) =>
      _api.post(ApiConstants.declineRequest(requestId));

  Future<dynamic> submitQuote(String requestId, Map<String, dynamic> body) =>
      _api.post(ApiConstants.submitQuote(requestId), body: body);

  Future<dynamic> updateQuote(String quoteId, Map<String, dynamic> body) =>
      _api.patch(ApiConstants.quoteDetail(quoteId), body: body);

  Future<dynamic> withdrawQuote(String quoteId) =>
      _api.post(ApiConstants.withdrawQuote(quoteId));
}

final procurementApiProvider = Provider<ProcurementApi>(
  (ref) => ProcurementApi(ref.watch(apiClientProvider)),
);
