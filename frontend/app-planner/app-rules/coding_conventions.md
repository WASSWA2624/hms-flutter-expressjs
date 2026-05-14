# Coding Conventions

## Scope
Defines naming, imports, style, and file focus conventions.

## Mandatory rules
- Use `snake_case.dart` for file names.
- Use `PascalCase` for classes, enums, typedefs, and extensions.
- Use `camelCase` for variables, methods, parameters, and providers.
- Use `_privateName` for private members.
- Prefer package imports for cross-folder imports.
- Use relative imports only inside the same small folder tree.
- Avoid circular imports.
- Use `const` constructors where possible.
- Keep widgets focused and small.
- Avoid business logic inside widgets.
- Use typed models instead of maps for app data.
- Do not hard-code route strings, user-facing text, colors, spacing, or repeated formatting.
- Treat analyzer warnings seriously.

## File focus rule
| File type | Owns |
|---|---|
| `*_page.dart` | page composition and layout |
| `*_controller.dart` | user actions and presentation state |
| `*_state.dart` | UI state shape |
| `*_repository.dart` | domain contract |
| `*_repository_impl.dart` | data coordination |
| `*_dto.dart` | API data shape |
| `*_mapper.dart` | explicit conversion |

## Import order
1. Dart SDK imports.
2. Flutter imports.
3. Package imports.
4. Project imports.

## Acceptance checklist
- Formatting passes.
- Analyzer passes.
- Naming and file placement are consistent across features.
- The same type of change is made in the same type of file across the codebase.

## Related rules
- [`architecture.md`](./architecture.md)
- [`localization_i18n.md`](./localization_i18n.md)
- [`theming.md`](./theming.md)
- [`navigation.md`](./navigation.md)
