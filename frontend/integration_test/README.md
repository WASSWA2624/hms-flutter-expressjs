# Integration Tests

Integration tests cover startup, routing, auth guards, responsive shell layout,
and workspace deep-links using provider overrides only — no live backend or secrets.

For Patrol end-to-end suites (real login, module workflows, failure diagnostics),
see [`patrol_test/README.md`](../patrol_test/README.md).

## Suites

| File | Coverage |
| ---- | -------- |
| `startup_navigation_smoke_test.dart` | App boot, home load, 404 route |
| `auth_shell_test.dart` | Unauthenticated redirect, login shell, session restore |
| `routing_guards_test.dart` | Protected workspace routes reject unauthenticated users |
| `responsive_shell_test.dart` | Shell renders at mobile + desktop viewports |
| `module_navigation_test.dart` | Deep-link to each workspace route with mocked session |
| `pharmacy_catalog_dialog_test.dart` | Pharmacy **Catalog and stock** dialog open/dismiss (desktop runner, web viewport) |

## Run locally

From `frontend/`:

```sh
flutter test integration_test
```

When multiple Flutter devices are available, pass the target explicitly:

```sh
flutter test integration_test -d <deviceId>
```

Run a specific suite:

```sh
flutter test integration_test/auth_shell_test.dart
```

## Related docs

- [`patrol_test/README.md`](../patrol_test/README.md) — E2E with seeded backend
- [`docs/release/build-ci-release.md`](../docs/release/build-ci-release.md) — CI quality gates
