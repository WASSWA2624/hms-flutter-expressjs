---
alwaysApply: true
---
# Health Check Rules

Purpose: define runtime health endpoints.

Endpoints:
- `/live`: process is running and event loop is healthy
- `/ready`: dependencies needed for safe traffic are available
- `/health`: operator-facing summary of app status

Rules:
- readiness may check database, storage, websocket gateway, and required background infrastructure
- health responses must never expose secrets or raw stack traces
- startup diagnostics may publish deeper information to logs, not public health payloads
- failing readiness must stop new traffic but should not crash the process by itself
