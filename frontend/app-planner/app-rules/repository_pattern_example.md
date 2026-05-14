# Repository Pattern Example

## Scope
Shows the expected boundary between domain contracts, data implementation, and data sources.

## Domain contract
```dart
abstract class ProfileRepository {
  Future<Result<Profile>> getCurrentProfile();
}
```

## Data implementation
```dart
class ProfileRepositoryImpl implements ProfileRepository {
  const ProfileRepositoryImpl({
    required ProfileRemoteDataSource remoteDataSource,
    required ProfileLocalDataSource localDataSource,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource;

  final ProfileRemoteDataSource _remoteDataSource;
  final ProfileLocalDataSource _localDataSource;

  @override
  Future<Result<Profile>> getCurrentProfile() async {
    try {
      final dto = await _remoteDataSource.getCurrentProfile();
      final profile = dto.toEntity();
      await _localDataSource.cacheProfile(profile);
      return Result.success(profile);
    } catch (error, stackTrace) {
      return Result.failure(mapToFailure(error, stackTrace));
    }
  }
}
```

## Rules
- Widgets depend on controllers, not repository implementations.
- Domain depends on repository contracts, not remote/local data sources.
- Data implementations map external data into domain entities.
- Failures are mapped before reaching presentation code.
- Repository implementations must not navigate or show UI messages.

## Related rules
- [`architecture.md`](./architecture.md)
- [`data_modeling.md`](./data_modeling.md)
- [`network_api.md`](./network_api.md)
- [`error_handling.md`](./error_handling.md)
