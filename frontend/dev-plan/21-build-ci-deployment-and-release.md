# 21 - Build, CI, Deployment, and Release Readiness
Prepare reliable quality gates and builds for every enabled Flutter platform.

## Applicable Rules
You must follow [`00-execution-policy.md`](./00-execution-policy.md), [`ci_cd_quality_gates.mdc`](../.cursor/ci_cd_quality_gates.mdc), [`platform_guidelines.mdc`](../.cursor/platform_guidelines.mdc), [`security.mdc`](../.cursor/security.mdc), [`dependencies.mdc`](../.cursor/dependencies.mdc), and [`testing.mdc`](../.cursor/testing.mdc).

## Implementation
1. Document local quality-gate commands.
2. Add CI guidance or configuration when required.
3. Document Android, iOS, Web, Windows, macOS, and Linux build commands plus host restrictions.
4. Verify release configuration and versioning.
5. Production builds must not include debug-only behavior or secrets.

## Acceptance Criteria
- Format, analyze, test, generation, and build commands must be clear.
- Build guidance must cover every enabled platform.
- Build documentation, CI plans/configuration, and a release checklist must be available.
