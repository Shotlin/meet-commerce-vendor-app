import 'package:flutter_test/flutter_test.dart';
import 'package:freshcuts_vendor_app/features/profile/presentation/providers/performance_provider.dart';
import 'package:freshcuts_vendor_app/features/profile/presentation/widgets/performance_insights.dart';

void main() {
  group('PerformanceSummary.fromState', () {
    test('no data yet (still loading, or errored before a first response) reports hasData: false', () {
      final summary0 = PerformanceSummary.fromState(const PerformanceState());
      expect(summary0.hasData, isFalse);
      expect(summary0.monthValueLabel, '—');
      expect(summary0.ratingLabel, '—');
      expect(summary0.monthlyTrend, isEmpty);
      expect(summary0.topProducts, isEmpty);
    });

    test('parses month_value/avg_rating and formats them for the KPI cards', () {
      final state = PerformanceState(data: {
        'vendor': {'id': 'v1', 'name': 'Kolkata Fresh Meats'},
        'performance': {
          'month_value': '18500',
          'avg_rating': '4.6',
          'review_count': 12,
          'monthly_trend': [],
          'top_products': [],
        },
      });

      final summary = PerformanceSummary.fromState(state);

      expect(summary.hasData, isTrue);
      expect(summary.monthValue, 18500);
      expect(summary.monthValueLabel, '₹18.5K');
      expect(summary.ratingLabel, '4.6 ★');
    });

    test('a real avg_rating with zero reviews still shows — (nothing to rate yet)', () {
      final state = PerformanceState(data: {
        'performance': {'month_value': '0', 'avg_rating': '0', 'review_count': 0, 'monthly_trend': [], 'top_products': []},
      });

      expect(PerformanceSummary.fromState(state).ratingLabel, '—');
    });

    test('parses monthly_trend points in order with label + numeric value', () {
      final state = PerformanceState(data: {
        'performance': {
          'month_value': '0',
          'avg_rating': '0',
          'review_count': 0,
          'monthly_trend': [
            {'month': '2026-04', 'label': 'Apr', 'value': '1200'},
            {'month': '2026-05', 'label': 'May', 'value': '0'},
            {'month': '2026-06', 'label': 'Jun', 'value': '4300.50'},
          ],
          'top_products': [],
        },
      });

      final trend = PerformanceSummary.fromState(state).monthlyTrend;

      expect(trend, hasLength(3));
      expect(trend[0].label, 'Apr');
      expect(trend[0].value, 1200);
      expect(trend[1].value, 0);
      expect(trend[2].value, 4300.5);
    });

    test('parses top_products including a real catalog image_url', () {
      final state = PerformanceState(data: {
        'performance': {
          'month_value': '0',
          'avg_rating': '0',
          'review_count': 0,
          'monthly_trend': [],
          'top_products': [
            {
              'product_id': 'p1',
              'name': 'Salmon Steak (250 g)',
              'image_url': 'https://res.cloudinary.com/h9sgzkie/image/upload/salmon.jpg',
              'quantity': '42.5',
              'unit': 'KG',
              'value': '18900',
            },
          ],
        },
      });

      final products = PerformanceSummary.fromState(state).topProducts;

      expect(products, hasLength(1));
      expect(products.single.name, 'Salmon Steak (250 g)');
      expect(products.single.imageUrl, 'https://res.cloudinary.com/h9sgzkie/image/upload/salmon.jpg');
      expect(products.single.quantity, 42.5);
      expect(products.single.value, 18900);
    });

    test('a top product with no product link (legacy free-text item) has a null image, not a crash', () {
      final state = PerformanceState(data: {
        'performance': {
          'month_value': '0',
          'avg_rating': '0',
          'review_count': 0,
          'monthly_trend': [],
          'top_products': [
            {'product_id': null, 'name': 'Legacy Item', 'image_url': null, 'quantity': '5', 'unit': 'KG', 'value': '500'},
          ],
        },
      });

      final products = PerformanceSummary.fromState(state).topProducts;

      expect(products.single.imageUrl, isNull);
      expect(products.single.name, 'Legacy Item');
    });
  });
}
