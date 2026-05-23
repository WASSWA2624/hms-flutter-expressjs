# Implementation Prompt: HMS Real-Time CRUD UI Synchronization Fix

## Goal

Fix inconsistent real-time UI updates in the Hospital Management System.

The app already has WebSocket support. Do **not** add a new real-time system and do **not** replace the existing architecture.

The problem is that backend CRUD mutations are not consistently emitted as domain events, and the Flutter frontend does not consistently invalidate or refresh affected Riverpod state when those events arrive.

Implement a focused fix so that when users create, update, delete, reconcile, queue, or process important HMS records, the UI updates immediately and consistently across relevant screens, tabs, devices, and users.

---

## Existing architecture to preserve

Preserve the existing project structure and coding style.

### Backend

The backend uses:

* Express
* Prisma
* CommonJS modules
* `ws` WebSocket server
* Layered structure:

```txt
route -> controller -> service -> repository -> prisma
```

Respect the existing backend rules:

* Services own business logic, workflow, audit, and event publishing decisions.
* Repositories own Prisma/database access.
* Do not move Prisma queries into controllers or shared websocket helpers.
* Do not put business logic in the WebSocket gateway.
* Keep WebSocket payloads stable and use `snake_case` field names.

Relevant backend files to inspect and update where required:

```txt
backend/src/server.js
backend/src/websockets/server.js
backend/src/websockets/gateway.js

backend/src/lib/websocket/events.js
backend/src/lib/websocket/emit.js
backend/src/lib/websocket/index.js

backend/src/modules/patient/services/patient.service.js
backend/src/modules/encounter/services/encounter.service.js
backend/src/modules/payment/services/payment.service.js
backend/src/modules/visit-queue/services/visit-queue.service.js
backend/src/modules/billing/services/billing.service.js

backend/src/modules/billing/repositories/billing.repository.js
```

Also inspect related tests under:

```txt
backend/src/tests/
```

especially existing websocket and module service tests.

### Frontend

The frontend uses:

* Flutter
* Riverpod
* Dio
* `web_socket_channel`
* Feature-first clean architecture

Respect the existing frontend rules:

* UI widgets must not own HTTP or business workflow logic.
* Repositories handle API calls and DTO/domain mapping.
* Controllers own presentation state.
* Providers should stay close to their owning feature unless truly shared.
* `core` must remain generic and must not contain feature-specific business rules.
* Use existing shared UI/theme patterns.
* Do not redesign screens.

Relevant frontend files to inspect and update where required:

```txt
frontend/lib/core/realtime/realtime_events.dart
frontend/lib/core/realtime/realtime_event_groups.dart
frontend/lib/core/realtime/realtime_message.dart
frontend/lib/core/realtime/realtime_service.dart
frontend/lib/core/realtime/realtime_providers.dart
frontend/lib/core/realtime/realtime_refresh.dart

frontend/lib/features/patients/presentation/controllers/patient_registry_controller.dart

frontend/lib/features/opd/presentation/controllers/opd_workspace_controller.dart

frontend/lib/features/billing/domain/repositories/billing_repository.dart
frontend/lib/features/billing/data/repositories/billing_repository_impl.dart
frontend/lib/features/billing/presentation/controllers/billing_workspace_controller.dart
```

Also inspect related frontend tests under:

```txt
frontend/test/
```

especially realtime, patient registry, OPD workspace, and billing workspace tests.

### App planner files

Use the rules in these files as project constraints:

```txt
app-planner/
backend/app-planner/app-rules/
frontend/app-planner/app-rules/
```

Do not modify `app-planner` files unless absolutely required.

---

## Screenshot/UI note

No task-specific screenshots are available to the coding agent. Therefore, preserve the existing UI exactly unless a functional state-update change requires a minimal adjustment.

Written UI/UX requirements:

1. After a successful create/update/delete/reconcile/payment/queue action, the user must see the latest state without manual refresh or navigating away.
2. Avoid full-screen flicker or unnecessary full reloads after small actions.
3. Keep existing loading/saving indicators such as `isSaving`, `isRefreshing`, and existing button/modal behavior.
4. Prefer immediate server-confirmed state patching when the API returns useful data.
5. Use WebSocket events to synchronize other visible screens, other browser tabs, other devices, and other users.
6. Existing polling may remain only as a slow fallback. Do not add new polling as the primary solution.
7. The experience should feel like a messaging app: after an action succeeds, the UI should quickly show the new/updated item.

---

## Main implementation requirements

## 1. Backend: add missing domain events

Extend the existing backend websocket event constants in:

```txt
backend/src/lib/websocket/events.js
```

