# CI/CD and Quality Gates

## Scope
Defines automated checks and release readiness gates.

## Mandatory rules
- CI must fail on formatting differences.
- CI must fail on analyzer errors.
- CI must fail when required tests fail.
- CI must fail when generated code is stale if generated files are committed.
- CI must not use production credentials.
- CI must avoid printing secrets.
- Release builds must use production-safe configuration.
- Deployment scripts must be POSIX-friendly when intended for Linux/macOS CI or servers.
- Platform builds may be split by operating system when host tooling requires it.

## Standard local quality commands
```bash
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

Run generation before analysis when the project uses generated files:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Platform build commands
```bash
flutter build web
flutter build apk
flutter build appbundle
flutter build ios      # macOS host only
flutter build macos    # macOS host only
flutter build windows  # Windows host only
flutter build linux    # Linux host only
```

## Release checklist
- Version is set correctly.
- Formatting passes.
- Analyzer passes.
- Tests pass.
- Generated code is current when generation is used.
- No secrets are committed.
- Production API URL and logging level are correct.
- Supported platform builds complete on compatible hosts.

## Acceptance checklist
- CI reproduces the local quality gate commands.
- Builds are deterministic enough for release packaging.
- Release artifacts and platform host requirements are documented.

## Related rules
- [`testing.md`](./testing.md)
- [`dependencies.md`](./dependencies.md)
- [`security.md`](./security.md)
- [`platform_guidelines.md`](./platform_guidelines.md)
