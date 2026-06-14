# P003 App

Goal: make the backend bootable with the final middleware order.

Do:
- build the Express app and root router
- mount `/health`, `/ready`, `/live`, and `/api/v1`
- wire validation, auth, entitlements, authorization, and error middleware in the canonical order
- add graceful shutdown and startup diagnostics

Acceptance:
- the app boots cleanly in development and test
- health endpoints behave correctly
- module routes can now be mounted without changing bootstrap behavior
