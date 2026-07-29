import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/reception/domain/entities/reception_entities.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_flow_actions_dialog.dart';

/// Roles that may open the Reception / front-desk workspace.
const AccessRequirement receptionWorkspaceRequirement = AccessRequirement(
  anyRoles: AppRoutes.patientFlowWorkspaceRoles,
  anyPermissions: <AppPermission>[
    AppPermissions.patientRead,
    AppPermissions.lastOfficeRead,
  ],
  activeModules: <String>['patient-registry', 'scheduling-queue'],
);

/// Front-desk mutations: check-in, reschedule, cancel, route, assign provider.
///
/// Source role gate ([opdFrontDeskActionRequirement]). Matrix update/delete for
/// Appointments document ∩ `patient:write` / ∩ `patient:delete`; keep this
/// source gate for hub mutations (receptionist role packs omit `patient:delete`).
const AccessRequirement receptionFrontDeskWriteRequirement =
    opdFrontDeskActionRequirement;

/// Patient creation and appointment scheduling additionally require write data
/// rights; a front-desk role by itself is not sufficient for these controls.
const AccessRequirement receptionPatientWriteRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.patientWrite],
  activeModules: <String>['patient-registry', 'scheduling-queue'],
);

/// Matrix delete ∩ `patient:delete` (Appointments / Active visits atoms).
///
/// Cancel appointment keeps [receptionFrontDeskWriteRequirement] — role packs
/// for receptionists omit `patient:delete`. No delete control on Active visits.
const AccessRequirement receptionPatientDeleteRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.patientDelete],
  activeModules: <String>['patient-registry', 'scheduling-queue'],
);

/// Appointment and queue worklists contain patient-identifiable scheduling data.
///
/// Matrix view ∩ `patient:read` (+ modules).
const AccessRequirement receptionSchedulingReadRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.patientRead],
  activeModules: <String>['patient-registry', 'scheduling-queue'],
);

/// Active visits mirror the backend OPD flow list authorization.
///
/// Prompt matrix documents ∩ `patient:read`; keep this source ∪ (patient /
/// clinical / billing / operations / emergency read) + `scheduling-queue` and
/// note the mapping in tests.
const AccessRequirement receptionActiveVisitsRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.patientRead,
    AppPermissions.clinicalRead,
    AppPermissions.billingRead,
    AppPermissions.operationsRead,
    AppPermissions.emergencyRead,
  ],
  activeModules: <String>['scheduling-queue'],
);

/// Nested cross-module write on Active visits (matrix ∪ `clinical:write` |
/// `patient:write`). Flow Actions stage buttons keep source role gates
/// ([opdFrontDeskActionRequirement] / [opdReceptionActionRequirement] / …);
/// Reception opens the hub with clinical / vitals / billing flags off.
const AccessRequirement receptionActiveVisitsNestedWriteRequirement =
    AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.clinicalWrite,
        AppPermissions.patientWrite,
      ],
      activeModules: <String>['scheduling-queue'],
    );

/// Payment-gate guidance uses authoritative invoice data and therefore mirrors
/// the backend Billing read scope. It never grants cashier mutations.
///
/// Prompt matrix documents ∩ `patient:read` + `billing:read`; keep this source
/// `billing:read` (+ `billing-payments`) and note the mapping in tests.
const AccessRequirement receptionPaymentGateRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[AppPermissions.billingRead],
  activeModules: <String>['billing-payments'],
);

/// Matrix create/update ∩ `billing:write` (collect / receive payment).
///
/// Reception Payment gate intentionally does not mount cashier collect
/// controls; Billing workspace owns Receive payment. This gate documents the
/// collect verb for absence tests and any future collect entry points.
const AccessRequirement receptionPaymentGateCollectRequirement =
    AccessRequirement(
      allPermissions: <AppPermission>[AppPermissions.billingWrite],
      activeModules: <String>['billing-payments'],
    );

/// Nested emergency handoff / emergency-visit chrome on High priority.
///
/// Matrix nested cross-module read ∪ `emergency:read` (+ `scheduling-queue`).
/// Does not unlock the High priority tab itself (tab stays ∩ `patient:read`).
const AccessRequirement receptionHighPriorityEmergencyNestedReadRequirement =
    AccessRequirement(
      anyPermissions: <AppPermission>[AppPermissions.emergencyRead],
      activeModules: <String>['scheduling-queue'],
    );

AccessRequirement receptionDeskSectionRequirement(
  ReceptionDeskSection section,
) {
  return switch (section) {
    ReceptionDeskSection.appointments => ReceptionAppointmentsAtomPermissions.tab,
    ReceptionDeskSection.queue => ReceptionDeskQueueAtomPermissions.tab,
    ReceptionDeskSection.highPriority => ReceptionHighPriorityAtomPermissions.tab,
    ReceptionDeskSection.activeVisits => ReceptionActiveVisitsAtomPermissions.tab,
    ReceptionDeskSection.followUps => ReceptionFollowUpsAtomPermissions.tab,
    ReceptionDeskSection.paymentGate => ReceptionPaymentGateAtomPermissions.tab,
  };
}

