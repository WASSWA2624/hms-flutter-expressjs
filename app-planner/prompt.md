You are working on the HOSSPI HMS codebase.

Project structure:
- app-planner/
- backend/
- frontend/

No OPD screenshots were included in the archive. Use the actual Flutter UI implementation as the source of truth for layout and interaction details.

Your task is to perform a complete OPD module UI + backend functionality test, fix every failure found, and leave the OPD workflow fully functional end-to-end.

Test accounts:
Use the same password for all accounts: Hosspi@2624

Accounts:
- super.admin@hosspi.com
- tenant.admin@hosspi.com
- facility.admin@hosspi.com
- doctor@hosspi.com
- nurse@hosspi.com
- lab@hosspi.com
- pharmacy@hosspi.com
- reception@hosspi.com
- billing@hosspi.com
- operations@hosspi.com
- hr@hosspi.com
- biomed@hosspi.com
- housekeeping@hosspi.com
- ambulance@hosspi.com
- patient.portal@hosspi.com

Important:
- Use these credentials only in the local/test environment.
- Do not commit credentials, logs containing credentials, or generated secrets.

Main objective:
Fully test and repair the OPD module so that every visible action, nested dialog, workflow transition, database update, and cross-module effect works correctly from both frontend and backend.

This is not only a code review. You must run the application, interact with the UI, perform real OPD workflows, verify backend persistence, and confirm that related UI areas update correctly.

Technology and architecture constraints:

Backend:
- Node.js / Express / Prisma / MySQL.
- CommonJS only.
- Follow the existing backend architecture:
  Route → Controller → Service → Repository → Prisma.
- APIs must stay under `/api/v1`.
- Use existing response helpers, error handling, auth middleware, permission checks, and Zod validation style.
- Do not bypass service/repository layers.
- Add Prisma migrations when schema/database changes are required.

Frontend:
- Flutter app.
- Follow the existing feature-first structure.
- Use the existing Riverpod, GoRouter, Dio, repository, controller, DTO, entity, and shared component patterns.
- Preserve existing design system components such as `AppWorkspace`, `AppListTable`, dialogs, summary cards, filters, and responsive layouts.
- Do not replace the OPD UI with an unrelated implementation.
- Fix the current implementation in place.

Do not modify `app-planner/` unless a file there is directly required for runtime behavior. Prefer backend/frontend changes only.

Key OPD frontend files to inspect:
- `frontend/lib/features/opd/data/dtos/opd_dtos.dart`
- `frontend/lib/features/opd/data/repositories/opd_repository_impl.dart`
- `frontend/lib/features/opd/domain/entities/opd_entities.dart`
- `frontend/lib/features/opd/domain/repositories/opd_repository.dart`
- `frontend/lib/features/opd/presentation/controllers/opd_workspace_controller.dart`
- `frontend/lib/features/opd/presentation/pages/opd_workspace_page.dart`
- `frontend/lib/shared/components/opd_encounter_dialog.dart`
- `frontend/lib/shared/opd_actions/opd_action_context.dart`
- `frontend/lib/shared/opd_actions/opd_billing_state.dart`
- `frontend/lib/shared/opd_actions/opd_flow_actions_dialog.dart`
- `frontend/lib/shared/clinical_actions/clinical_order_action_dialogs.dart`

Key backend modules to inspect:
- `backend/src/modules/opd-flow`
- `backend/src/modules/triage`
- `backend/src/modules/encounter`
- `backend/src/modules/vital-sign`
- `backend/src/modules/lab-order`
- `backend/src/modules/lab-order-item`
- `backend/src/modules/radiology-order`
- `backend/src/modules/pharmacy-order`
- `backend/src/modules/pharmacy-order-item`
- `backend/src/modules/procedure`
- `backend/src/modules/referral`
- `backend/src/modules/follow-up`
- `backend/src/modules/billing`
- `backend/src/modules/admission`
- `backend/prisma/schema.prisma`

OPD route:
- The Flutter OPD page is routed at `/opd`.
- Confirm route protection, role access, permissions, redirects, and module activation behavior.

