# App Planner

This folder is a reusable planning and implementation guide for Flutter apps. Place `app-planner/` at the root of the Flutter project and follow the rules and development plan before adding app-specific features.

## Folder roles

| Folder | Purpose |
|---|---|
| `app-rules/` | Permanent architecture, UI, platform, security, testing, and maintenance standards. These rules define what the app must follow. |
| `dev-plan/` | Chronological implementation steps for creating or normalizing a minimal, professional, runnable Flutter starter. |

## How to use

1. Read `app-rules/scope.md` and `dev-plan/00-execution-policy.md` first.
2. Execute `dev-plan/01` through `dev-plan/23` in order.
3. At every step, inspect the current Flutter project before changing files.
4. Keep correct existing files unchanged; patch only missing, incomplete, duplicated, or non-compliant work.
5. Do not add product-specific behavior unless a later app-specific plan requires it.

## Starter outcome

Following this planner must produce a minimal but runnable Flutter app with:

- Android, iOS, Web, Windows, macOS, and Linux readiness where the local Flutter host supports those targets.
- A clean feature-first architecture.
- Riverpod for state and dependency injection.
- `go_router` for navigation.
- A professional Material Design theme system with a blue light theme and clean dark theme.
- Responsive mobile, tablet, web, and desktop layouts.
- Desktop menu bar, side navigation, collapsible navigation behavior, and readable content constraints.
- Localization, accessibility, testing, CI, and documentation foundations.

## Rule precedence

When files disagree, resolve them in this order:

1. `app-rules/`
2. `dev-plan/00-execution-policy.md`
3. Numbered `dev-plan/` steps
4. App-specific requirements

If a numbered step repeats a rule, treat the rule file as the source of truth and update the step instead of duplicating the rule.