/// Whether [flow] carries emergency indicators for High priority nested chrome.
bool isReceptionEmergencyFlow(OpdFlowSummary flow) {
  return flow.emergencyIndicator ||
      (flow.encounterType ?? '').toUpperCase() == 'EMERGENCY' ||
      (flow.triageLevel ?? '').toUpperCase() == 'LEVEL_1' ||
      (flow.triageLevel ?? '').toUpperCase() == 'IMMEDIATE';
}

/// Follow-ups worklist read — source ∪ `patient:read` | `clinical:read`
/// (matches backend follow-up list auth).
///
/// Prompt matrix documents ∪ `patient:read` | `last_office:read` and ∩
/// `patient:read`; keep this source ∪ (backend list) and note the mapping in
/// tests. `last_office:read` alone may enter the reception shell but cannot
/// list follow-ups.
const AccessRequirement receptionFollowUpsRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.patientRead,
    AppPermissions.clinicalRead,
  ],
  activeModules: <String>['patient-registry', 'scheduling-queue'],
);

/// Follow-ups complete / reschedule — matrix ∩ `patient:write`.
///
/// Backend complete accepts ∪ `clinical:write` | `patient:write`; PUT update
/// (reschedule) currently requires `clinical:write` alone. Reception chrome
/// keeps matrix ∩ via [receptionPatientWriteRequirement]. Readers with only
/// `last_office:read` / read grants cannot mutate.
const AccessRequirement receptionFollowUpsWriteRequirement =
    receptionPatientWriteRequirement;

/// Front-desk insurance enrollment capture (not claims finalize).
const AccessRequirement receptionInsuranceCaptureRequirement =
    AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.patientWrite,
        AppPermissions.billingWrite,
      ],
      activeModules: <String>['insurance-claims'],
    );

bool canViewReceptionAppointments(AppAccessPolicy policy) {
  return ReceptionAppointmentsAtomPermissions.tab.isAllowed(policy);
}

bool canViewReceptionDeskQueue(AppAccessPolicy policy) {
  return ReceptionDeskQueueAtomPermissions.tab.isAllowed(policy);
}

bool canViewReceptionHighPriority(AppAccessPolicy policy) {
  return ReceptionHighPriorityAtomPermissions.tab.isAllowed(policy);
}

/// Desk queue next-action cells are read-only guidance labels (not mutation
/// buttons). Mount whenever the tab is readable.
bool receptionDeskQueueShowsNextActionColumn(AppAccessPolicy policy) {
  return ReceptionDeskQueueAtomPermissions.nextActionLabel.isAllowed(policy);
}

/// High priority next-action cells are read-only guidance labels.
bool receptionHighPriorityShowsNextActionColumn(AppAccessPolicy policy) {
  return ReceptionHighPriorityAtomPermissions.nextActionLabel.isAllowed(policy);
}

bool canViewReceptionFollowUps(AppAccessPolicy policy) {
  return ReceptionFollowUpsAtomPermissions.tab.isAllowed(policy);
}

/// Whether Follow-ups complete / reschedule may mount.
bool canWriteReceptionFollowUps(AppAccessPolicy policy) {
  return ReceptionFollowUpsAtomPermissions.write.isAllowed(policy);
}

bool canViewReceptionActiveVisits(AppAccessPolicy policy) {
  return ReceptionActiveVisitsAtomPermissions.tab.isAllowed(policy);
}

bool canViewReceptionPaymentGate(AppAccessPolicy policy) {
  return ReceptionPaymentGateAtomPermissions.tab.isAllowed(policy);
}

/// Payment gate next-action cells are read-only billing guidance labels.
bool receptionPaymentGateShowsNextActionColumn(AppAccessPolicy policy) {
  return ReceptionPaymentGateAtomPermissions.nextActionLabel.isAllowed(policy);
}

/// Whether the Appointments next-action column may mount.
bool receptionAppointmentsShowsNextActionColumn(AppAccessPolicy policy) {
  return ReceptionAppointmentsAtomPermissions.nextActionCheckIn.isAllowed(
        policy,
      ) ||
      ReceptionAppointmentsAtomPermissions.nextActionContinue.isAllowed(
        policy,
      ) ||
      ReceptionAppointmentsAtomPermissions.nextActionReschedule.isAllowed(
        policy,
      ) ||
      ReceptionAppointmentsAtomPermissions.frontDesk.isAllowed(policy);
}

