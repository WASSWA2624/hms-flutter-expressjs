# P015 Offline

Goal: publish the backend sync contract after core modules are stable.

Safe offline candidates:
- patient registry quick edits with conflict checks
- scheduling drafts and queue updates where idempotency exists
- nursing and observation drafts
- housekeeping task updates and selected biomedical field updates

Online-only actions:
- auth and session issuance
- entitlements and subscription changes
- break-glass approval
- payments, refunds, payroll finalization
- Mortuary release approval and final release
- shift close, day close, and closeout finalization

Acceptance:
- offline-capable endpoints expose version metadata and idempotency behavior
- conflict responses are deterministic and documented for frontend consumers