Add missing resource-level events while preserving all existing event names.

Required new events:

```js
patient.created
patient.updated
patient.deleted

encounter.created
encounter.updated
encounter.deleted

visit_queue.created
visit_queue.updated
visit_queue.deleted
visit_queue.position_changed

payment.created
payment.updated
payment.deleted
payment.reconciled

invoice.updated
billing.balance_updated
```

Keep existing compatibility events such as:

```js
billing.invoice_issued
billing.payment_received
billing.refund_processed
opd.flow.updated
ipd.flow.updated
visit_queue.triage_updated
```

Do not remove or rename existing events that the frontend may already consume.

---

## 2. Backend: add or formalize a shared domain event publisher

Create or extend a shared publisher under:

```txt
backend/src/lib/websocket/
```

Suggested export:

```js
publishDomainEvent({
  event,
  tenant_id,
  facility_id,
  actor_user_id,
  resource_type,
  resource_id,
  affected,
  payload,
  recipient_user_ids,
});
```

Requirements:

1. The publisher must use existing websocket emit helpers.
2. The publisher must not query Prisma directly.
3. Recipient lookup must remain in services/repositories.
4. Payloads must use stable `snake_case` fields.
5. Every event should include:

   * `event`
   * `tenant_id`
   * `facility_id`
   * `actor_user_id`
   * `resource_type`
   * `resource_id`
   * `affected`
   * `payload`
   * `occurred_at`
6. Realtime delivery failure must not break successful CRUD API responses.
7. Log websocket publish failures using the existing backend logger pattern.
8. Do not send large raw Prisma objects unless already established by existing patterns. Prefer IDs, public IDs, statuses, amounts, timestamps, and affected resource references.

Example payload shape:

```js
{
  event: "payment.reconciled",
  tenant_id,
  facility_id,
  actor_user_id,
  resource_type: "payment",
  resource_id: payment.id,
  affected: {
    payment_id: payment.id,
    invoice_id,
    patient_id,
    encounter_id
  },
  payload: {
    payment_id: payment.id,
    payment_public_id,
    invoice_id,
    invoice_public_id,
    patient_id,
    encounter_id,
    status,
    amount,
    occurred_at
  },
  occurred_at
}
```

---

## 3. Backend: support multiple WebSocket connections per user

Update:

```txt
backend/src/websockets/gateway.js
```

The current gateway stores one socket per user. Change this to support multiple active sockets per user.

Target concept:

```js
Map<UserId, Set<WebSocket>>
```

Requirements:

1. The same user can open multiple tabs/devices without disconnecting older sockets.
2. `sendToUser(userId, event, payload)` must send to all active sockets for that user.
3. `broadcast(event, payload, excludeUserIds)` must handle multiple sockets per user.
4. Closing one socket must not disconnect other sockets for the same user.
5. Cleanup must remove stale socket references safely.
6. `getConnectedUsers()` should still return unique user IDs.
7. Update gateway tests to cover multiple sockets for the same user.

Do not change the public gateway API more than necessary.

---

## 4. Backend: emit events after successful mutations

Emit domain events after successful database writes in the relevant services.

Update only the required mutation paths.

### Patient service

File:

```txt
backend/src/modules/patient/services/patient.service.js
```

Emit:

```js
patient.created
patient.updated
patient.deleted
```

Required payload fields where available:

```js
patient_id
patient_public_id
tenant_id
facility_id
status or is_active
actor_user_id
occurred_at
affected: { patient_id }
target_path, if existing navigation patterns support it
```

For delete operations, use the pre-delete record to include affected IDs.

### Encounter service

File:

```txt
backend/src/modules/encounter/services/encounter.service.js
```

Emit:

```js
encounter.created
encounter.updated
encounter.deleted
```

Required payload fields where available:

```js
encounter_id
encounter_public_id
patient_id
tenant_id
facility_id
encounter_type
status
actor_user_id
occurred_at
affected: { patient_id, encounter_id }
```

### Payment service

File:

```txt
backend/src/modules/payment/services/payment.service.js
```

Emit:

```js
payment.created
payment.updated
payment.deleted
payment.reconciled
```

Required payload fields where available:

```js
payment_id
payment_public_id
invoice_id
invoice_public_id
patient_id
encounter_id
tenant_id
facility_id
amount
status
method
actor_user_id
occurred_at
affected: { payment_id, invoice_id, patient_id, encounter_id }
```

### Visit queue service

File:

```txt
backend/src/modules/visit-queue/services/visit-queue.service.js
```

Emit:

```js
visit_queue.created
visit_queue.updated
visit_queue.deleted
visit_queue.position_changed
```