/// Appointments tab atom → permission mapping (inventory + matrix).
///
/// Schedule / check-in / reschedule / cancel (`/reception?section=appointments`).
/// Nested cross-module matrix rows are _(n/a)_. Register + Schedule use matrix
/// ∩ `patient:write`. Hub check-in / reschedule / cancel keep source
/// [receptionFrontDeskWriteRequirement] rather than matrix ∩ alone (cancel
/// cannot use ∩ `patient:delete` — receptionist packs omit it). Route entry
/// stays ∪ `patient:read` | `last_office:read`. Tab chrome stays ∩ `patient:read`.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Appointments strip tab / count | navigate | read ∩ ([tab]) |
/// | Register patient (primary) | create | write ∩ ([register]) |
/// | Schedule appointment (secondary) | create | write ∩ ([schedule]) |
/// | Search / Clear / Filters / Settings / columns | read chrome | ([listChrome]) |
/// | Empty / loading / error / retry | read chrome | ([empty] / [loading] / [retry]) |
/// | Success snackbar / validation (authorized) | visible feedback | write ∩ / form |
/// | Row select → Appointment Actions hub | read | ([rowSelect] / [detail]) |
/// | Next action Check in / Continue / Reschedule | update | source front-desk |
/// | Nested hub Reschedule | update | source front-desk ([reschedule]) |
/// | Nested hub Cancel appointment | delete | source front-desk ([cancelAppointment]) |
/// | Nested encounter dialog (check-in) | create | source front-desk ([checkIn]) |
/// | Nested billing / clinical panels | nested write | _(n/a)_ — hub strips them |
/// | Route entry (deep link) | navigate | ∪ patient:read \| last_office:read |
abstract final class ReceptionAppointmentsAtomPermissions {
  static const AccessRequirement tab = receptionSchedulingReadRequirement;
  static const AccessRequirement listChrome = receptionSchedulingReadRequirement;
  static const AccessRequirement search = receptionSchedulingReadRequirement;
  static const AccessRequirement filters = receptionSchedulingReadRequirement;
  static const AccessRequirement settings = receptionSchedulingReadRequirement;
  static const AccessRequirement empty = receptionSchedulingReadRequirement;
  static const AccessRequirement loading = receptionSchedulingReadRequirement;
  static const AccessRequirement retry = receptionSchedulingReadRequirement;
  static const AccessRequirement success = receptionPatientWriteRequirement;
  static const AccessRequirement validation = receptionPatientWriteRequirement;
  static const AccessRequirement rowSelect = receptionSchedulingReadRequirement;
  static const AccessRequirement detail = receptionSchedulingReadRequirement;
  static const AccessRequirement close = receptionSchedulingReadRequirement;

  /// Matrix ∩ `patient:write`.
  static const AccessRequirement create = receptionPatientWriteRequirement;
  static const AccessRequirement update = receptionPatientWriteRequirement;

  /// Matrix ∩ `patient:delete` (documented); cancel keeps [frontDesk].
  static const AccessRequirement delete = receptionPatientDeleteRequirement;

  static const AccessRequirement register = receptionPatientWriteRequirement;
  static const AccessRequirement schedule = receptionPatientWriteRequirement;
  static const AccessRequirement write = receptionPatientWriteRequirement;

  /// Source front-desk gate for appointment hub writes (keep source).
  static const AccessRequirement frontDesk = receptionFrontDeskWriteRequirement;
  static const AccessRequirement nextAction = receptionFrontDeskWriteRequirement;
  static const AccessRequirement nextActionCheckIn =
      receptionFrontDeskWriteRequirement;
  static const AccessRequirement nextActionContinue =
      receptionFrontDeskWriteRequirement;
  static const AccessRequirement nextActionReschedule =
      receptionFrontDeskWriteRequirement;
  static const AccessRequirement checkIn = receptionFrontDeskWriteRequirement;
  static const AccessRequirement reschedule = receptionFrontDeskWriteRequirement;
  static const AccessRequirement cancelAppointment =
      receptionFrontDeskWriteRequirement;

  /// Nested cross-module write — matrix _(n/a)_; hub uses front-desk only.
  static const AccessRequirement nestedWrite = receptionFrontDeskWriteRequirement;

  /// Nested cross-module read — matrix _(n/a)_; reuses scheduling read ∩.
  static const AccessRequirement nestedRead = receptionSchedulingReadRequirement;

  static const AccessRequirement entry = receptionWorkspaceRequirement;
  static const AccessRequirement routeEntry = receptionWorkspaceRequirement;
  static const AccessRequirement routeEntryUnion = receptionWorkspaceRequirement;
}

