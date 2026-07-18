# P007 Backend Testing
Ensure new behavior ships with proportional regression protection.

## Coverage

- Establish schema, repository, service, controller, route, and script test templates.
- Access tests must cover roles, entitlements, ABAC, and break-glass flows.
- Workflow tests must cover high-risk billing, biomedical, Mortuary, and closeout behavior.

## Delivery Gate

- Every new module must include mirrored tests.
- Data-changing scripts must have tests or an explicit justification.
- Documentation and tests must ship with the behavior they describe.
- The test suite should remain deterministic and runnable through `npm test`.
