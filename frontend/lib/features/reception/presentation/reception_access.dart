import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';
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
const AccessRequirement receptionPaymentGateRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[AppPermissions.billingRead],
  activeModules: <String>['billing-payments'],
);

AccessRequirement receptionDeskSectionRequirement(
  ReceptionDeskSection section,
) {
  return switch (section) {
    ReceptionDeskSection.appointments => ReceptionAppointmentsAtomPermissions.tab,
    ReceptionDeskSection.queue ||
    ReceptionDeskSection.highPriority => receptionSchedulingReadRequirement,
    ReceptionDeskSection.activeVisits => ReceptionActiveVisitsAtomPermissions.tab,
    ReceptionDeskSection.followUps => receptionFollowUpsRequirement,
    ReceptionDeskSection.paymentGate => receptionPaymentGateRequirement,
  };
}

/// Follow-ups worklist: patient or clinical read (matches follow-up list auth).
const AccessRequirement receptionFollowUpsRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.patientRead,
    AppPermissions.clinicalRead,
  ],
  activeModules: <String>['patient-registry', 'scheduling-queue'],
);

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

bool canViewReceptionActiveVisits(AppAccessPolicy policy) {
  return ReceptionActiveVisitsAtomPermissions.tab.isAllowed(policy);
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
