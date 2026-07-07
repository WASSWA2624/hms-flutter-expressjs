# Integration Tests

Integration tests cover startup, navigation, and platform-critical flows that
must run without production services or secrets.

For Patrol end-to-end suites (module workspaces, failure diagnostics, web/native
automation), see [`patrol_test/README.md`](../patrol_test/README.md).

Run the integration suite locally with:

```sh
flutter test integration_test
```

When multiple Flutter devices are available, pass the target explicitly:

```sh
flutter test integration_test -d <deviceId>
```

Run a specific smoke test with:

```sh
flutter test integration_test/startup_navigation_smoke_test.dart
```
