import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_template/core/storage/preferences/app_preferences_store.dart';
import 'package:flutter_template/core/storage/secure/app_secure_storage.dart';
import 'package:flutter_template/core/storage/storage_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('storage providers', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
    });

    test(
      'allow tests to override local and secure storage dependencies',
      () async {
        final SharedPreferences preferences =
            await SharedPreferences.getInstance();
        const secureStorage = FlutterSecureStorage();
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            secureStorageProvider.overrideWithValue(secureStorage),
          ],
        );
        addTearDown(container.dispose);

        expect(container.read(sharedPreferencesProvider), same(preferences));
        expect(container.read(secureStorageProvider), same(secureStorage));
        expect(
          container.read(appPreferencesStoreProvider),
          isA<AppPreferencesStore>(),
        );
        expect(
          container.read(appSecureStorageProvider),
          isA<AppSecureStorage>(),
        );
      },
    );
  });
}