/// Desk queue tab atom → permission mapping (inventory + matrix).
///
/// Waiting queue + hub mutations (`/reception?section=desk-queue`). Nested
/// cross-module matrix rows are _(n/a)_. Register + Schedule use matrix ∩
/// `patient:write`. Hub prioritize / change status / assign doctor keep source
/// [receptionFrontDeskWriteRequirement] rather than matrix ∩ alone (role packs
/// authorize front-desk queue work; matrix delete ∩ `patient:delete` has no
/// delete atom on this tab). Route entry stays ∪ `patient:read` |
/// `last_office:read`. Tab chrome stays ∩ `patient:read`. Next-action column is
/// progressive-disclosure read chrome (guidance labels only).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Desk queue strip tab / count | navigate | read ∩ ([tab]) |
/// | Register patient (primary) | create | write ∩ ([register]) |
/// | Schedule appointment (secondary) | create | write ∩ ([schedule]) |
/// | Search / Clear / Filters / Settings / columns | read chrome | ([listChrome]) |
/// | Empty / loading / error / retry | read chrome | ([empty] / [loading] / [retry]) |
/// | Success snackbar / validation (authorized) | visible feedback | write ∩ / form |
/// | Row select → Queue Actions hub | read | ([rowSelect] / [detail]) |
/// | Row select → Flow Actions (linked visit) | read | ([rowSelect] / [detail]) |
/// | Next action guidance label | progressive disclosure | read ∩ ([nextActionLabel]) |
/// | Nested hub Prioritize | update | source front-desk ([prioritize]) |
/// | Nested hub Change status | update | source front-desk ([changeStatus]) |
/// | Nested hub Assign / Change doctor | update | source front-desk ([assignDoctor]) |
/// | Nested billing / clinical panels from hub | nested write | _(n/a)_ — hub strips them |
/// | Route entry (deep link) | navigate | ∪ patient:read \| last_office:read |
abstract final class ReceptionDeskQueueAtomPermissions {
  static const AccessRequirement tab = receptionSchedulingReadRequirement;
  static const AccessRequirement listChrome = receptionSchedulingReadRequirement;
  static const AccessRequirement search = receptionSchedulingReadRequirement;
  static const AccessRequirement filters = receptionSchedulingReadRequirement;
  static const AccessRequirement settings = receptionSchedulingReadRequirement;
  static const AccessRequirement empty = receptionSchedulingReadRequirement;
  static const AccessRequirement loading = receptionSchedulingReadRequirement;
  static const AccessRequirement retry = receptionSchedulingReadRequirement;
  static const AccessRequirement success = receptionPatientWriteRequirement;
  static const AccessRequirement validation = receptionPatientWriteRequirement;
  static const AccessRequirement rowSelect = receptionSchedulingReadRequirement;
  static const AccessRequirement detail = receptionSchedulingReadRequirement;
  static const AccessRequirement close = receptionSchedulingReadRequirement;

  /// Read-only next-action guidance (not a mutation control).
  static const AccessRequirement nextActionLabel =
      receptionSchedulingReadRequirement;

  /// Matrix ∩ `patient:write`.
  static const AccessRequirement create = receptionPatientWriteRequirement;
  static const AccessRequirement update = receptionPatientWriteRequirement;

  /// Matrix ∩ `patient:delete` (documented); queue hub has no delete atom.
  static const AccessRequirement delete = receptionPatientDeleteRequirement;

  static const AccessRequirement register = receptionPatientWriteRequirement;
  static const AccessRequirement schedule = receptionPatientWriteRequirement;
  static const AccessRequirement write = receptionPatientWriteRequirement;

  /// Source front-desk gate for queue hub writes (keep source).
  static const AccessRequirement frontDesk = receptionFrontDeskWriteRequirement;
  static const AccessRequirement nextAction = receptionFrontDeskWriteRequirement;
  static const AccessRequirement prioritize = receptionFrontDeskWriteRequirement;
  static const AccessRequirement changeStatus =
      receptionFrontDeskWriteRequirement;
  static const AccessRequirement moveQueue = receptionFrontDeskWriteRequirement;
  static const AccessRequirement assignDoctor =
      receptionFrontDeskWriteRequirement;

  /// Nested cross-module write — matrix _(n/a)_; hub uses front-desk only.
  static const AccessRequirement nestedWrite =
      receptionFrontDeskWriteRequirement;

  /// Nested cross-module read — matrix _(n/a)_; reuses scheduling read ∩.
  static const AccessRequirement nestedRead = receptionSchedulingReadRequirement;

  static const AccessRequirement entry = receptionWorkspaceRequirement;
  static const AccessRequirement routeEntry = receptionWorkspaceRequirement;
  static const AccessRequirement routeEntryUnion = receptionWorkspaceRequirement;
  static const AccessRequirement catalogEntry = RouteAccessCatalog.receptionEntry;
}

