import 'package:flutter_template/core/storage/preferences/app_preferences_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SharedPreferencesAppPreferencesStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('reads and writes non-sensitive preferences', () async {
      final preferences = await SharedPreferences.getInstance();
      final store = SharedPreferencesAppPreferencesStore(preferences);

      expect(await store.setString('app.locale', 'en'), isTrue);
      expect(await store.setBool('feature.enabled', value: true), isTrue);
      expect(await store.setInt('launch.count', 3), isTrue);

      expect(store.getString('app.locale'), 'en');
      expect(store.getBool('feature.enabled'), isTrue);
      expect(store.getInt('launch.count'), 3);
    });

    test('removes preference values', () async {
      final preferences = await SharedPreferences.getInstance();
      final store = SharedPreferencesAppPreferencesStore(preferences);

      await store.setString('app.locale', 'en');
      expect(await store.remove('app.locale'), isTrue);

      expect(store.getString('app.locale'), isNull);
    });
  });
}
