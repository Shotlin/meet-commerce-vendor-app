import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freshcuts_vendor_app/core/network/api_client.dart';
import 'package:freshcuts_vendor_app/core/theme/app_theme.dart';

void main() {
  test('theme builds with FreshCuts brand tokens', () {
    final theme = AppTheme.light;
    expect(theme.filledButtonTheme.style, isNotNull);
  });

  test('ApiClient exposes configured base url', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final client = container.read(apiClientProvider);
    expect(client.dio.options.baseUrl, contains('/api/v1'));
  });
}
