# 01 - Project Setup
Create or normalize the Flutter root without disturbing compliant project files.

## Applicable Rules
You must follow [`00-execution-policy.md`](./00-execution-policy.md), [`scope.mdc`](../.cursor/scope.mdc), [`project_structure.mdc`](../.cursor/project_structure.mdc), [`platform_guidelines.mdc`](../.cursor/platform_guidelines.mdc), and [`documentation_standards.mdc`](../.cursor/documentation_standards.mdc).

## Implementation
1. If no project exists, run:
   ```bash
   flutter create . --platforms=android,ios,web,windows,macos,linux
   ```
2. Otherwise, normalize only missing or noncompliant files.
3. Ensure `pubspec.yaml`, `analysis_options.yaml`, `README.md`, `l10n.yaml`, `docs/`, `lib/`, `test/`, `integration_test/`, and `tool/` exist.
4. The starter must remain minimal, runnable, API-contract-ready, and free of product-specific backend behavior.
5. Scripts and documentation should use portable line endings.

## Acceptance Criteria
- `flutter pub get` must succeed.
- Structure must match `project_structure.mdc`.
- Supported platform folders may depend on host capabilities.
