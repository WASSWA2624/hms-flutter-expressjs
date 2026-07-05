# Fix lab order creation and catalog visibility for non–super-admin users

## Problem

Creating a lab order works when signed in as **super admin**, but fails for other clinical roles (e.g. doctor, nurse, facility admin, lab tech). In some sessions, the lab order dialog also shows **no tests or panels** in the catalog picker.

The root cause is unknown — it may be authentication, role/permission checks, tenant/facility scoping, module entitlements, or catalog resolution — but behavior must be consistent for all authorized users.

## Expected behavior

Any user with permission to request lab work should be able to:

1. Open the lab order flow from clinical workspaces (OPD, IPD, nursing, patient quick actions, etc.).
2. Search and select lab tests and panels offered at their facility.
3. Submit a lab order successfully and see the created order in the workspace.

Super admin should not be the only role that can complete this flow.

## Scope

Investigate and fix end-to-end across frontend and backend:

| Layer | Likely touchpoints |
|-------|-------------------|
| **Frontend** | `ClinicalLabOrderActionDialog`, `clinical_lab_request_catalog_dialog.dart`, workspace action handlers (`clinical_workspace_page.dart`, `opd_flow_actions_dialog.dart`, `patient_clinical_quick_actions.dart`) |
| **Backend** | `POST /api/v1/lab-orders`, `GET /api/v1/facility-lab-catalog/search`, lab test/panel list endpoints, `resolveRequestedLabOrderItems` in `lab-order.service.js` |
| **Auth** | `authenticate` / `authorize` middleware, `PERMISSIONS.CLINICAL_READ`, role lists on lab routes, `lab-workflows` module entitlement |

## Investigation checklist

1. Reproduce with a **non–super-admin** account (doctor or nurse) and capture the failing API response (status, error key, payload).
2. Compare the same request as super admin vs. the failing role — note differences in tenant, facility, permissions, and headers.
3. Verify catalog search: confirm `facility-lab-catalog/search` returns results for the user’s facility and that the UI calls it with the correct `termType`, `source`, and facility context.
4. Verify order creation: confirm selected test/panel IDs resolve under `resolveRequestedLabOrderItems` for the patient’s tenant (empty resolution currently throws).
5. Check whether missing `clinical:read` permission, `lab-workflows` entitlement, or facility-scoped catalog configuration explains empty catalogs or 403/401 responses.
6. Ensure error messages surfaced in the UI reflect the real backend failure (not a generic or silent failure).

## Acceptance criteria

- [ ] Doctor, nurse, facility admin, and lab tech can create a lab order for a patient in their tenant/facility.
- [ ] Lab tests and panels configured for the facility appear in the order dialog catalog for those roles.
- [ ] Failures show a clear, actionable error when prerequisites are missing (e.g. no catalog offerings, no permission).
- [ ] Existing super-admin behavior is unchanged.
- [ ] Add or update tests covering non–super-admin lab order creation and catalog search where gaps exist.

## Out of scope

- Redesigning the lab order UI.
- Changing which roles may request lab work unless current route/permission definitions are incorrect.
