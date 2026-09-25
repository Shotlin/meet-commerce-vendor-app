import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';

class SupplyOrderModel {
  SupplyOrderModel({
    required this.id,
    required this.supplyNumber,
    required this.status,
    required this.awardAmount,
    required this.shopName,
    required this.shopCity,
    required this.sourceMode,
    this.requestNumber,
    this.promisedDeliveryAt,
    this.itemSummary = const [],
    this.hasEvidence = false,
    this.items = const [],
    this.events = const [],
    this.evidence = const [],
  });

  final String id;
  final String supplyNumber;
  final String status;
  final num awardAmount;
  final String shopName;
  final String shopCity;
  final String sourceMode;
  final String? requestNumber;
  final DateTime? promisedDeliveryAt;
  final List<Map<String, dynamic>> itemSummary;
  final bool hasEvidence;
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> events;
  final List<Map<String, dynamic>> evidence;

  bool get isActive => !['CLOSED', 'CANCELLED', 'REJECTED_AT_RECEIPT', 'RECEIVED'].contains(status);

  static DateTime? _date(dynamic value) =>
      value == null ? null : DateTime.tryParse(value.toString());

  factory SupplyOrderModel.fromJson(Map<String, dynamic> json) => SupplyOrderModel(
        id: json['id'].toString(),
        supplyNumber: json['supply_number']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        awardAmount: num.tryParse('${json['award_amount']}') ?? 0,
        shopName: json['shop_name']?.toString() ?? '',
        shopCity: json['shop_city']?.toString() ?? '',
        sourceMode: json['source_mode']?.toString() ?? 'RFQ',
        requestNumber: json['request_number']?.toString(),
        promisedDeliveryAt: _date(json['promised_delivery_at']),
        itemSummary: (json['item_summary'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e))
            .toList(),
        hasEvidence: json['has_evidence'] == true,
        items: (json['items'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList(),
        events: (json['events'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList(),
        evidence: (json['evidence'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList(),
      );
}

class SuppliesApi {
  SuppliesApi(this._api);

  final ApiClient _api;

  Future<List<SupplyOrderModel>> listSupplies() async {
    final data = await _api.get(ApiConstants.vendorSupplies);
    final rows = data is List ? data : (data?['supplies'] as List? ?? []);
    return rows.map((row) => SupplyOrderModel.fromJson(Map<String, dynamic>.from(row))).toList();
  }

  Future<SupplyOrderModel> getSupply(String supplyId) async {
    final data = await _api.get(ApiConstants.supplyDetail(supplyId));
    return SupplyOrderModel.fromJson(Map<String, dynamic>.from(data));
  }

  Future<dynamic> updateStatus(String supplyId, Map<String, dynamic> body) =>
      _api.post('${ApiConstants.supplyDetail(supplyId)}/status', body: body);

  /// Uploads the video binary to Cloudinary via the backend, then registers
  /// the evidence metadata against the supply order.
  Future<dynamic> uploadQualityVideo(
    String supplyId,
    String filePath, {
    void Function(int sent, int total)? onProgress,
  }) async {
    final fileName = filePath.split('/').last;
    final form = FormData.fromMap({
      'video': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    final response = await _api.dio.post(
      '/uploads/video',
      data: form,
      onSendProgress: onProgress,
    );
    final payload = response.data;
    final data = payload is Map ? (payload['data'] ?? payload) : null;
    if (data is! Map) {
      throw ApiException('Upload succeeded but no media info was returned', statusCode: 500);
    }
    return _api.post('${ApiConstants.supplyDetail(supplyId)}/evidence', body: {
      'evidence_type': 'QUALITY_VIDEO',
      'media_public_id': data['publicId']?.toString() ?? '',
      'media_url': data['url']?.toString() ?? '',
      'mime_type': 'video/mp4',
      if (data['duration'] != null) 'duration_seconds': (num.tryParse('${data['duration']}'))?.round(),
      if (data['bytes'] != null) 'size_bytes': num.tryParse('${data['bytes']}'),
    });
  }
}

final suppliesApiProvider = Provider<SuppliesApi>((ref) => SuppliesApi(ref.watch(apiClientProvider)));
