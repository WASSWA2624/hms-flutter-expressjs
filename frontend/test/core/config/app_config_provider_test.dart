import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_template/core/config/app_config.dart';
import 'package:flutter_template/core/config/app_config_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('allows tests to override app configuration', () {
    final config = AppConfig.fromValues(
      environmentName: 'staging',
      apiBaseUrl: 'https://staging-api.example.com',
    );
    final container = ProviderContainer(
      overrides: [appConfigProvider.overrideWithValue(config)],
    );
    addTearDown(container.dispose);

    expect(container.read(appConfigProvider), same(config));
  });
}
