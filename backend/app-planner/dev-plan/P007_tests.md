# P007 Tests

Goal: make testing part of the implementation contract.

Do:
- establish schema, repository, service, controller, route, and script test templates
- add access-control regression coverage for roles, entitlements, ABAC, and break-glass flows
- add workflow tests for high-risk domains such as billing, biomedical, mortuary, and closeout

Acceptance:
- every new backend module lands with mirrored tests
- data-changing scripts have tests or explicit justification
- docs and tests ship in the same change as behavior changes
