# Home Feature

Role-based landing dashboard for HOSSPI HMS staff after login.

## Capabilities

- Role-specific quick actions, shortcuts, KPI strip, queue preview, and alerts
- Live data from `GET /dashboard-workspace/workspace` when tenant context and feature flag allow
- Graceful profile fallback when the workspace API is unavailable or disabled
- Tenant/facility/branch context selection via `GET /dashboard-workspace/lookups`
- Realtime refresh on patient, OPD, IPD, billing, and communications domain events

## Layout

```
presentation/
  controllers/home_controller.dart
  pages/home_page.dart
  widgets/home_context_panel.dart
domain/
  entities/home_dashboard.dart
  entities/home_dashboard_profiles.dart
  entities/home_dashboard_guided_content.dart
  entities/home_dashboard_lookups.dart
data/
  repositories/home_repository_impl.dart
  dtos/
```

## Boundary rules

- Presentation must not call APIs directly; use `HomeRepository` via Riverpod controllers.
- Domain entities are the UI source of truth for dashboard shape.
- Data maps API DTOs into domain entities before returning them.