Core OPD UI areas to test:

1. OPD workspace loading
- Login with relevant staff accounts.
- Open `/opd`.
- Confirm the workspace loads without crashes, blank states, infinite loaders, or permission errors for allowed roles.
- Confirm denied roles cannot access OPD if the app is designed to block them.

2. OPD summary cards
Test all summary cards:
- All records
- Arrivals
- Queue
- Triage
- Active flow

Verify:
- Counts are correct.
- Zero-value cards behave as intended.
- Clicking each card filters the main OPD table correctly.
- Clearing filters restores all records.
- Counts update after actions such as check-in, queueing, triage, payment, vitals, doctor assignment, review, discharge, and refresh.

3. OPD main table
Test:
- Search.
- Advanced filters.
- Category filters.
- Status filters.
- Column visibility.
- Sorting if available.
- Pagination or scrolling if available.
- Empty states.
- Loading states.
- Error states.
- Refresh action.
- Responsive behavior on desktop and narrow widths.

Every row type must open the correct action dialog:
- Appointment rows → appointment actions dialog.
- Queue rows → queue actions dialog.
- Active OPD flow rows → flow actions dialog.
- Triage rows → correct triage/flow dialog behavior.

4. Start walk-in flow
Test the “Start walk-in” primary action.

Verify:
- New patient creation if supported.
- Existing patient selection if supported.
- Required field validation.
- Duplicate patient prevention.
- Encounter creation.
- Queue creation/update.
- Appointment linkage if applicable.
- Correct initial OPD stage.
- Correct UI refresh after creation.
- No duplicated active OPD encounters for the same patient.

5. Appointment actions
For appointment rows, test every action:
- Queue appointment.
- Reschedule appointment.
- Cancel appointment.
- Check in / start OPD encounter.

Verify:
- Dialogs open correctly.
- Required validations work.
- Backend calls succeed.
- Appointment status updates correctly.
- OPD table updates correctly.
- Duplicate queue or encounter records are not created.
- Cancelled appointments cannot incorrectly continue into active OPD flow unless explicitly allowed.

6. Queue actions
For queue rows, test every action:
- Prioritize.
- Move queue.
- Start consultation.

Verify:
- Queue status changes correctly.
- Priority changes persist.
- Department/service movement persists.
- Starting consultation creates or reuses the correct OPD encounter.
- UI updates immediately after each action.
- Backend prevents duplicate active encounters.

7. OPD flow actions
For every active OPD patient, open the flow actions dialog and test every visible action and every nested dialog.

Test at minimum:
- Consultation payment.
- Record vitals.
- Edit/update vitals.
- Assign doctor.
- Change doctor.
- Doctor review.
- Add diagnosis.
- Add procedure.
- Request lab tests.
- Request radiology tests.
- Prescribe medication.
- Create referral.
- Create follow-up.
- Correct stage.
- Disposition.
- Print OPD summary.

For each action:
- Confirm the button is visible only when appropriate.
- Confirm disabled states are correct.
- Open the dialog.
- Test required validation.
- Submit valid data.
- Confirm success feedback.
- Confirm errors display clearly when backend rejects the request.
- Confirm database state changes.
- Confirm OPD UI refreshes.
- Confirm related modules reflect the change.

8. Consultation payment
Test:
- Payment required flow.
- Payment not required flow if supported.
- Cash/mobile money/insurance/other available methods.
- Invoice creation/update.
- Payment status.
- Partial/invalid payment handling if supported.
- Transition from `WAITING_CONSULTATION_PAYMENT` to `WAITING_VITALS`.

Verify Billing module reflects the invoice/payment correctly.

9. Vitals
Test:
- Recording vitals.
- Updating existing vitals.
- Required fields.
- Numeric validation.
- Clinical alert thresholds if implemented.
- Stage transition to doctor assignment.

Verify:
- Vitals persist.
- Updated vitals replace or update the correct record.
- No duplicate vitals are created when update behavior is intended.
- Vitals are visible anywhere else they should appear.

