import 'package:flutter_test/flutter_test.dart';

import 'package:freshcuts_vendor_app/core/socket/socket_service.dart';

void main() {
  group('ProcurementSocketEvent.tryParse', () {
    test('parses a real request_published notification payload', () {
      final event = ProcurementSocketEvent.tryParse({
        'id': 'n1',
        'title': 'New procurement requirement',
        'body': 'FreshCuts — Kolkata published PRQ-20260927-0001 — respond before the deadline.',
        'type': 'procurement',
        'data': {
          'event': 'request_published',
          'request_id': 'req-123',
          'request_number': 'PRQ-20260927-0001',
          'mode': 'FIXED_OFFER',
        },
        'is_read': false,
        'created_at': '2026-09-27T10:00:00.000Z',
      });

      expect(event, isNotNull);
      expect(event!.event, 'request_published');
      expect(event.requestId, 'req-123');
      expect(event.title, 'New procurement requirement');
      expect(event.body, contains('PRQ-20260927-0001'));
    });

    test('parses a non-request_id event (e.g. rfq not selected) with no requestId crash', () {
      final event = ProcurementSocketEvent.tryParse({
        'title': 'Requirement awarded to another vendor',
        'body': 'PRQ-1 was awarded to a different vendor.',
        'type': 'procurement',
        'data': {'event': 'rfq_not_selected', 'request_id': 'req-9', 'request_number': 'PRQ-1'},
      });

      expect(event, isNotNull);
      expect(event!.event, 'rfq_not_selected');
      expect(event.requestId, 'req-9');
    });

    test('returns null for a non-procurement notification (e.g. a plain order/system notification)', () {
      final event = ProcurementSocketEvent.tryParse({
        'title': 'Something else',
        'body': 'Not procurement',
        'type': 'general',
        'data': {},
      });

      expect(event, isNull);
    });

    test('returns null when the payload has no event key at all', () {
      final event = ProcurementSocketEvent.tryParse({
        'title': 'Malformed',
        'body': '',
        'type': 'procurement',
        'data': {'request_id': 'req-1'},
      });

      expect(event, isNull);
    });

    test('returns null for non-map input', () {
      expect(ProcurementSocketEvent.tryParse('not a map'), isNull);
      expect(ProcurementSocketEvent.tryParse(null), isNull);
    });
  });
}
