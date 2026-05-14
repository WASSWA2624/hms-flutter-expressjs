# Architecture Conventions

## Scope
Defines the app architecture, dependency direction, and boundaries between presentation, domain, and data code.

## Architecture style
Use feature-first clean architecture:

```txt
presentation -> domain -> data contracts
              data implementation -> external services
```

The UI depends on controllers/state. Controllers call use cases or repositories. Repositories coordinate data sources. Data sources talk to APIs, local databases, secure storage, or platform services.

## Mandatory rules
- Widgets must not call APIs directly.
- Widgets must not read or write databases directly.
- Widgets must not store tokens or secrets.
- Repositories must not show dialogs, snackbars, or navigate.
- Data sources must not contain UI state.
- Domain entities must not depend on Flutter widgets.
- `core` must not contain feature-specific business rules.
- Feature modules should expose only intentional public entry points.
- Use cases are optional for simple CRUD flows, but required when business decisions span multiple repositories or rules.
- Mapping between DTOs, database models, and domain entities must be explicit.

## Layer responsibilities
| Layer | Owns | Must not own |
|---|---|---|
| Presentation | pages, widgets, controllers, UI state | API calls, SQL, token storage |
| Domain | entities, value objects, repository contracts, use cases | JSON parsing, widgets, database tables |
| Data | repository implementations, DTOs, mappers, data sources | navigation, UI messages |
| Core | reusable infrastructure | app-specific business rules |
| Shared UI | reusable components and layouts | domain decisions |

## Acceptance checklist
- Dependency direction is consistent inside every feature.
- Presentation tests can override providers without touching production data sources.
- Data models do not leak into widgets.
- Business decisions are testable without rendering widgets.

## Related rules
- [`project_structure.md`](./project_structure.md)
- [`state_management.md`](./state_management.md)
- [`network_api.md`](./network_api.md)
- [`database_strategy.md`](./database_strategy.md)
- [`data_modeling.md`](./data_modeling.md)
