# Checklists and Final Standard

## Scope
Defines final review checklists for the reusable Flutter starter.

## Starter readiness checklist
- Project structure follows `project_structure.md`.
- Architecture boundaries follow `architecture.md`.
- Dependencies follow `dependencies.md` and only actively used packages are added.
- Theme supports light, dark, and system mode.
- Light theme is blue-based and dark theme is clean, readable, and Material-aligned.
- Localization is configured with English as the initial locale.
- Responsive utilities and breakpoints are implemented.
- Desktop layouts include a menu bar, side navigation, collapsible navigation behavior, and readable content constraints.
- Shared components are minimal, theme-aware, accessible, and not oversized.
- Routing uses `go_router`; route guards are ready.
- State management uses Riverpod only.
- API, storage, offline, and auth contracts are ready without hard-coded product backend logic.
- Tests and CI commands are documented.

## Per-feature checklist
- Feature folder follows the standard structure.
- User-facing strings are localized.
- UI uses theme tokens and shared components.
- Loading, empty, error, and success states are handled.
- Forms validate and preserve recoverable input.
- Data models are mapped explicitly.
- Tests cover controller and critical UI behavior.

## Final standard
A developer or coding agent following the rules and dev plan must produce the same architecture, conventions, responsive behavior, theming behavior, and reusable component patterns.

## Related rules
- [`scope.md`](./scope.md)
- [`validation_report.md`](./validation_report.md)
- [`documentation_standards.md`](./documentation_standards.md)
