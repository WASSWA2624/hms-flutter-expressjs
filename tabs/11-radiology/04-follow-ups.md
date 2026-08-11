# Radiology tab — Follow-ups

## 1. Tab strip

- Label: `opdFollowUpsTitle`
- Icon: `Icons.phone_callback_outlined`
- Count source: `followUpTabCountProvider(const FollowUpWorklistScope())`
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `follow-ups` (aliases `follow_ups`, `followups`)
- Stage: none (no radiology `applyStage`)
- Tab gate: `RadiologyFollowUpsAtomPermissions.tab` = ∩ `radiology:read` + `radiology-workflows`
- **Omitted when unauthorized** (also omitted for route-only clinical/billing fallback without radiology read)

## 2. Search / Filters / Settings / Export / Print / context

- Hosted by **reused** `FollowUpWorklistPanel` (`storageKeyPrefix: 'radiology_follow_ups'`)
- Request imaging / Configurations / Orders↔Patients: **not mounted** on this section
- Search / Clear / Settings (columns) per shared follow-up panel chrome
- Filters / Export / Print: follow panel implementation (Radiology does not add strip create)

## 3. Table

- Row model: shared follow-up worklist rows (not `RadiologyOrder`)
- Row select → follow-up detail (panel-owned)
- Columns / settings storage under `radiology_follow_ups*` prefix

## 4. Advanced filters / search fields

- Per **reused** `FollowUpWorklistPanel` (no radiology stage/modality/billing gate groups on this host)

## 5. Primary / secondary / row actions

- No Request imaging strip action
- Detail: Close; Mark completed / Reschedule when write-authorized

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Follow-up detail / complete / reschedule | **reused** follow-up panel |

## 7. Nested / follow-on

- Reschedule / Mark completed forms inside follow-up panel (write ∩)
- No radiology procedure / report / configurations chain from this tab

## 8. Forms (summary)

- Complete / reschedule follow-up fields (shared panel)

## 9. Print / labels / preview

- No Radiology print report entry from this tab chrome
- Panel-owned print if any is shared follow-up behavior (not radiology clinicalResult)

## 10. Loading / empty / error / success

- Panel empty / loading / retry under `RadiologyFollowUpsAtomPermissions` read
- Success / validation under write ∩ after complete / reschedule

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / chrome / detail / close | `RadiologyFollowUpsAtomPermissions` read ∩ |
| Mark completed / Reschedule / Save | write ∩ `radiology:write` |
| Request imaging / Configurations | write ∩ documented — **not mounted** |
| Billing hold | narrative / reuse only — not on panel |
| Route entry | ∪ radiology\|clinical\|billing |
