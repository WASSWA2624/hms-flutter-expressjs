---
alwaysApply: true
---
# Testing Rules

Purpose: define the minimum backend verification bar.

Required coverage:
- schema validation tests
- repository tests
- service tests
- controller and route tests
- auth, entitlement, ABAC, and break-glass regression tests
- seed and maintenance script tests where scripts change data or contracts

Rules:
- every module mirrors its runtime structure in tests
- new modules are incomplete until tests and docs land together
- high-risk domains such as billing, biomedical, mortuary, security, and closeout need workflow-level regression coverage
- mocks must preserve real contract shape for Prisma, storage, websocket, and auth dependencies
