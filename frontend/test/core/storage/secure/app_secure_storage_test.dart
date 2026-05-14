import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_template/core/storage/secure/app_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlutterAppSecureStorage', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
    });

    test('reads and writes sensitive values through secure storage', () async {
      const store = FlutterAppSecureStorage(FlutterSecureStorage());

      await store.write(
        key: SecureStorageKeys.accessToken,
        value: 'access-token',
      );

      expect(await store.read(SecureStorageKeys.accessToken), 'access-token');
    });

    test('deletes sensitive values', () async {
      const store = FlutterAppSecureStorage(FlutterSecureStorage());

      await store.write(
        key: SecureStorageKeys.refreshToken,
        value: 'refresh-token',
      );
      await store.delete(SecureStorageKeys.refreshToken);

      expect(await store.read(SecureStorageKeys.refreshToken), isNull);
    });
  });
}
