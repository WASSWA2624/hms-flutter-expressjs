# Subscriptions Tab: Single Worklist with Module Access in Detail

Collapse the Subscriptions panel into one subscriptions worklist. Surface tenant module access and Assign module inside the existing subscription detail dialog—without regressing create/edit/renew/cancel, Denied modules, or RBAC.

## Context

Current UI (`frontend/lib/features/subscriptions`), matching screenshots:

- Primary tabs already include Overview, Plans, Modules, Subscriptions, Invoices, Licenses, Denied modules.
- Under **Subscriptions** (`panel=operations`), a nested strip still exposes **Subscriptions** | **Module subscriptions**.
- Subscriptions worklist shows tenant/plan/status/amount/expiry with **New subscription** after Export.
- Module subscriptions is a separate worklist with **Assign module** after Export.
- Row select opens `_openSubscriptionDetailDialog` → `_SubscriptionDetailPanel` with header, actions (Edit / Renew / Change plan / Activate / Cancel), fields, and timeline. Module enable/disable actions exist only when the selected item is a `moduleSubscriptions` row.
- Plan detail already shows included modules via Manage modules; tenant subscription detail does **not** yet list granted vs unavailable modules or host Assign module.
- Assign/toggle module dialogs, controller mutations, and `SubscriptionsAtomPermissions` (`create`, `assignModule`, `toggleModule`, `update`, etc.) already exist.
- Denied modules remains a separate primary tab for entitlement-denied rows; keep it.

**Definitions**

- **Granted modules**: module subscriptions for the selected tenant that are active and not entitlement-denied.
- **Unavailable modules**: catalog modules the tenant lacks, or module subscriptions that are inactive / entitlement-denied (reuse existing status/eligibility fields; do not invent new entitlement rules).

## Requirements

1. **Remove nested strip.** On the Subscriptions primary tab, show only the subscriptions worklist. Remove the nested **Subscriptions | Module subscriptions** resource tabs from `panel=operations`.
2. **Default resource.** Selecting Subscriptions always loads `resource=subscriptions`. Do not mount a Module subscriptions worklist under this panel.
3. **Preserve New subscription.** Keep **New subscription** as a worklist trailing action after Export, gated by existing create atoms; omit when unauthorized.
4. **Subscription detail entry.** Keep row-select → subscription detail dialog. Detail must identify the tenant and subscription (plan, status, dates, amounts) using existing detail chrome.
5. **Module access section.** Inside the subscription detail dialog, add a progressive-disclosure section that lists **Granted** and **Unavailable** modules for that tenant/subscription. Reuse workspace lookups and module-subscription data already available via repository/controller (fetch or filter by `tenantId` / subscription when needed). Show loading, empty, and error/retry states for that section.
6. **Detail actions.** Keep existing subscription actions (Edit, Renew, Change plan, Activate, Cancel) under current permission atoms. Add **Assign module** in the detail (section or action row), reusing `_showModuleSubscriptionDialog` (or equivalent) prefilled for the selected tenant when possible. Gate with `assignModule`; omit when unauthorized. Where toggle enable/disable already applies to a module row shown in the section, keep those actions under `toggleModule`.
7. **Remove Module subscriptions worklist entry points.** Remove the nested-tab path and its search-bar **Assign module** primary from operations. Do not delete backend module-subscription APIs or Denied modules.
8. **Deep links.** Preserve compatibility: `panel=operations&resource=module-subscriptions` (without denied/blocked queue) redirects to the subscriptions worklist, optionally opening the matching tenant subscription detail when `tenantId` / `id` is present. `queue=MODULE_BLOCKED` / Denied panel behavior stays on the Denied modules tab.
9. **Authorization and sync.** Backend RBAC/ABAC remains authoritative. Unauthorized tabs, sections, and actions must not render. After assign/toggle/edit mutations, refresh detail module lists and parent worklist/summary counts.
10. **Theme and layout.** New detail section uses theme tokens (light/dark), remains usable on mobile/tablet/desktop without clipping, and stays visually hierarchical under the existing detail header/actions.

### Optional enhancements

- Module search/filter inside the detail section when the catalog is large.
- Badge on the detail section header for denied-module count for that tenant only.

## Constraints

- Follow `prompts/.cursor/prompt.mdc` and `.cursor/access/subscriptions.mdc`.
- Reuse `subscriptions_workspace_page.dart` detail dialogs, `subscriptions_workspace_controller.dart`, DTOs, assign/toggle flows, and design-system panels/tables—no parallel module-subscription UI.
- Do not remove the Modules catalog tab, Denied modules tab, or plan Manage modules flow.
- No unrelated refactors; do not recreate `screens/` inventories.

## Acceptance Criteria

1. Subscriptions primary tab shows one worklist and no nested Subscriptions/Module subscriptions strip.
2. New subscription remains after Export when authorized and is absent when not.
3. Opening a subscription shows tenant/subscription detail plus Granted and Unavailable module lists with loading/empty/error states.
4. Assign module appears in that detail when authorized, opens the existing assign flow for the tenant, and is omitted when unauthorized; enable/disable remain permission-gated where shown.
5. Module subscriptions is no longer reachable as a nested operations worklist; Denied modules tab still lists entitlement-denied rows.
6. Legacy `resource=module-subscriptions` under operations redirects as in Requirement 8; post-mutation detail and list data stay in sync.
7. Light/dark and mobile/tablet/desktop layouts show no overflow/clipping of the new section or actions.

## Relevant Files

- `frontend/lib/features/subscriptions/presentation/pages/subscriptions_workspace_page.dart`
- `frontend/lib/features/subscriptions/presentation/controllers/subscriptions_workspace_controller.dart`
- `frontend/lib/features/subscriptions/presentation/subscriptions_access.dart`
- `frontend/lib/features/subscriptions/domain/entities/subscription_entities.dart`
- `backend/src/modules/subscriptions-workspace/` (only if tenant-scoped module list needs an existing endpoint/filter)
- `frontend/test/features/subscriptions/presentation/` (especially tab + subscriptions permissions tests)

## Verification

- Update tests: nested Module subscriptions strip absent; Assign module absent from operations search bar; Assign module present in authorized subscription detail and absent when unauthorized; Granted/Unavailable section states covered.
- Manual: open subscription → assign module → list/detail refresh; Denied modules tab unchanged; light/dark; phone/tablet/desktop.
- Confirm deep-link aliases from Requirement 8.
