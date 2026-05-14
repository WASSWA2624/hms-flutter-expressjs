# Validation Strategy

## Scope
Defines validation ownership for user input, API data, domain values, and local persistence.

## Mandatory rules
- Validate user input before submission.
- Validate or safely map backend responses before converting them to domain entities.
- Keep user-facing validation messages localized.
- Keep reusable validation functions in shared/core validation utilities.
- Keep business-specific validation in the feature domain or controller layer.
- Do not rely on frontend validation only; backend validation remains required for real products.
- Preserve invalid raw external data only where needed for diagnostics, never as trusted domain state.

## Validation ownership
| Validation type | Owner |
|---|---|
| Required field | form/controller/shared validator |
| Format | shared validator/value object |
| Business rule | domain/use case |
| Server constraint | backend + frontend mapping |
| API response shape | DTO/parser/mapper |

## Acceptance checklist
- Validation is tested for important fields and value objects.
- Server validation errors display cleanly.
- Invalid states are not silently accepted into domain models.

## Related rules
- [`forms.md`](./forms.md)
- [`data_modeling.md`](./data_modeling.md)
- [`error_handling.md`](./error_handling.md)