Required payload fields where available:

```js
queue_id
queue_public_id
patient_id
appointment_id
provider_user_id
tenant_id
facility_id
status
queued_at
actor_user_id
occurred_at
affected: { queue_id, patient_id, appointment_id, provider_user_id }
```

### Billing service

File:

```txt
backend/src/modules/billing/services/billing.service.js
```

Keep existing billing events and add more specific events where appropriate:

```js
invoice.updated
payment.reconciled
billing.balance_updated
```

Important:

* Do not remove current `billing.invoice_issued`, `billing.payment_received`, or `billing.refund_processed` behavior.
* Stop excluding the actor completely from billing realtime recipients.
* The same tab may already update from the API response, but other tabs/devices for the same user must still receive events.
* Other users in the same tenant/facility who should see billing updates must continue receiving them.

---

## 5. Backend: recipient resolution

Use the existing repository/service patterns to determine recipients.

Do not hardcode unsafe global broadcasts unless the existing module already uses that pattern.

If recipient lookup needs database access, place it in the appropriate repository, not in shared websocket helpers.

Missing detail to verify from the codebase:

```txt
The exact role/permission set that should receive patient, encounter, visit queue, payment, and billing events.
```

Choose the smallest safe recipient set based on existing role, facility, tenant, and module patterns.

---

## 6. Frontend: add matching realtime event constants and groups

Update:

```txt
frontend/lib/core/realtime/realtime_events.dart
frontend/lib/core/realtime/realtime_event_groups.dart
```

Add constants for the new backend events.

Required frontend event names:

```dart
patient.created
patient.updated
patient.deleted

encounter.created
encounter.updated
encounter.deleted

visit_queue.created
visit_queue.updated
visit_queue.deleted
visit_queue.position_changed

payment.created
payment.updated
payment.deleted
payment.reconciled

invoice.updated
billing.balance_updated
```

Update event groups so affected workspaces receive the correct invalidation triggers.

Expected group behavior:

| Event                     | Frontend reaction                                                             |
| ------------------------- | ----------------------------------------------------------------------------- |
| `patient.created`         | Refresh/upsert patient registry                                               |
| `patient.updated`         | Refresh/update patient registry, selected patient detail, related workspaces  |
| `patient.deleted`         | Remove patient from lists and close/clear stale selected detail if needed     |
| `encounter.created`       | Refresh patient timeline/detail and OPD/IPD/clinical workspace where relevant |
| `encounter.updated`       | Refresh encounter detail and affected patient/workspace state                 |
| `encounter.deleted`       | Remove stale encounter data and refresh affected patient/workspace state      |
| `visit_queue.created`     | Refresh OPD queue/list                                                        |
| `visit_queue.updated`     | Refresh OPD queue card/status and affected patient state                      |
| `visit_queue.deleted`     | Remove stale queue item and refresh OPD queue/list                            |
| `payment.created`         | Refresh billing workspace/payment list                                        |
| `payment.updated`         | Refresh billing workspace/payment detail                                      |
| `payment.reconciled`      | Refresh invoice, payment list, patient balance, and billing workspace         |
| `invoice.updated`         | Refresh invoice detail and billing workspace                                  |
| `billing.balance_updated` | Refresh patient billing balance and billing workspace                         |

Do not place feature-specific invalidation rules directly inside generic `core` code unless the helper is feature-neutral.

---

## 7. Frontend: centralize invalidation behavior without violating architecture

Improve the existing realtime refresh flow.

Relevant file:

```txt
frontend/lib/core/realtime/realtime_refresh.dart
```

You may create a new helper only if it remains generic, for example:

```txt
frontend/lib/core/realtime/realtime_invalidation_controller.dart
```

But feature-specific mappings must live in feature controllers or feature-owned files.

Requirements:

1. Avoid scattered duplicate websocket handling logic.
2. Keep debounced refresh behavior to prevent excessive API calls.
3. Add support for refresh-on-reconnect/authenticated websocket events.
4. Add support for pending refresh while a controller is saving or already syncing.
5. Do not lose realtime events that arrive during `isSaving` or `_isSyncing`.

Required behavior:

```txt
If realtime event arrives while saving/syncing:
    mark refreshPending = true

After saving/syncing finishes:
    run one refresh if refreshPending == true
```

Apply this pattern to affected controllers, especially:

```txt
patient_registry_controller.dart
opd_workspace_controller.dart
billing_workspace_controller.dart
```

---

## 8. Frontend: use API responses immediately

Do not throw away useful mutation responses.

Billing currently has mutation methods that return `Result<void>` even when the backend can return useful payment, invoice, approval, or billing data.

