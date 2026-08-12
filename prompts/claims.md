# Flatten Claims nested queues into independent tabs

## Context

The Insurance claims workspace (`ClaimsWorkspacePage`, route `AppRoutes.claims`, query `section`) currently uses four primary `AppTabStrip` sections: **Authorizations**, **Active Claims**, **Settled**, and **Insurance Setup**.

Authorizations and Active Claims also render a nested `_ClaimsSummaryBar` of `ActionChip` workload chips that apply a `ClaimsQueueFilter` without changing the primary tab. Those chips are subordinate navigation, not `AppTabStrip` items.

### Current nested chips (convert these)

| Parent tab | Nested chip label | `ClaimsQueueFilter` | Summary count |
| --- | --- | --- | --- |
| Authorizations | Auth pending | `authorizationPending` | `authorizationPendingCount` |
| Authorizations | Auth approved | `authorizationApproved` | `authorizationApprovedCount` |
| Active Claims | Submitted | `claimSubmitted` | `submittedClaimsCount` |
| Active Claims | Approved | `claimApproved` | `approvedClaimsCount` |
| Active Claims | Partial claims | `claimPartial` | `partialClaimsCount` |
| Active Claims | Claim rejected | `claimRejected` | `rejectedResubmissionCount` |

Settled has no nested chips. Insurance Setup is a catalog hub (Add company / scheme / offer / Enroll patient / Add price / Insurer API) and is **out of scope** except that it remains a primary tab.

**Request authorization** and **Prepare claim** currently mount as `AppTabStrip.primaryAction`. Move them onto the queue table search bar for the tabs that need them, after Print.

Follow [tabs.mdc](/.cursor/tabs.mdc) for the strip, [tables.mdc](/.cursor/tables.mdc) for search-bar action order, [screens.mdc](/.cursor/screens.mdc) for in-desk `section` query sync, and [prompt.mdc](/.cursor/prompt.mdc) for RBAC and UI states. Do not restate those files.

### Terms

- **Independent tab:** a primary `AppTabStrip` item (`AppTabStripVariant.standard`) with its own `section` query value, dedicated queue scope, and count badge. Not a nested chip, `ActionChip` row, or `AppTabStripVariant.nested` strip.
- **Nested summary chips:** the `_ClaimsSummaryBar` `ActionChip` row under Authorizations / Active Claims that applies `ClaimsQueueFilter` while leaving the parent tab selected.
- **Authorization-scoped tabs:** independent tabs whose default filter is an authorization queue (`authorizationPending`, `authorizationApproved`, and any promoted denied/expired sibling).
- **Claim-scoped tabs:** independent tabs whose default filter is an active-claim queue (`claimSubmitted`, `claimApproved`, `claimPartial`, `claimRejected`).
- **Applied query:** the committed search text, Advanced filters, active independent tab/scope, and sort that already drive the table and tab counts.

## Requirements

1. **Replace parent Authorizations and Active Claims tabs with independent tabs.** Remove `ClaimsDeskSection.authorizations` and `ClaimsDeskSection.activeClaims` as strip items. Mount one independent tab per nested chip in the table above, in this order, then Settled, then Insurance Setup:
   1. Auth pending
   2. Auth approved
   3. Submitted
   4. Approved
   5. Partial claims
   6. Claim rejected
   7. Settled
   8. Insurance Setup  
   Reuse existing short labels (`claimsAuthorizationPendingSummaryLabel`, `claimsAuthorizationApprovedSummaryLabel`, `claimsSubmittedSummaryLabel`, `claimsApprovedSummaryLabel`, `claimsPartialSummaryLabel`, `claimsFilterClaimRejected`, `claimsSectionSettled`, `claimsSectionInsuranceSetup`). Do not keep a parent “Authorizations” or “Active Claims” tab.

2. **Remove nested summary chips.** Delete `_ClaimsSummaryBar` (and any equivalent chip/wrap row). Do not replace it with `AppTabStripVariant.nested`, a second strip, or status chips above the table. Queue scope changes only through the primary strip (and in-tab Advanced filters that do not switch sibling-tab membership).

