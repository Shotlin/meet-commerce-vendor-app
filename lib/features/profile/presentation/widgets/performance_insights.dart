import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/product_thumbnail.dart';
import '../providers/performance_provider.dart';

/// Parsed, null-safe view over the raw `/vendor-procurement/vendor/performance`
/// response — shared by the Home overview and the full Performance screen so
/// both read the exact same fields the exact same way.
class PerformanceSummary {
  const PerformanceSummary({
    required this.hasData,
    required this.monthValue,
    required this.avgRating,
    required this.reviewCount,
    required this.monthlyTrend,
    required this.topProducts,
  });

  final bool hasData;
  final num monthValue;
  final num avgRating;
  final int reviewCount;
  final List<TrendPoint> monthlyTrend;
  final List<TopProduct> topProducts;

  factory PerformanceSummary.fromState(PerformanceState state) {
    final data = state.data;
    final performance = data?['performance'];
    if (performance is! Map) {
      return const PerformanceSummary(
        hasData: false,
        monthValue: 0,
        avgRating: 0,
        reviewCount: 0,
        monthlyTrend: [],
        topProducts: [],
      );
    }
    final trend = (performance['monthly_trend'] as List? ?? const [])
        .map((e) => TrendPoint.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final products = (performance['top_products'] as List? ?? const [])
        .map((e) => TopProduct.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return PerformanceSummary(
      hasData: true,
      monthValue: num.tryParse('${performance['month_value']}') ?? 0,
      avgRating: num.tryParse('${performance['avg_rating']}') ?? 0,
      reviewCount: int.tryParse('${performance['review_count']}') ?? 0,
      monthlyTrend: trend,
      topProducts: products,
    );
  }

  String get monthValueLabel {
    if (!hasData) return '—';
    return '₹${NumberFormat.compact().format(monthValue)}';
  }

  String get ratingLabel {
    if (!hasData || reviewCount == 0) return '—';
    return '${avgRating.toStringAsFixed(1)} ★';
  }
}

class TrendPoint {
  const TrendPoint({required this.label, required this.value});

  final String label;
  final num value;

  factory TrendPoint.fromJson(Map<String, dynamic> json) => TrendPoint(
        label: json['label']?.toString() ?? '',
        value: num.tryParse('${json['value']}') ?? 0,
      );
}

class TopProduct {
  const TopProduct({
    required this.name,
    required this.imageUrl,
    required this.quantity,
    required this.unit,
    required this.value,
  });

  final String name;
  final String? imageUrl;
  final num quantity;
  final String unit;
  final num value;

  factory TopProduct.fromJson(Map<String, dynamic> json) => TopProduct(
        name: json['name']?.toString() ?? 'Item',
        imageUrl: (json['image_url'] as String?)?.trim().isNotEmpty == true ? json['image_url'] as String : null,
        quantity: num.tryParse('${json['quantity']}') ?? 0,
        unit: json['unit']?.toString() ?? 'KG',
        value: num.tryParse('${json['value']}') ?? 0,
      );
}

/// A rounded, bordered card shell matching the app's existing metric-card
/// styling (`_MetricCard`/`_KpiCard` in performance_screen.dart/home_screen.dart).
class InsightCardShell extends StatelessWidget {
  const InsightCardShell({super.key, required this.child, this.height, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final double? height;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

/// Monthly revenue bar chart — the last several months' confirmed
/// (RECEIVED/CLOSED) supply value, zero-filled by the backend so a quiet
/// month renders as a real ₹0 bar instead of a gap.
class EarningsChartCard extends StatelessWidget {
  const EarningsChartCard({super.key, required this.state, required this.summary});

  final PerformanceState state;
  final PerformanceSummary summary;

  @override
  Widget build(BuildContext context) {
    if (state.loading && state.data == null) {
      return const InsightCardShell(
          height: 190, child: Center(child: CircularProgressIndicator(color: AppColors.brandRed)));
    }
    if (!summary.hasData) {
      return const InsightCardShell(
        height: 120,
        child: Center(child: Text('Could not load earnings', style: TextStyle(color: AppColors.muted, fontSize: 12))),
      );
    }
    final trend = summary.monthlyTrend;
    if (trend.isEmpty || trend.every((point) => point.value == 0)) {
      return InsightCardShell(
        height: 120,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.show_chart, color: AppColors.subtle, size: 28),
              const SizedBox(height: 8),
              Text(
                trend.isEmpty
                    ? 'Earnings trend will appear here.'
                    : 'No completed supplies yet — your monthly value will chart here.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ),
      );
    }

    final maxValue = trend.map((p) => p.value.toDouble()).reduce((a, b) => a > b ? a : b);
    final maxY = maxValue <= 0 ? 1.0 : maxValue * 1.25;

    return InsightCardShell(
      height: 190,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      child: BarChart(
        BarChartData(
          maxY: maxY,
          alignment: BarChartAlignment.spaceAround,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.ink,
              getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                '₹${NumberFormat('#,##0').format(rod.toY)}',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= trend.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(trend[index].label,
                        style: const TextStyle(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.w600)),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < trend.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: trend[i].value.toDouble(),
                    width: 18,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    color: i == trend.length - 1 ? AppColors.brandRed : AppColors.brandRedSurface,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Ranked list of the vendor's best-selling products by confirmed supply
/// value — real catalog image, quantity supplied, and revenue per line.
class TopProductsCard extends StatelessWidget {
  const TopProductsCard({super.key, required this.state, required this.summary});

  final PerformanceState state;
  final PerformanceSummary summary;

  @override
  Widget build(BuildContext context) {
    if (state.loading && state.data == null) {
      return const InsightCardShell(
          height: 120, child: Center(child: CircularProgressIndicator(color: AppColors.brandRed)));
    }
    if (!summary.hasData) {
      return const InsightCardShell(
        height: 100,
        child: Center(child: Text('Could not load top products', style: TextStyle(color: AppColors.muted, fontSize: 12))),
      );
    }
    final products = summary.topProducts;
    if (products.isEmpty) {
      return const InsightCardShell(
        height: 100,
        child: Center(
          child: Text(
            'No completed supplies yet — your best sellers will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ),
      );
    }

    return InsightCardShell(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          for (var i = 0; i < products.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: Row(
                children: [
                  Text('${i + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.subtle)),
                  const SizedBox(width: 10),
                  ProductThumbnail(
                    imageUrl: products[i].imageUrl,
                    size: 44,
                    heroTag: 'top-product-$i',
                    title: products[i].name,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(products[i].name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
                        Text(
                          '${NumberFormat('#,##0.##').format(products[i].quantity)} ${products[i].unit} supplied',
                          style: const TextStyle(fontSize: 11, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₹${NumberFormat.compact().format(products[i].value)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
