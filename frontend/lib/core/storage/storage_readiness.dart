final class StorageReadiness {
  const StorageReadiness({
    required this.localPreferencesReady,
    required this.secureStorageReady,
  });

  const StorageReadiness.ready()
    : localPreferencesReady = true,
      secureStorageReady = true;

  const StorageReadiness.notReady()
    : localPreferencesReady = false,
      secureStorageReady = false;

  final bool localPreferencesReady;
  final bool secureStorageReady;

  bool get isReady => localPreferencesReady && secureStorageReady;
}