3. **Do not orphan authorization denied / expired.** Those statuses exist as nested chips when the loaded page has matching rows, and as Advanced-filter choices under Authorizations. After the nested bar is gone, promote them to independent tabs **immediately after Auth approved**, using existing labels `claimsFilterAuthorizationDenied` and `claimsFilterAuthorizationExpired`. Always show them. If the workspace summary has no dedicated total, badge **0**—do not use loaded-page `items.length`. Selecting the tab still applies `ClaimsQueueFilter.authorizationDenied` / `authorizationExpired` to `listQueue`.

4. **Each independent tab owns one default `ClaimsQueueFilter`.** Selecting a tab loads that filter’s queue (same `applyFilter` / `listQueue` path as today) and must not leave the previous tab’s rows visible. Default filters:
   - Auth pending → `authorizationPending`
   - Auth approved → `authorizationApproved`
   - Authorization denied → `authorizationDenied`
   - Authorization expired → `authorizationExpired`
   - Submitted → `claimSubmitted`
   - Approved → `claimApproved`
   - Partial claims → `claimPartial`
   - Claim rejected → `claimRejected`
   - Settled → `claimPaid` (unchanged)
   - Insurance Setup → catalog panel (unchanged; no queue table)

5. **Counts on every countable tab.** Each queue tab shows its dedicated workspace-summary total for that scope, selected or not. Insurance Setup still omits count (`null`). Active tab with search / Advanced filters that narrow the applied query uses `queue.totalItemCount` for that same query. Sibling tabs keep their unfiltered summary totals. Do not badge `items.length` or the visible page size. Count tones: authorization-scoped and claim-scoped tabs keep `AppTabCountTone.warning`; Settled keeps `info`.

6. **URL / deep-link `section` stays in-desk.** Sync with `syncWorkspaceLocation` on the same claims path. Introduce leaf query values (kebab-case) for the new tabs, for example `auth-pending`, `auth-approved`, `auth-denied`, `auth-expired`, `submitted`, `approved`, `partial-claims`, `claim-rejected`. Keep `settled` and `insurance-setup`. Map legacy `authorizations` → Auth pending and `active-claims` → Submitted so existing links still open a valid tab. Unauthorized or unknown `section` still falls back to the first allowed tab.

7. **Move create actions onto the search bar after Print.** Remove `AppTabStrip.primaryAction` for Request authorization and Prepare claim. Pass them as `AppListTableSearch.trailingActions` (`AppSearchBarAction`) so shared table chrome places them after Filters → Settings → Export → Print. Pattern: Billing `_billingTrailingSearchActions`.
   - **Request authorization** (`claimsRequestAuthorizationAction`) on every authorization-scoped queue tab when `ClaimsAuthorizationsAtomPermissions.requestAuthorization` is allowed.
   - **Prepare claim** (`claimsPrepareClaimAction`) on every claim-scoped queue tab when `ClaimsActiveClaimsAtomPermissions.prepare` is allowed.
   - Omit both on Settled and Insurance Setup.
   - Omit the action (do not render a disabled control) when the matching write requirement is false.
   - Existing request / prepare dialogs, validation, snackbars, and queue sync stay; only the trigger moves.

8. **Advanced filters must not impersonate sibling tabs.** Remove the queue-status `filterGroups` choices that are now independent tabs (pending/approved/denied/expired on auth tabs; submitted/approved/partial/rejected on claim tabs). Search and any remaining non-status filters stay. Settled may keep Paid / Cancelled as in-tab Advanced filters because Settled is not being split. Applying filters refreshes the active tab’s table and that tab’s filtered count; it must not silently select a different strip tab. Opening Advanced filters shows the committed in-tab filter model.

9. **Reuse queue chrome per kind.** Authorization-scoped tabs keep the current Authorizations column set, next-action, detail dialog, Export/Print helpers, and list-chrome permission. Claim-scoped tabs keep the current Active Claims column set and helpers. Settled and Insurance Setup bodies stay as they are. Do not restyle tables or invent a second scroller.

