---
alwaysApply: true
---
# WebSocket Rules

Purpose: define realtime transport behavior.

Rules:
- websocket bootstrap lives in `src/websockets/*`
- clients authenticate before subscribing to privileged channels
- services emit domain events through shared websocket helpers; gateways do not own business logic
- event payloads use stable `snake_case` fields
- channel names and event families must align with module boundaries
- clinical alerts, queue changes, roster publishing, biomedical work orders, mortuary custody changes, notifications, and closeout progress are valid realtime domains
