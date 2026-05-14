# Home Feature

`home` is the starter example feature. It exists to show the feature-first
folder boundary without adding product-specific behavior.

Layer ownership:

- `presentation/` owns pages, widgets, controllers, and view state.
- `domain/` owns entities, value objects, repository contracts, services, and
  use cases.
- `data/` owns repository implementations, DTOs, mappers, and data sources.

Boundary rules:

- Presentation must not call APIs, storage, databases, or platform services.
- Domain must not depend on Flutter widgets or external data models.
- Data must map external models into domain models before returning them.
