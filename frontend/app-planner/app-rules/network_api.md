# Network and API Strategy

## Scope
Defines HTTP access, API clients, interceptors, error mapping, and backend-agnostic contracts.

## Mandatory rules
- Use repository contracts in the domain layer instead of calling HTTP from UI.
- Use `dio` for HTTP clients and interceptors.
- Keep API DTOs in the data layer.
- Map API errors into app failures before they reach the UI.
- Apply request timeouts.
- Do not log tokens, passwords, or sensitive payloads.
- Handle unauthorized responses through the session manager.
- Keep backend URLs and timeouts environment-driven.
- Support cancellation where long requests can become stale.

## Client standard
```txt
core/network/
├── api_client.dart
├── api_endpoints.dart
├── api_interceptors.dart
├── api_result.dart
└── network_failure_mapper.dart
```

## Error mapping
| Backend condition | App result |
|---|---|
| timeout | localized retryable network failure |
| no reachable internet | localized offline/network failure |
| `401` | session refresh or logout flow |
| `403` | forbidden failure |
| `404` | not found failure |
| validation error | field/server validation failure |
| unexpected response | generic safe failure |

## Acceptance checklist
- API logic is testable without rendering widgets.
- The UI receives typed results or failures, not raw `DioException` objects.
- Token refresh is centralized.

## Related rules
- [`authentication_session.md`](./authentication_session.md)
- [`error_handling.md`](./error_handling.md)
- [`security.md`](./security.md)
- [`offline_sync.md`](./offline_sync.md)