10. **Permissions.** Reuse existing `claimsDeskSectionRequirement` / atom maps: authorization-scoped tabs use Authorizations read ∩; claim-scoped tabs use Active Claims read ∩; Settled and Insurance Setup gates unchanged. Omit unauthorized tabs and actions. Do not render disabled unauthorized Request authorization / Prepare claim. Update `ClaimsDeskSection` (or equivalent leaf ids) and `claimsDeskSectionFromQuery` / `claimsDeskSectionToQuery` so every new tab has a gate.

11. **States.** Cover loading, empty, error, and success for tab switch, search submit, filter apply, Request authorization, and Prepare claim. While `state.isSaving`, disable the moved search-bar create action (loading on that control is fine). After a successful create or status mutation, refresh the table and **all visible tab counts**. Do not leave a silent stale table when a tab or filter request fails.

12. **Insurance Setup unchanged.** Leave the Insurance Setup tab, panel copy, and six panel actions in place. Do not move those actions onto a search bar.

## Constraints

- Reuse `AppTabStrip` / `AppTabItem`, `AppListTable` / `AppListTableSearch` / `AppSearchBarAction`, `claimsWorkspaceControllerProvider` (`applyFilter`, `applySearch`, `changePage`), existing request/prepare dialogs, `claims_scope_navigation.dart` count helpers, and `claims_access.dart` requirements. Prefer extending `ClaimsDeskSection` over a parallel navigator.
- Do not use `AppTabStripVariant.nested` for these queues. Do not keep `_ClaimsSummaryBar`.
- Do not change toolbar order, Export/Print labels, print preview, or default visible columns.
- Do not add backend aggregator fields or new list endpoints unless a denied/expired summary total is already returned; badge 0 until then.
- Do not bypass RBAC/ABAC. Backend remains authoritative.
- Localization, theming, and responsiveness: [localization.mdc](/.cursor/localization.mdc), [theming.mdc](/.cursor/theming.mdc), [responsiveness.mdc](/.cursor/responsiveness.mdc). Add l10n keys only if a new user-facing string is required; prefer the existing chip/section/action keys listed above.
- Dialogs and forms for request/prepare: [dialogs.mdc](/.cursor/dialogs.mdc), [forms.mdc](/.cursor/forms.mdc). Print: [printing.mdc](/.cursor/printing.mdc).
- Out of scope: Insurance Setup catalog work, Settled settlement UX, changing next-action workflows, export/print matching-dataset behavior, and unrelated workspace refactors.

## Optional enhancements

- Dedicated workspace-summary totals for authorization denied and expired (so those badges are authoritative rather than 0).
- Overflow-friendly short labels if the strip’s more-menu is the only way to reach later tabs on compact widths (shared strip overflow already exists—do not fork a custom more-menu).

These are optional. Requirements 1–12 are mandatory.

## Acceptance Criteria

1. **R1.** The primary strip shows Auth pending, Auth approved, Authorization denied, Authorization expired, Submitted, Approved, Partial claims, Claim rejected, Settled, and Insurance Setup (when each is allowed). It does not show parent tabs labeled Authorizations or Active Claims.

2. **R2.** `_ClaimsSummaryBar` / Auth pending (and sibling) `ActionChip`s are absent. Tapping Auth pending on the strip loads `authorizationPending`; tapping Submitted loads `claimSubmitted`; the table rows match that filter.

3. **R3.** Authorization denied and Authorization expired are always present as strip tabs (when the operator can view authorization-scoped tabs). Their badges are summary totals or 0, never the loaded-page length.

4. **R4.** Selecting Approved (claim) after Auth pending replaces authorization rows with `claimApproved` rows and updates `?section=` to the claim-approved leaf. The previous tab’s rows are gone.

5. **R5.** With unfiltered queries, Auth pending’s badge equals `authorizationPendingCount`, Submitted’s badge equals `submittedClaimsCount`, and Settled’s badge equals `paidClosedCount`, including on inactive tabs. Insurance Setup has no count. After search that yields M matching rows on the active tab, that tab’s badge is M (`totalItemCount`), and sibling badges stay at their unfiltered summary totals.