10. Doctor assignment
Test:
- Provider list loading.
- Assigning doctor.
- Changing assigned doctor.
- Invalid provider handling.
- Stage transition to doctor review.

Verify:
- Assigned doctor appears correctly in OPD UI.
- Doctor account can see or act on the assigned patient if role-based filtering exists.

11. Doctor review
Test full doctor review:
- Notes.
- Diagnosis.
- Procedures.
- Lab orders.
- Radiology orders.
- Medication prescriptions.
- Review completion.
- Stage transition logic.

Verify:
- Lab-only review moves to lab-requested stage.
- Radiology-only review moves to radiology-requested stage.
- Lab + radiology review moves to combined lab/radiology stage.
- Prescription review moves to pharmacy-requested stage.
- No-order review moves to waiting disposition.
- Review completion is persisted.
- Cross-module records are created correctly.

12. Lab requests
Test:
- Creating lab orders from OPD.
- Adding lab order items.
- Updating existing lab orders if the UI exposes update.
- Required fields.
- Duplicate prevention.
- Correct patient/encounter linkage.

Important known area to inspect:
In `frontend/lib/shared/opd_actions/opd_flow_actions_dialog.dart`, the OPD lab-order update callback may currently return a validation failure placeholder. If existing lab-order update is exposed in the UI, implement it properly through the repository/backend.

Verify:
- Lab orders appear in the Lab module.
- Lab status changes are reflected back where expected.
- OPD stage and badges remain consistent.

13. Radiology requests
Test:
- Creating radiology orders from OPD.
- Required fields.
- Correct patient/encounter linkage.
- Cross-module visibility in Radiology.

Verify:
- Radiology orders appear in the Radiology module.
- Status changes are reflected where expected.

14. Prescriptions / pharmacy
Test:
- Creating prescriptions from OPD.
- Medication search/list loading.
- Quantity, dosage, frequency, duration validation.
- Duplicate medication handling if applicable.
- Pharmacy order creation.

Verify:
- Pharmacy module receives the order.
- OPD patient stage/status reflects pharmacy request.
- Disposition to pharmacy works only with valid pharmacy order linkage.

15. Procedures
Test:
- Adding procedures.
- Required fields.
- Procedure persistence.
- Billing linkage if procedure billing is expected.
- Correct encounter linkage.

16. Referrals and follow-ups
Test:
- Creating referral.
- Creating follow-up.
- Required field validation.
- Date/time validation.
- Provider/facility linkage.
- Cross-module or patient-record visibility.

17. Correct stage
Test correcting the OPD workflow stage to each allowed stage:
- `WAITING_CONSULTATION_PAYMENT`
- `WAITING_VITALS`
- `WAITING_DOCTOR_ASSIGNMENT`
- `WAITING_DOCTOR_REVIEW`
- `LAB_REQUESTED`
- `RADIOLOGY_REQUESTED`
- `LAB_AND_RADIOLOGY_REQUESTED`
- `PHARMACY_REQUESTED`
- `WAITING_DISPOSITION`
- `ADMITTED`
- `DISCHARGED`

Verify:
- Invalid transitions are blocked if business rules require blocking.
- Terminal stages close encounters correctly.
- Queue and appointment statuses update correctly.
- UI reflects corrected stage everywhere.

18. Disposition
Test:
- Admit.
- Send to pharmacy.
- Discharge.

Verify:
- Admit creates admission/IPD record.
- Send to pharmacy requires a valid pharmacy order.
- Discharge closes the encounter.
- Closed encounters no longer appear as active OPD encounters.
- Patient history remains accessible.

19. Print OPD summary
Test:
- Print dialog opens.
- Summary content contains correct patient, encounter, vitals, doctor review, diagnosis, orders, prescriptions, procedures, referral/follow-up, and disposition details.
- Print/export action does not crash.
- Empty sections render cleanly.

20. Duplicate active encounter prevention
This is critical.

Find and fix cases where the same patient can have more than one active OPD encounter at the same time.