Update billing repository/controller flow where appropriate:

```txt
frontend/lib/features/billing/domain/repositories/billing_repository.dart
frontend/lib/features/billing/data/repositories/billing_repository_impl.dart
frontend/lib/features/billing/presentation/controllers/billing_workspace_controller.dart
```

Requirements:

1. Replace `Result<void>` with typed results where useful backend data is available.
2. Decode server-confirmed responses instead of ignoring them.
3. Patch selected invoice/payment/workspace state immediately when safe.
4. If exact patching is too risky, trigger a targeted refresh using the server-confirmed result.
5. Keep the UI responsive and avoid waiting for polling.
6. Do not break existing billing actions.

Missing detail to verify from the codebase:

```txt
Exact backend response shapes for issue invoice, send invoice, receive payment, reconcile payment, refund request, adjustment request, void request, shift close, and day close.
```

Use existing DTO/domain conventions.

---

## 9. Frontend: keep existing UI design

Do not redesign pages.

Do not change layout, colors, typography, navigation, modals, or shared components unless required for the realtime state fix.

Expected UX after implementation:

1. Creating/updating/deleting a patient updates the registry and selected detail immediately.
2. Creating/updating/deleting an encounter updates patient detail/timeline and relevant workspace state.
3. Creating/updating/deleting/prioritizing a queue item updates OPD queue state immediately.
4. Processing or reconciling a payment updates billing workspace, invoice state, payment list, and patient balance.
5. Opening the same user account in two tabs/devices keeps both tabs connected and synchronized.
6. WebSocket reconnect causes the visible workspace state to refresh because events may have been missed.

---

## 10. Scope limits

Do **not**:

1. Rewrite the whole app.
2. Replace Riverpod.
3. Replace the existing WebSocket system.
4. Add GraphQL, Socket.IO, Firebase, Supabase, or another realtime platform.
5. Add polling as the primary fix.
6. Redesign the UI.
7. Refactor unrelated modules.
8. Change folder structure unnecessarily.
9. Rename files unless required.
10. Add a transactional outbox migration unless the existing codebase already has an unfinished outbox pattern that can be completed safely.

A transactional outbox is a future improvement, not required for this task.

---

## 11. Testing requirements

Add or update tests for the changed behavior.

### Backend tests

Update or add tests for:

1. WebSocket gateway multiple connections per user:

   * same user can register more than one socket
   * `sendToUser` sends to all sockets for that user
   * closing one socket does not remove other sockets
   * broadcast reaches all expected sockets
   * cleanup closes/removes all sockets safely

2. Event constants and publisher:

   * new event names exist
   * publisher creates stable payload shape
   * publisher does not throw into service mutation flow when delivery fails

3. Service mutations emit expected events:

   * patient create/update/delete
   * encounter create/update/delete
   * payment create/update/delete/reconcile
   * visit queue create/update/delete/position change
   * billing invoice/payment/balance updates

4. Failed mutations must not emit success events.

Run:

```bash
cd backend
npm run lint
npm run test:backend
```

If backend routes or API schemas are changed, also run:

```bash
npm run openapi:validate
```

### Frontend tests

Update or add tests for:

1. New realtime event constants and groups.
2. Realtime refresh helper behavior:

   * debounced refresh
   * refresh-on-reconnect/authenticated event
   * pending refresh while saving/syncing
3. Patient registry controller:

   * reacts to patient events
   * updates/refreshes selected patient when affected
4. OPD workspace controller:

   * reacts to encounter and visit queue events
   * does not lose refresh during saving
5. Billing workspace controller:

   * reacts to payment, invoice, and balance events
   * does not ignore useful mutation responses
6. Billing repository DTO decoding for updated mutation return types.

Run:

```bash
cd frontend
dart format .
flutter analyze
flutter test
```

All linter/analyzer issues must be cleared.

---

## 12. Output requirements

Return a zipped archive containing **only** files and folders that were created or updated.

All files must be placed in their correct relative project directories, for example:

```txt
backend/src/...
frontend/lib/...
frontend/test/...
backend/src/tests/...
```

Do not include:

```txt
node_modules/
build/
.dart_tool/
coverage/
.env files
logs
temporary extraction folders
unrelated unchanged files
```

If any file or folder must be deleted or renamed, include one or more PowerShell scripts:

```txt
scripts/delete-or-rename-*.ps1
```

Script requirements:

1. Use correct relative paths.
2. Check that the target exists before deleting or renaming.
3. Do not delete unrelated files.
4. Do not use broad destructive patterns.
5. Keep scripts safe and readable.

Only modify the files required for this realtime CRUD synchronization task.
