import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hosspi_hms/core/logging/app_logger.dart';

/// Platform storage used for the session tokens, stated explicitly.
///
/// Session persistence is only as reliable as the store underneath it, and the
/// package defaults differ per platform in ways that decide whether a user is
/// still signed in after closing the app. They are pinned here rather than left
/// implicit so the behavior is reviewable and identical in development and
/// production builds.
///
/// | Platform | Mechanism | Survives app close | Survives reboot |
/// | -------- | --------- | ------------------ | --------------- |
/// | Web      | `localStorage`, AES-GCM encrypted, key wrapped in the same origin | Yes | Yes |
/// | Android  | SharedPreferences, AES-GCM data key wrapped by an RSA-OAEP KeyStore key | Yes | Yes |
/// | Windows  | Credential store via DPAPI, scoped to the Windows user | Yes | Yes |
/// | iOS/macOS| Keychain, `kSecAttrAccessibleAfterFirstUnlock` | Yes | Yes, after first unlock |
/// | Linux    | libsecret (GNOME Keyring / KWallet) | Yes | Yes, once the keyring is unlocked |
///
/// iOS and macOS are overridden to `first_unlock` rather than the package
/// default `unlocked`, so a session restores after a device restart instead of
/// only while the device is unlocked.
///
/// The package defaults carry the rest and are relied on deliberately:
///
/// * Web defaults to `localStorage`, not `sessionStorage`. `useSessionStorage:
///   true` would clear the session on every tab close, which is the exact
///   defect this layer exists to prevent.
/// * Android defaults to `resetOnError: true`. A KeyStore that can no longer
///   decrypt its own data (OS upgrade, restore to a new device, cleared
///   credentials) would otherwise throw on every read and leave the app
///   unusable; dropping the stored tokens costs one sign-in instead. It also
///   defaults to `migrateOnAlgorithmChange: true`, so a cipher upgrade carries
///   existing sessions forward rather than discarding them.
/// * The web `dbName`/`publicKey` and the Android namespace stay at their
///   defaults: changing them renames the stored entries, which would sign out
///   every existing user on the deploy that changed them.
abstract final class AppSecureStorageOptions {
  /// iOS: readable after the first unlock following a restart.
  ///
  /// The package default is `unlocked`, which makes the Keychain entry
  /// unreadable until the user unlocks the device. Restoring a session during
  /// startup would then fail on a cold boot and present the login page to a
  /// signed-in user.
  static const IOSOptions ios = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock,
  );

  /// macOS: readable after the first unlock following a restart, as on iOS.
  static const MacOsOptions macOs = MacOsOptions(
    accessibility: KeychainAccessibility.first_unlock,
  );

  /// The storage handle the app runs on.
  ///
  /// Android, web, Windows, and Linux keep the package defaults documented
  /// above; only the Apple platforms need an override.
  static const FlutterSecureStorage storage = FlutterSecureStorage(
    iOptions: ios,
    mOptions: macOs,
  );
}

abstract interface class AppSecureStorage {
  Future<String?> read(String key);

  Future<void> write({required String key, required String value});

  Future<void> delete(String key);

  Future<void> deleteAll();
}

abstract final class SecureStorageKeys {
  static const String accessToken = 'session.access_token';
  static const String refreshToken = 'session.refresh_token';
  static const String accessTokenExpiresAt = 'session.access_token_expires_at';
}

final class FlutterAppSecureStorage implements AppSecureStorage {
  const FlutterAppSecureStorage(this._storage);

  final FlutterSecureStorage _storage;

  /// Reads a key, treating an unreadable store as "nothing stored".
  ///
  /// A platform keystore can fail for reasons that have nothing to do with the
  /// session — a locked keyring, a browser with site data blocked, a KeyStore
  /// that lost its key. Startup restore runs before the first frame, so a throw
  /// here would take the whole app down instead of showing the login page.
  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (error) {
      AppLogger.warning(
        'Secure storage read failed; treating the session as absent.',
        context: <String, Object?>{'error': error.runtimeType.toString()},
      );
      return null;
    }
  }

  @override
  Future<void> write({required String key, required String value}) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (error) {
      // Logout must still clear in-memory state and reach the login page even
      // if the platform store refuses the delete.
      AppLogger.warning(
        'Secure storage delete failed for a session key.',
        context: <String, Object?>{'error': error.runtimeType.toString()},
      );
    }
  }

  @override
  Future<void> deleteAll() {
    return _storage.deleteAll();
  }
}
