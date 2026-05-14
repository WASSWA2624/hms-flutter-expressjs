# 01 - Project setup

## Goal
Create or normalize the Flutter project root for consistent multi-platform development.

## Applies app rules
- [`scope.md`](../app-rules/scope.md)
- [`project_structure.md`](../app-rules/project_structure.md)
- [`platform_guidelines.md`](../app-rules/platform_guidelines.md)
- [`documentation_standards.md`](../app-rules/documentation_standards.md)

## Implementation tasks
1. Follow [`00-execution-policy.md`](./00-execution-policy.md).
2. If no Flutter project exists, create one with the supported platform set:
   ```bash
   flutter create . --platforms=android,ios,web,windows,macos,linux
   ```
3. If a Flutter project already exists, inspect it and normalize only missing or non-compliant files.
4. Ensure root files exist: `pubspec.yaml`, `analysis_options.yaml`, `README.md`, `l10n.yaml`, `docs/`, `lib/`, `test/`, `integration_test/`, and `tool/`.
5. Keep the initial app minimal and runnable; do not add product-specific backend behavior.
6. Confirm scripts and documentation are safe for Linux/macOS line endings.

## Expected output
- Clean Flutter project root.
- Supported platform folders where the host and project allow them.
- Root documentation and required folders.

## Acceptance criteria
- `flutter pub get` succeeds.
- Project structure matches `project_structure.md`.
- The project remains backend-agnostic.