/// Active visits tab atom → permission mapping (inventory + matrix).
///
/// In-facility same-day visits (`/reception?section=active` /
/// `active-visits`). Prompt matrix ∩ `patient:read` for view maps to source ∪
/// [receptionActiveVisitsRequirement] (keep source). Create/update Register /
/// Schedule keep ∩ `patient:write` ([receptionPatientWriteRequirement]).
/// Delete maps ∩ `patient:delete` ([delete]) — no delete control on this tab.
/// Nested cross-module write matrix ∪ `clinical:write` | `patient:write`
/// ([nestedWrite]); Flow Actions clinical / vitals / billing stay off from
/// Reception and keep source stage gates for remaining front-desk actions.
/// Route entry keeps workspace ∪ `patient:read` | `last_office:read`; catalog
/// ∩ `reception:read` is noted in tests.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Active visits tab / count badge | navigate | read ∪ ([tab]) |
/// | Register patient (strip primary) | create | ∩ patient:write ([register]) |
/// | Schedule appointment (strip secondary) | create | ∩ patient:write ([scheduleAppointment]) |
/// | Search / Clear / Filters / Settings / columns | read chrome | ([listChrome]) |
/// | Stage / next-action / staff / payment filters | read chrome | ([filters]) |
/// | Empty / error / retry / loading | read chrome | ([empty] / [loading] / [retry]) |
/// | Success snackbar / validation (authorized) | visible feedback | write / form |
/// | Row select → Flow Actions (read guidance) | read | ([rowSelect] / [detail]) |
/// | Next-action column (label only, not button) | read chrome | ([nextActionLabel]) |
/// | Nested Flow Actions clinical / vitals / billing | update | off + source ([nestedBillingWrite] / …) |
/// | Nested Flow Actions assign / follow-up / print / correct stage | update | source front-desk / reception |
/// | Nested matrix write ∪ | update | ([nestedWrite]) |
/// | Deep link `section=active` / `flowId=` | navigate | ([tab] / [rowSelect]) |
/// | Route entry (workspace) | navigate | ([entry] / [routeEntryUnion]) |
/// | Catalog route entry ∩ reception:read | navigate | ([catalogEntry]) |
abstract final class ReceptionActiveVisitsAtomPermissions {
  static const AccessRequirement tab = receptionActiveVisitsRequirement;
  static const AccessRequirement listChrome = receptionActiveVisitsRequirement;
  static const AccessRequirement search = receptionActiveVisitsRequirement;
  static const AccessRequirement filters = receptionActiveVisitsRequirement;
  static const AccessRequirement settings = receptionActiveVisitsRequirement;
  static const AccessRequirement empty = receptionActiveVisitsRequirement;
  static const AccessRequirement loading = receptionActiveVisitsRequirement;
  static const AccessRequirement retry = receptionActiveVisitsRequirement;
  static const AccessRequirement success = receptionPatientWriteRequirement;
  static const AccessRequirement validation = receptionPatientWriteRequirement;
  static const AccessRequirement rowSelect = receptionActiveVisitsRequirement;
  static const AccessRequirement detail = receptionActiveVisitsRequirement;

  /// Matrix ∩ `patient:write` (Register / Schedule strip actions).
  static const AccessRequirement create = receptionPatientWriteRequirement;
  static const AccessRequirement update = receptionPatientWriteRequirement;
  static const AccessRequirement delete = receptionPatientDeleteRequirement;
  static const AccessRequirement write = receptionPatientWriteRequirement;
  static const AccessRequirement register = receptionPatientWriteRequirement;
  static const AccessRequirement scheduleAppointment =
      receptionPatientWriteRequirement;

  /// Next-action column is read-only guidance text (not a mutation control).
  static const AccessRequirement nextActionLabel =
      receptionActiveVisitsRequirement;

  /// Matrix nested write ∪ `clinical:write` | `patient:write`.
  static const AccessRequirement nestedWrite =
      receptionActiveVisitsNestedWriteRequirement;

  /// Nested cross-module read — matrix _(n/a)_; reuses tab read ∪.
  static const AccessRequirement nestedRead = receptionActiveVisitsRequirement;

  /// Billing mutations stay unavailable from Reception Active visits.
  static const AccessRequirement nestedBillingWrite =
      opdBillingActionRequirement;

  /// Remaining Flow Actions front-desk mutations (source role gate).
  static const AccessRequirement nestedFrontDesk =
      receptionFrontDeskWriteRequirement;
  static const AccessRequirement nestedAssignDoctor =
      opdReceptionActionRequirement;
  static const AccessRequirement nestedCorrectStage =
      opdReceptionActionRequirement;

  static const AccessRequirement entry = receptionWorkspaceRequirement;
  static const AccessRequirement routeEntry = receptionWorkspaceRequirement;
  static const AccessRequirement routeEntryUnion = receptionWorkspaceRequirement;
  static const AccessRequirement catalogEntry = RouteAccessCatalog.receptionEntry;
}

