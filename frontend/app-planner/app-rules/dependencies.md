# Dependency Strategy

## Scope
Defines approved dependencies, when they may be added, and how to avoid unnecessary package growth.

## Required starter dependencies
| Purpose | Package | Rule |
|---|---|---|
| State and DI | `flutter_riverpod` | Use for app state, feature state, dependency injection, async state, and provider overrides. |
| Navigation | `go_router` | Use for all navigation, shell routes, guards, deep links, and web URLs. |
| Localization | `flutter_localizations`, `intl` | Use generated localizations and locale-aware formatting. |

## Approved when needed
| Purpose | Package | Add only when |
|---|---|---|
| Riverpod generation | `riverpod_annotation` | Generated providers are adopted consistently. |
| HTTP | `dio` | The app needs real HTTP clients, interceptors, cancellation, or API error mapping. |
| Immutable models | `freezed_annotation` | Model complexity justifies generation. |
| JSON DTOs | `json_annotation` | API DTO serialization is required. |
| Local database | `drift`, `drift_flutter` | Structured local data, offline cache, or sync queues are required. |
| Simple settings | `shared_preferences` | Non-sensitive settings such as theme mode or locale must persist. |
| Secure storage | `flutter_secure_storage` | Tokens or secrets must be stored where supported. |
| Connectivity hint | `connectivity_plus` | Connectivity status is useful as a hint, never as proof of internet access. |
| Paths | `path_provider` | Platform-specific database or cache paths are needed. |
| External links/deep links | `url_launcher`, `app_links` | External URLs, auth handoff, or app links are required. |

## Dev dependencies
| Purpose | Package | Rule |
|---|---|---|
| Lints | `flutter_lints`, `riverpod_lint`, `custom_lint` | Keep analysis strict and Riverpod usage consistent. |
| Testing | `flutter_test`, `integration_test`, `mocktail` | Use provider overrides and mocks for test isolation. |
| Code generation | `build_runner`, `riverpod_generator`, `freezed`, `json_serializable`, `drift_dev` | Add only when the matching runtime/codegen pattern is used. |

## Mandatory rules
- Do not add a dependency when Flutter SDK widgets or Dart standard libraries are enough.
- Do not add duplicate packages for the same responsibility.
- Every new dependency must have a clear owner, purpose, and platform compatibility check.
- Keep dependencies compatible with Android, iOS, Web, Windows, macOS, and Linux unless an app-specific exception documents a narrower target set.
- Avoid packages that are abandoned, unmaintained, or platform-limited unless the app-specific requirement justifies them.
- Do not put secrets in `pubspec.yaml`, assets, source code, docs, or test fixtures.

## Acceptance checklist
- `pubspec.yaml` contains only the required starter packages plus approved packages that are actively used.
- Generated-code dependencies are in `dev_dependencies` where appropriate.
- Dependency decisions are documented in README or an ADR when they affect architecture.

## Related rules
- [`code_generation.md`](./code_generation.md)
- [`platform_guidelines.md`](./platform_guidelines.md)
- [`security.md`](./security.md)
- [`ci_cd_quality_gates.md`](./ci_cd_quality_gates.md)
