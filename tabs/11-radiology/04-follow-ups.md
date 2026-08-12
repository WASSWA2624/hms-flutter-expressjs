# Radiology tab — Follow-ups

## 1. Tab strip

- Label: `opdFollowUpsTitle` (not a `radiologyScope*` key)
- Icon: `Icons.phone_callback_outlined`
- Count source: `followUpTabCountProvider(const FollowUpWorklistScope())`; when Filters/search/date narrow the panel, host `onNarrowedCountChanged` overrides the badge
- Count tone: `AppTabCountTone.info` (`radiologySectionCountTone`)
- Deep-link `section`: `follow-ups` (aliases `follow_ups`, `followups`)
- Stage: none (no radiology `applyStage`)
- Tab gate: `RadiologyFollowUpsAtomPermissions.tab` = ∩ `radiology:read` + `radiology-workflows`
- Host: **reused** `FollowUpWorklistPanel` (`storageKeyPrefix: radiology_follow_ups`)
- **Omitted when unauthorized** (also omitted for route-only clinical/billing fallback without radiology read)

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print** (no Request imaging)

- Search: panel-owned follow-up search; Clear shared reset
- Filters: `commonFiltersActionLabel` / `commonAdvancedFiltersTitle`; Apply `opdApplyFiltersAction`; Reset `radiologyClearFiltersAction` (→ `Clear filters`); Close `commonCloseActionLabel`
- Date: `opdFollowUpDateLabel`; From/To `opdDateFromLabel` / `opdDateToLabel`
- Settings: panel-owned follow-up column dialog (`radiology_follow_ups_cols`) — not Radiology desk settings
- Export: gated `RadiologyFollowUpsAtomPermissions.export` (∩ `evidence:export`); omitted when denied
- Print: preview-first `_printRadiologyFollowUpsList` / `commonPrintActionLabel` when print ∩
- Request imaging / Configurations / Orders↔Patients: **not mounted** on this section

## 3. Table

- Row model: `ReceptionFollowUpEntry` (shared follow-up worklist; not `RadiologyOrder`)
- Default columns (**5**; `patient` alwaysVisible): patient, phone, status, date, time
- Column choices: patient ID, email, notes (Settings exposes all; Reset restores defaults)
- Panel storage keys: `radiology_follow_ups_cols` / `radiology_follow_ups_cw`
- Empty: `receptionFollowUpsEmptyTitle` / `receptionFollowUpsEmptyBody`
- Row select → follow-up detail (panel-owned)

## 4. Advanced filters / search fields

- Group `follow_up_status`: `labFollowUpStatusFilterLabel` — Pending / Completed (`labFollowUpStatusPending` / `labFollowUpStatusCompleted`)
- Search text filters: patient / patient id / phone
- Date range on follow-up date (narrowed count syncs active badge)
- No radiology stage / modality / billing gate groups

## 5. Primary / secondary / row actions

- No Request imaging strip action
- Row → follow-up detail
- Detail: Close; Mark completed / Reschedule when write ∩

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Follow-up detail / complete / reschedule | **reused** follow-up panel (`showReceptionFollowUpDetailDialog`) |
| Follow-up column settings | panel-owned |

## 7. Nested / follow-on

When `RadiologyFollowUpsAtomPermissions.write`: Mark completed / Reschedule → Save follow-up. Close for read-only. Hard delete **not mounted**. No radiology procedure / report / configurations chain from this tab.

## 8. Forms (summary)

Detail read + nested reschedule / complete fields (shared panel). Hide tenant/facility/session context the operator already knows.

## 9. Print / labels / preview

- Table Print: `commonPrintActionLabel` → preview-first `printRadiologyWorkspaceList` via `_printRadiologyFollowUpsList` (gated ∩ `evidence:export`)
- Preview title: `printPreviewTitle`
- Print columns align to exportable follow-up fields (patient, phone, status, date, time + optional patient_id / email / notes)
- Detail: no clinicalResult report print from this tab chrome

## 10. Loading / empty / error / success

- Panel empty / loading / retry under `RadiologyFollowUpsAtomPermissions` read ∩
- Hard failure: shared unexpected error + retry
- Success / validation under write ∩ after complete / reschedule

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / search / filters / settings / empty / loading / retry / detail / close | ∩ `radiology:read` + `radiology-workflows` |
| reschedule / markCompleted / saveFollowUp / write | ∩ `radiology:write` + `radiology-workflows` |
| Desk Export | ∩ `evidence:export` (`RadiologyFollowUpsAtomPermissions.export`) |
| Desk Print | ∩ `evidence:export` (`RadiologyFollowUpsAtomPermissions.print`) |
| Request imaging / Configurations (not mounted) | write ∩ (documented only) |
| Billing hold (narrative; not on panel) | billing hold ∩ |
| Request-from-clinical (cross-module; not strip) | clinical radiology ∪ |
| Deep-link route entry | ∪ radiology\|clinical\|billing |