/// Follow-ups tab atom → permission mapping (inventory + matrix).
///
/// Call worklist (`/reception?section=follow-ups`). Prompt matrix view ∪
/// `patient:read` | `last_office:read` (and ∩ `patient:read`) maps to source ∪
/// [receptionFollowUpsRequirement] (`patient:read` | `clinical:read` — backend
/// list auth; keep source). Create / update keep ∩ `patient:write`
/// ([receptionFollowUpsWriteRequirement]). Delete maps ∩ `patient:delete`
/// ([delete]) — no delete control on this tab (complete is update). Nested
/// cross-module matrix rows are _(n/a)_. Register / Schedule strip actions
/// reuse ∩ `patient:write`. Route entry keeps workspace ∪ `patient:read` |
/// `last_office:read`. Complete / reschedule gated by write ∩; read-only
/// detail shows Close only (no mutation affordances).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Follow-ups strip tab / count | navigate | read ∪ ([tab]) |
/// | Register patient (strip primary) | create | ∩ patient:write ([register]) |
/// | Schedule appointment (strip secondary) | create | ∩ patient:write ([schedule]) |
/// | Search / Clear / Settings / columns | read chrome | ([listChrome] / [search]) |
/// | Advanced filters / date filter | read chrome | omitted on this tab |
/// | Empty / loading / error / retry | read chrome | ([empty] / [loading] / [retry]) |
/// | Success snackbar / validation (authorized) | visible feedback | write ∩ / form |
/// | Row select → follow-up detail | read | ([rowSelect] / [detail]) |
/// | Detail patient / schedule / notes panels | read | ([detail]) |
/// | Detail Close (read-only footer) | progressive disclosure | ([close]) |
/// | Reschedule follow-up | update | write ∩ ([reschedule]) |
/// | Mark completed | update | write ∩ ([markCompleted] / [complete]) |
/// | Save follow-up (nested reschedule dialog) | update | write ∩ ([saveFollowUp]) |
/// | Hard delete / void | delete | ∩ patient:delete ([delete]) — not mounted |
/// | Nested cross-module panels | nested | _(n/a)_ ([nestedRead] / [nestedWrite]) |
/// | Deep link `section=follow-ups` | navigate | ([tab] / [rowSelect]) |
/// | Route entry (workspace) | navigate | ([entry] / [routeEntryUnion]) |
abstract final class ReceptionFollowUpsAtomPermissions {
  static const AccessRequirement tab = receptionFollowUpsRequirement;
  static const AccessRequirement listChrome = receptionFollowUpsRequirement;
  static const AccessRequirement search = receptionFollowUpsRequirement;
  static const AccessRequirement filters = receptionFollowUpsRequirement;
  static const AccessRequirement settings = receptionFollowUpsRequirement;
  static const AccessRequirement empty = receptionFollowUpsRequirement;
  static const AccessRequirement loading = receptionFollowUpsRequirement;
  static const AccessRequirement retry = receptionFollowUpsRequirement;
  static const AccessRequirement success = receptionFollowUpsWriteRequirement;
  static const AccessRequirement validation = receptionFollowUpsWriteRequirement;
  static const AccessRequirement rowSelect = receptionFollowUpsRequirement;
  static const AccessRequirement detail = receptionFollowUpsRequirement;
  static const AccessRequirement close = receptionFollowUpsRequirement;

  /// Matrix ∩ `patient:write` (Register / Schedule strip + mutations).
  static const AccessRequirement create = receptionFollowUpsWriteRequirement;
  static const AccessRequirement update = receptionFollowUpsWriteRequirement;
  static const AccessRequirement delete = receptionPatientDeleteRequirement;
  static const AccessRequirement write = receptionFollowUpsWriteRequirement;
  static const AccessRequirement register = receptionPatientWriteRequirement;
  static const AccessRequirement schedule = receptionPatientWriteRequirement;
  static const AccessRequirement reschedule = receptionFollowUpsWriteRequirement;
  static const AccessRequirement markCompleted =
      receptionFollowUpsWriteRequirement;
  static const AccessRequirement complete = receptionFollowUpsWriteRequirement;
  static const AccessRequirement saveFollowUp =
      receptionFollowUpsWriteRequirement;

  /// Nested cross-module — matrix _(n/a)_; reuses follow-ups read ∪ / write ∩.
  static const AccessRequirement nestedWrite = receptionFollowUpsWriteRequirement;
  static const AccessRequirement nestedRead = receptionFollowUpsRequirement;

  static const AccessRequirement entry = receptionWorkspaceRequirement;
  static const AccessRequirement routeEntry = receptionWorkspaceRequirement;
  static const AccessRequirement routeEntryUnion = receptionWorkspaceRequirement;
  static const AccessRequirement catalogEntry = RouteAccessCatalog.receptionEntry;
  static const AccessRequirement read = receptionFollowUpsRequirement;
}