Test duplicate attempts from:
- Start walk-in.
- Appointment check-in.
- Queue start consultation.
- Triage routing.
- Browser refresh/retry.
- Double-clicking submit buttons.
- Two roles acting on the same patient.
- Direct backend API calls.

Required behavior:
- A patient must not have more than one active OPD encounter at the same facility/tenant at the same time.
- If an active encounter exists, the system should either reuse it intentionally or reject the duplicate with a clear error.
- UI must show a clear message instead of creating duplicates.
- Backend must enforce this rule, not only the frontend.

Implementation requirement:
- Inspect existing duplicate active encounters in the database.
- Add cleanup/backfill logic if needed.
- Add a transaction-safe backend guard.
- Add a database-level uniqueness constraint or equivalent durable protection where feasible with MySQL/Prisma.
- Add tests proving duplicates cannot be created under normal and repeated requests.

21. Cross-module consistency
After each OPD action, verify affected modules:
- Billing
- Lab
- Radiology
- Pharmacy
- Patients
- Admissions/IPD
- Referrals
- Follow-ups
- Triage
- Visit queues
- Appointments

For every created or updated record:
- Confirm the backend database row is correct.
- Confirm the OPD UI reflects the change.
- Confirm the target module reflects the change.
- Confirm refresh/reload still shows correct data.

22. Error handling and UX
Fix:
- Buttons that do nothing.
- Dialogs that open but cannot submit.
- Silent failures.
- Incorrect success messages.
- Incorrect loading states.
- Duplicate submissions.
- Stale UI after mutation.
- Missing refresh after mutation.
- Crashes caused by null/empty data.
- Bad validation messages.
- Overflow, clipped buttons, broken scrolling, or unusable layouts.
- Broken responsive behavior.

23. Testing requirements
Add or update tests where needed.

Backend:
Run and keep passing:
- `npm run test:backend`
- `npm run test:backend:unit`
- `npm run test:backend:integration`
- `npm run openapi:validate`
- `npm run validate`

Frontend:
Run and keep passing:
- `flutter pub get`
- `dart run build_runner build --delete-conflicting-outputs`
- `dart format --set-exit-if-changed .`
- `flutter analyze`
- `flutter test`
- `flutter test integration_test`

Add focused tests for:
- OPD duplicate active encounter prevention.
- Start walk-in.
- Appointment check-in.
- Queue start consultation.
- Payment.
- Vitals.
- Doctor assignment.
- Doctor review with lab/radiology/pharmacy/procedure orders.
- Disposition.
- Correct stage.
- Cross-module order creation.
- OPD controller refresh/state updates.
- Any fixed regression.

24. Manual UI test requirement
Run the app locally and manually test the OPD module in the browser.

Recommended frontend run command:
`flutter run -d chrome --web-hostname=127.0.0.1 --web-port=5201 --dart-define-from-file=env/development.json.example`

Open:
`http://127.0.0.1:5201`

Manually test OPD with multiple roles, especially:
- super admin
- tenant admin
- facility admin
- receptionist
- nurse
- doctor
- lab
- radiology-related user if available
- pharmacy
- billing
- patient portal where relevant

25. Deliverables
When finished, provide:

1. Summary of what was tested.
2. Accounts/roles tested.
3. OPD workflows tested.
4. Bugs found.
5. Bugs fixed.
6. Backend files changed.
7. Frontend files changed.
8. Prisma migrations added, if any.
9. Tests added/updated.
10. Commands run and results.
11. Any remaining limitations or manual follow-up needed.

Acceptance criteria:
- OPD opens correctly.
- Every visible OPD button works or is intentionally disabled with a clear reason.
- Every OPD dialog can be opened, validated, submitted, cancelled, and reopened.
- Every OPD workflow stage behaves correctly.
- Backend and frontend stay synchronized.
- Cross-module effects are visible in the correct modules.
- No duplicate active OPD encounters can be created for one patient at the same time.
- All relevant tests pass.
- No credentials are committed.
- No frontend-only fake success behavior is left behind.
- No unresolved placeholder callbacks remain in OPD actions.