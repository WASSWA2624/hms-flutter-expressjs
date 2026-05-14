# Project Scope

## Scope
Defines the reusable Flutter foundation this planner must produce and what it must leave to app-specific projects.

## Mandatory rules
- Build a reusable Flutter starter, not a finished product-specific app.
- Keep the starter minimal, professional, and fully runnable without a real backend.
- Support Android, iOS, Web, Windows, macOS, and Linux where the Flutter project and host machine enable those targets.
- Support extra-small mobile screens through large desktop screens; smartwatch-sized layouts are out of scope.
- Include backend readiness through contracts, configuration, repositories, and test doubles, but do not hard-code a product backend.
- Prefer Flutter SDK widgets, Material Design patterns, and small app-level abstractions before adding custom frameworks or extra packages.
- Avoid duplicate dependencies, duplicate folders, duplicate components, duplicate rules, and competing design systems.

## Minimum runnable starter contract
The first complete starter must include:

| Area | Required baseline |
|---|---|
| Startup | `main.dart`, `bootstrap.dart`, app-level provider scope, predictable startup flow |
| App shell | `MaterialApp.router`, `go_router`, not-found route, responsive shell |
| Desktop UI | menu bar, side navigation, collapsible navigation state, readable content width |
| Theme | Material 3 light blue theme, dark theme, system theme mode, shared design tokens |
| State | Riverpod providers and override-ready dependency boundaries |
| Localization | English ARB file, root `l10n.yaml`, generated localization readiness |
| Components | Minimal shared buttons, fields, dialogs, state views, responsive page/layout helpers |
| Quality | format, analyze, tests, CI-ready commands, documentation |

## Implementation standard
- Every template feature must be useful for most Flutter apps.
- Product-specific features must live outside the starter or be added only by a later app-specific plan.
- The template must have one architecture, one routing system, one state system, one theme system, and one shared component strategy.
- The development plan must be executable chronologically from `00` through final validation.

## Acceptance checklist
- The app can run after the starter steps without requiring a production API, credentials, or app-specific data.
- No rule contradicts another rule in `app-rules/`.
- Every dev-plan step references the rule files that govern it.
- A developer or coding agent can follow the plan and produce the same structure, behavior, and UI conventions.

## Related rules
- [`project_structure.md`](./project_structure.md)
- [`architecture.md`](./architecture.md)
- [`dependencies.md`](./dependencies.md)
- [`responsive_adaptive_design.md`](./responsive_adaptive_design.md)
- [`reusable_components.md`](./reusable_components.md)
- [`checklists.md`](./checklists.md)