6. **R6.** Opening `/claims?section=authorizations` selects Auth pending. Opening `/claims?section=active-claims` selects Submitted. Opening a new leaf value selects that tab. Changing tabs updates the query without leaving the claims route.

7. **R7.** On Auth pending (write allowed), Request authorization is in the table search trailing cluster after Print (desktop) and is absent from `AppTabStrip.primaryAction`. On Submitted (write allowed), Prepare claim is in that same trailing cluster. Settled and Insurance Setup show neither. With write denied, both actions are absent (not disabled). Tapping the moved action still opens the existing dialog.

8. **R8.** Advanced filters on Auth pending do not list Auth approved / Submitted / other sibling-tab statuses as a way to change scope. Settled still allows Paid / Cancelled in-tab. Apply/clear refreshes the active table and that tab’s filtered count.

9. **R9.** Authorization-scoped tabs still use the Authorizations column set and next-action behavior. Claim-scoped tabs still use the Active Claims column set. Settled columns and Insurance Setup panel are unchanged.

10. **R10.** An operator without Active Claims read does not see Submitted / Approved / Partial claims / Claim rejected. An operator without Insurance Setup read does not see that tab. Request authorization / Prepare claim remain absent without write ∩.

11. **R11.** Tab switch while the queue is loading shows the existing loading path. Empty scope shows the existing empty queue copy. A failed filter/search surfaces the existing error path and does not keep the previous tab’s rows under the new label. Successful Request authorization / Prepare claim still snackbar and refresh queue plus tab counts.

12. **R12.** Insurance Setup still shows its six panel actions and does not gain a queue search bar or Request authorization / Prepare claim.

13. **Verification.** Update `frontend/test/features/claims/presentation/claims_workspace_page_test.dart` so the strip lists the independent tabs, nested summary chips are absent, legacy `section=authorizations` / `active-claims` map correctly, and Request authorization / Prepare claim are found via search-bar trailing tooltips rather than the tab strip. Update `claims_scope_navigation_test.dart` for per-tab counts (sibling summary vs active filtered `totalItemCount`). Update `claims_authorizations_permissions_test.dart` and `claims_active_claims_permissions_test.dart` so unauthorized create actions are absent and authorized ones remain on the relevant independent tabs; keep Settled / Insurance Setup tests that assert those creates stay absent. Manually check light and dark at a compact phone width and a desktop width: overflow tabs remain reachable, create actions sit after Print on desktop, and Insurance Setup is unchanged.

## Relevant Files

- `frontend/lib/features/claims/presentation/pages/claims_workspace_page.dart`
- `frontend/lib/features/claims/presentation/widgets/claims_scope_navigation.dart`
- `frontend/lib/features/claims/presentation/controllers/claims_workspace_controller.dart`
- `frontend/lib/features/claims/presentation/claims_access.dart`
- `frontend/lib/features/claims/domain/entities/claims_entities.dart` (`ClaimsDeskSection`, `claimsDeskSectionFromQuery`, `claimsDeskSectionToQuery`)
- `frontend/lib/l10n/app_en.arb`
- `frontend/lib/shared/components/app_tab_strip.dart`
- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/lib/shared/components/app_search_bar.dart`
- `frontend/lib/shared/routing/workspace_location_sync.dart`
- `frontend/test/features/claims/presentation/claims_workspace_page_test.dart`
- `frontend/test/features/claims/presentation/claims_scope_navigation_test.dart`
- `frontend/test/features/claims/presentation/claims_authorizations_permissions_test.dart`
- `frontend/test/features/claims/presentation/claims_active_claims_permissions_test.dart`
- `frontend/test/features/claims/presentation/claims_settled_permissions_test.dart`
- `frontend/test/features/claims/presentation/claims_insurance_setup_permissions_test.dart`
- `frontend/test/features/claims/domain/claims_entities_test.dart`