/// High priority tab atom → permission mapping (inventory + matrix).
///
/// Escalated desk-queue items (`/reception?section=high-priority`). Tab chrome
/// stays ∩ `patient:read` ([receptionSchedulingReadRequirement]). Register /
/// Schedule use matrix ∩ `patient:write`. Hub prioritize / change status /
/// assign doctor keep source [receptionFrontDeskWriteRequirement] rather than
/// matrix ∩ alone. Delete maps ∩ `patient:delete` ([delete]) — no hard-delete
/// control on this tab. Nested cross-module read matrix ∪ `emergency:read`
/// ([nestedEmergencyRead] / [nestedRead]); emergency-linked Flow Actions open
/// only when that grant is present — otherwise Queue Actions (front-desk) open.
/// Nested cross-module write matrix rows are _(n/a)_. Route entry keeps
/// workspace ∪ `patient:read` | `last_office:read`.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | High priority strip tab / count | navigate | read ∩ ([tab]) |
/// | Register patient (strip primary) | create | ∩ patient:write ([register]) |
/// | Schedule appointment (strip secondary) | create | ∩ patient:write ([schedule]) |
/// | Search / Clear / Filters / Settings / columns | read chrome | ([listChrome]) |
/// | Status / next-action / staff / payment filters | read chrome | ([filters]) |
/// | High priority badge (prioritized) | read chrome | ([listChrome]) |
/// | Empty / loading / error / retry | read chrome | ([empty] / [loading] / [retry]) |
/// | Success snackbar / validation (authorized) | visible feedback | write ∩ / form |
/// | Row select → Queue Actions / Flow Actions | read | ([rowSelect] / [detail]) |
/// | Next-action column (label only) | read chrome | ([nextActionLabel]) |
/// | Nested prioritize / change status / assign doctor | update | source front-desk |
/// | Nested emergency Flow Actions / visit chrome | nested read | ∪ emergency:read |
/// | Nested cross-module write | nested write | _(n/a)_ ([nestedWrite] front-desk) |
/// | Deep link `section=high-priority` | navigate | ([tab]) |
/// | Route entry (workspace) | navigate | ([entry] / [routeEntryUnion]) |
abstract final class ReceptionHighPriorityAtomPermissions {
  static const AccessRequirement tab = receptionSchedulingReadRequirement;
  static const AccessRequirement listChrome = receptionSchedulingReadRequirement;
  static const AccessRequirement search = receptionSchedulingReadRequirement;
  static const AccessRequirement filters = receptionSchedulingReadRequirement;
  static const AccessRequirement settings = receptionSchedulingReadRequirement;
  static const AccessRequirement empty = receptionSchedulingReadRequirement;
  static const AccessRequirement loading = receptionSchedulingReadRequirement;
  static const AccessRequirement retry = receptionSchedulingReadRequirement;
  static const AccessRequirement success = receptionPatientWriteRequirement;
  static const AccessRequirement validation = receptionPatientWriteRequirement;
  static const AccessRequirement rowSelect = receptionSchedulingReadRequirement;
  static const AccessRequirement detail = receptionSchedulingReadRequirement;
  static const AccessRequirement close = receptionSchedulingReadRequirement;

  /// Matrix ∩ `patient:write`.
  static const AccessRequirement create = receptionPatientWriteRequirement;
  static const AccessRequirement update = receptionPatientWriteRequirement;
  static const AccessRequirement delete = receptionPatientDeleteRequirement;
  static const AccessRequirement write = receptionPatientWriteRequirement;
  static const AccessRequirement register = receptionPatientWriteRequirement;
  static const AccessRequirement schedule = receptionPatientWriteRequirement;

  /// Next-action column is read-only guidance text (not a mutation control).
  static const AccessRequirement nextActionLabel =
      receptionSchedulingReadRequirement;

  /// Source front-desk gate for queue hub writes (keep source).
  static const AccessRequirement frontDesk = receptionFrontDeskWriteRequirement;
  static const AccessRequirement prioritize = receptionFrontDeskWriteRequirement;
  static const AccessRequirement changeStatus = receptionFrontDeskWriteRequirement;
  static const AccessRequirement assignDoctor = receptionFrontDeskWriteRequirement;

  /// Matrix nested read ∪ `emergency:read`.
  static const AccessRequirement nestedEmergencyRead =
      receptionHighPriorityEmergencyNestedReadRequirement;
  static const AccessRequirement nestedRead =
      receptionHighPriorityEmergencyNestedReadRequirement;

  /// Nested cross-module write — matrix _(n/a)_; hub uses front-desk.
  static const AccessRequirement nestedWrite = receptionFrontDeskWriteRequirement;

  static const AccessRequirement entry = receptionWorkspaceRequirement;
  static const AccessRequirement routeEntry = receptionWorkspaceRequirement;
  static const AccessRequirement routeEntryUnion = receptionWorkspaceRequirement;
  static const AccessRequirement catalogEntry = RouteAccessCatalog.receptionEntry;
}

