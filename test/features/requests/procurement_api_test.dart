import 'package:flutter_test/flutter_test.dart';
import 'package:freshcuts_vendor_app/features/requests/data/procurement_api.dart';

void main() {
  group('VendorRequest.fromDetailJson', () {
    // Regression test for the RFQ-breaking bug: the backend's real
    // GET /vendor-procurement/vendor/requests/:id response puts `items` as
    // a sibling of `request`, not nested inside it. Before the fix, the
    // request map passed here never carried real items, so the quote form
    // always built zero item rows and every RFQ quote submission sent
    // items: [] — which the backend's own AJV schema (minItems: 1) always
    // rejected. This test parses the exact shape the backend sends.
    test('surfaces items merged in from the response sibling field', () {
      final requestJson = {
        'id': 'req-1',
        'request_number': 'PRQ-1',
        'mode': 'RFQ',
        'status': 'PUBLISHED',
        'title': 'Fresh Rohu',
        'shop_name': 'FreshCuts Kolkata',
        'shop_city': 'Kolkata',
        // Deliberately no 'items' key here — mirrors the real backend
        // response, where items lives beside 'request', not inside it.
        'items': [],
      };
      final itemsFromSibling = [
        {
          'id': 'item-1',
          'item_name': 'Rohu',
          'requested_quantity': '15',
          'unit': 'KG',
          'category_name': 'Fish',
        },
      ];
      // Mirrors ProcurementApi.getRequestDetail's merge step.
      requestJson['items'] = itemsFromSibling;

      final request = VendorRequest.fromDetailJson(requestJson, {'status': 'VIEWED'});

      expect(request.items, hasLength(1));
      expect(request.items.single.itemName, 'Rohu');
      expect(request.items.single.requestedQuantity, 15);
      expect(request.items.single.unit, 'KG');
    });

    test('parses the vendor\'s own live quote when present, for pre-fill', () {
      final requestJson = {
        'id': 'req-1',
        'request_number': 'PRQ-1',
        'mode': 'RFQ',
        'status': 'PUBLISHED',
        'title': 'Fresh Rohu',
        'shop_name': 'FreshCuts Kolkata',
        'shop_city': 'Kolkata',
        'items': [
          {'id': 'item-1', 'item_name': 'Rohu', 'requested_quantity': '15', 'unit': 'KG'},
        ],
      };
      final quoteJson = {
        'id': 'quote-1',
        'status': 'SUBMITTED',
        'grand_total': '3300',
        'note': 'Fresh catch',
        'promised_delivery_at': '2026-10-01T10:00:00.000Z',
        'items': [
          {'request_item_id': 'item-1', 'quoted_quantity': '15', 'unit_price': '220'},
        ],
      };

      final request = VendorRequest.fromDetailJson(
        requestJson,
        {'status': 'RESPONDED'},
        quote: quoteJson,
      );

      expect(request.myQuote, isNotNull);
      expect(request.myQuote!.id, 'quote-1');
      expect(request.myQuote!.grandTotal, 3300);
      final item = request.myQuote!.itemFor('item-1');
      expect(item, isNotNull);
      expect(item!.quotedQuantity, 15);
      expect(item.unitPrice, 220);
    });

    test('has no quote when the backend sends null (fresh RFQ, or any fixed offer)', () {
      final request = VendorRequest.fromDetailJson(
        {
          'id': 'req-1',
          'request_number': 'PRQ-1',
          'mode': 'FIXED_OFFER',
          'status': 'PUBLISHED',
          'title': 'Chicken',
          'shop_name': 'FreshCuts Kolkata',
          'shop_city': 'Kolkata',
          'items': [],
        },
        {'status': 'NEW'},
        quote: null,
      );

      expect(request.myQuote, isNull);
    });
  });
}
