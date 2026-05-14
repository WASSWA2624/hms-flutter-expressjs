# Flutter Multi-Platform App Template Blueprint

## Purpose
This document defines the reusable Flutter foundation that the `app-rules/` and `dev-plan/` files implement.

The template is intended for building many different apps with the same architecture, conventions, responsive behavior, UI consistency, and development workflow.

## Supported platforms
- Android
- iOS
- Web
- Linux desktop
- Other desktop platforms where enabled by the project

## Supported screen sizes

| Token | Width range | Target layout |
|---|---:|---|
| `xs` | `< 360` | extra-small mobile, one column, compact spacing |
| `sm` | `360-599` | mobile, one column |
| `md` | `600-839` | large mobile / small tablet, one or two columns |
| `lg` | `840-1199` | tablet / small desktop, adaptive navigation |
| `xl` | `1200-1599` | desktop, centered readable content |
| `xxl` | `>= 1600` | large desktop, max-width layouts, avoid over-stretching |


Smartwatch-sized layouts are outside the required scope.

## Core principles
- Keep the starter functional, minimal, complete, flexible, responsive, and scalable.
- Keep the backend separate and app-specific.
- Provide API integration readiness without hard-coding product backend logic.
- Use one architecture and one design system throughout the codebase.
- Prefer Flutter built-in widgets and stable packages before custom components.
- Avoid duplicate components, duplicate folders, duplicate state systems, and duplicate rules.
- Localize all user-facing text.
- Keep the template secure by default and production-aware.

## Architecture blueprint
Use feature-first clean architecture.

```txt
lib/
├── main.dart
├── bootstrap.dart
├── app/
│   ├── app.dart
│   ├── router/
│   ├── startup/
│   └── theme/
├── core/
│   ├── config/
│   ├── errors/
│   ├── logging/
│   ├── network/
│   ├── permissions/
│   ├── responsive/
│   ├── security/
│   ├── storage/
│   ├── sync/
│   └── utils/
├── features/
│   └── <feature_name>/
│       ├── data/
│       ├── domain/
│       └── presentation/
├── l10n/
└── shared/
    ├── components/
    ├── forms/
    ├── layout/
    └── widgets/
```

## Approved dependency stack
| Area | Approved packages |
|---|---|
| State and DI | `flutter_riverpod`, `riverpod_annotation` |
| Routing | `go_router` |
| Networking | `dio` |
| Models and JSON | `freezed_annotation`, `json_annotation` |
| Local database | `drift`, `drift_flutter` |
| Simple settings | `shared_preferences` |
| Secure storage | `flutter_secure_storage` |
| Connectivity hint | `connectivity_plus` |
| File paths | `path_provider` |
| Deep links and external URLs | `app_links`, `url_launcher` |
| Localization | `flutter_localizations`, `intl` |
| Generation and tests | `build_runner`, `riverpod_generator`, `freezed`, `json_serializable`, `drift_dev`, `flutter_lints`, `riverpod_lint`, `custom_lint`, `flutter_test`, `integration_test`, `mocktail` |

## Required startup capabilities
- Environment configuration.
- Logging setup.
- Theme mode restoration.
- Locale restoration.
- Secure/session restoration readiness.
- Router guard readiness.
- Local storage/database readiness.
- Clear startup loading and error states.

## Required UI capabilities
- Material 3 light theme by default.
- Dark theme.
- System theme mode.
- Responsive page constraints.
- Shared buttons, fields, select fields, radio groups, date fields, dialogs, state views, and data/list components.
- Accessibility labels and keyboard/pointer/touch support.

## Localization requirement
English is the initial development locale. Every user-facing string must come from localization files, including labels, buttons, validation messages, errors, empty states, and accessibility labels.

## Backend assumption
The backend is separate and app-specific. The template must provide networking, repository, DTO, error mapping, auth/session, and offline/sync readiness without embedding a specific backend contract.

## Development plan
Follow the files in `dev-plan/` from `01` to `23`. Each step references the exact rules that govern the implementation.

## Final standard
A developer or coding agent following this blueprint, the app rules, and the dev plan should produce the same foundational architecture, same visual conventions, same responsive behavior, same state management approach, and same implementation workflow.
