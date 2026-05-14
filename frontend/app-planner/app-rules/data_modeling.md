# Data Modeling Strategy

## Scope
Defines entities, DTOs, value objects, mappers, and database models.

## Mandatory rules
- Do not pass API DTOs directly into domain logic.
- Do not make UI depend on raw JSON.
- Do not use database table classes as UI state.
- Use immutable models for app state and domain entities.
- Keep mappers explicit and testable.
- Use value objects for important constrained values.
- Keep DTOs shaped around external API contracts.
- Keep entities shaped around business meaning.
- Keep presentation-only formatting out of domain entities.

## Model types
| Type | Location | Purpose |
|---|---|---|
| Entity | `domain/entities` | business meaning |
| Value object | `domain/entities` or `domain/value_objects` | validated/constrained values |
| DTO | `data/dtos` | API request/response shape |
| Database model | `data/datasources/local` or core database | local persistence shape |
| View state | `presentation/state` | UI-ready state |

## Acceptance checklist
- DTO-to-entity mapping is explicit.
- Invalid external data cannot silently become valid domain state.
- Tests cover important mappers and value objects.

## Related rules
- [`architecture.md`](./architecture.md)
- [`code_generation.md`](./code_generation.md)
- [`validation.md`](./validation.md)
- [`database_strategy.md`](./database_strategy.md)
