# Tooling Scripts

Place project maintenance scripts here. Scripts should be portable across
Linux and macOS unless a platform-specific filename or README states otherwise.

## Standard commands

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

Use `dart run build_runner watch --delete-conflicting-outputs` during model,
provider, or database schema work when continuous generation is useful.