/// Payment gate tab atom → permission mapping (inventory + matrix).
///
/// Billing hold / payment clearance guidance (`/reception?section=payment-gate`).
/// Prompt matrix view ∩ `patient:read` + `billing:read` maps to source
/// [receptionPaymentGateRequirement] (`billing:read` + `billing-payments` —
/// mirrors backend Billing read; keep source). Create/update matrix ∩
/// `billing:write` ([collect] / [create] / [update]) — cashier Receive payment
/// is intentionally **not mounted** on this tab (Billing workspace owns
/// collect). Register / Schedule strip reuse ∩ `patient:write`. Delete maps ∩
/// `patient:delete` ([delete]) — no delete control. Nested cross-module matrix
/// rows are _(n/a)_. Route entry keeps workspace ∪ `patient:read` |
/// `last_office:read`. Detail is read-only guidance (Close only).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Payment gate strip tab / count | navigate | read source ([tab]) |
/// | Register patient (strip primary) | create | ∩ patient:write ([register]) |
/// | Schedule appointment (strip secondary) | create | ∩ patient:write ([schedule]) |
/// | Search / Clear / Filters / Settings / columns | read chrome | ([listChrome]) |
/// | Status / source / date filters | read chrome | ([filters]) |
/// | Empty / loading / error / retry | read chrome | ([empty] / [loading] / [retry]) |
/// | Success snackbar / validation (authorized) | visible feedback | write / form |
/// | Row select → read-only billing guidance detail | read | ([rowSelect] / [detail]) |
/// | Next-action column (Billing guidance label) | progressive disclosure | ([nextActionLabel]) |
/// | Collect / Receive payment | create / update | ∩ billing:write ([collect]) — not mounted |
/// | Hard delete / void | delete | ∩ patient:delete ([delete]) — not mounted |
/// | Nested cross-module panels | nested | _(n/a)_ ([nestedRead] / [nestedWrite]) |
/// | Deep link `section=payment-gate` | navigate | ([tab] / [rowSelect]) |
/// | Route entry (workspace) | navigate | ([entry] / [routeEntryUnion]) |
abstract final class ReceptionPaymentGateAtomPermissions {
  static const AccessRequirement tab = receptionPaymentGateRequirement;
  static const AccessRequirement listChrome = receptionPaymentGateRequirement;
  static const AccessRequirement search = receptionPaymentGateRequirement;
  static const AccessRequirement filters = receptionPaymentGateRequirement;
  static const AccessRequirement settings = receptionPaymentGateRequirement;
  static const AccessRequirement empty = receptionPaymentGateRequirement;
  static const AccessRequirement loading = receptionPaymentGateRequirement;
  static const AccessRequirement retry = receptionPaymentGateRequirement;
  static const AccessRequirement success = receptionPaymentGateCollectRequirement;
  static const AccessRequirement validation =
      receptionPaymentGateCollectRequirement;
  static const AccessRequirement rowSelect = receptionPaymentGateRequirement;
  static const AccessRequirement detail = receptionPaymentGateRequirement;
  static const AccessRequirement close = receptionPaymentGateRequirement;

  /// Matrix ∩ `billing:write` (collect). Controls intentionally not mounted.
  static const AccessRequirement create = receptionPaymentGateCollectRequirement;
  static const AccessRequirement update = receptionPaymentGateCollectRequirement;
  static const AccessRequirement collect = receptionPaymentGateCollectRequirement;
  static const AccessRequirement receivePayment =
      receptionPaymentGateCollectRequirement;
  static const AccessRequirement write = receptionPaymentGateCollectRequirement;

  /// Matrix ∩ `patient:delete` — no delete control on this tab.
  static const AccessRequirement delete = receptionPatientDeleteRequirement;

  /// Desk strip Register / Schedule (prose: need `patient:write`).
  static const AccessRequirement register = receptionPatientWriteRequirement;
  static const AccessRequirement schedule = receptionPatientWriteRequirement;

  /// Next-action column is read-only billing guidance (not a mutation control).
  static const AccessRequirement nextActionLabel =
      receptionPaymentGateRequirement;

  /// Nested cross-module — matrix _(n/a)_; reuses tab read / collect write.
  static const AccessRequirement nestedRead = receptionPaymentGateRequirement;
  static const AccessRequirement nestedWrite =
      receptionPaymentGateCollectRequirement;

  static const AccessRequirement entry = receptionWorkspaceRequirement;
  static const AccessRequirement routeEntry = receptionWorkspaceRequirement;
  static const AccessRequirement routeEntryUnion = receptionWorkspaceRequirement;
  static const AccessRequirement catalogEntry = RouteAccessCatalog.receptionEntry;
  static const AccessRequirement read = receptionPaymentGateRequirement;
}
