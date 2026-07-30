import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';

/// Module entitlement for the clinical workspace route and encounter worklists.
const String clinicalEncountersVitalsModule = 'encounters-vitals';

/// View / read UI (matrix ∩ `clinical:read`).
const AccessRequirement clinicalWorkspaceReadRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.clinicalRead],
  activeModules: <String>[clinicalEncountersVitalsModule],
);

/// Alias used by tab atom maps / prompts.
const AccessRequirement clinicalReadRequirement =
    clinicalWorkspaceReadRequirement;

/// Route entry — unique atom from [RouteAccessCatalog.clinical].
const AccessRequirement clinicalWorkspaceEntryRequirement =
    RouteAccessCatalog.clinicalEntry;

/// Create / update / delete encounter mutations.
///
/// Matrix lists ∩ `clinical:write` alone; source inventory (`screens/clinical.md`)
/// documents `_writeRequirement` / `clinicalEncounterWriteRequirement` as ∪
/// `clinical:write` | `system:admin` plus `encounters-vitals` — keep source.
const AccessRequirement clinicalWorkspaceWriteRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.clinicalWrite,
    AppPermissions.systemAdmin,
  ],
  activeModules: <String>[clinicalEncountersVitalsModule],
);

/// Alias matching historical `_writeRequirement` / panel write gate.
const AccessRequirement clinicalEncounterWriteRequirement =
    clinicalWorkspaceWriteRequirement;

/// Alias used by tab atom maps / prompts.
const AccessRequirement clinicalWriteRequirement =
    clinicalWorkspaceWriteRequirement;

/// Nested lab request / order mutations (prompt narrative ∪):
/// `clinical:write` | `lab:write` | `system:admin`.
const AccessRequirement clinicalLabOrderWriteRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.clinicalWrite,
    AppPermissions.labWrite,
    AppPermissions.systemAdmin,
  ],
  activeModules: <String>[clinicalEncountersVitalsModule],
);

/// Nested radiology request / order mutations (prompt narrative ∪):
/// `clinical:write` | `radiology:write` | `system:admin`.
const AccessRequirement clinicalRadiologyOrderWriteRequirement =
    AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.clinicalWrite,
        AppPermissions.radiologyWrite,
        AppPermissions.systemAdmin,
      ],
      activeModules: <String>[clinicalEncountersVitalsModule],
    );

/// Nested pharmacy / prescribe mutations (prompt narrative ∪):
/// `clinical:write` | `pharmacy:write` | `system:admin`.
const AccessRequirement clinicalPharmacyOrderWriteRequirement =
    AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.clinicalWrite,
        AppPermissions.pharmacyWrite,
        AppPermissions.systemAdmin,
      ],
      activeModules: <String>[clinicalEncountersVitalsModule],
    );

/// Admission request from clinical (prompt narrative ∪):
/// `clinical:write` | `operations:write` | `system:admin`.
const AccessRequirement clinicalAdmissionWriteRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.clinicalWrite,
    AppPermissions.operationsWrite,
    AppPermissions.systemAdmin,
  ],
  activeModules: <String>[clinicalEncountersVitalsModule],
);

/// Discharge planning financial-clearance / Open billing nested read.
///
/// Reuses [billingReadRequirement] (`billing:read` ∩ `billing-payments`) so
/// clinical atom maps and the discharge planning dialog share one gate.
const AccessRequirement clinicalDischargeFinancialReadRequirement =
    billingReadRequirement;

/// Follow-ups tab / panel read on clinical host (matrix ∩ `clinical:read`).
///
/// Shared [FollowUpWorklistPanel] defaults to reception ∪; clinical overrides
/// with this requirement (see Follow-ups tab permission scan).
const AccessRequirement clinicalFollowUpsRequirement =
    clinicalWorkspaceReadRequirement;

/// Follow-ups complete / reschedule — write source ∪.
const AccessRequirement clinicalFollowUpsWriteRequirement =
    clinicalWorkspaceWriteRequirement;

/// Per-section tab strip gate.
///
/// Worklist tabs share ∩ `clinical:read` + `encounters-vitals`; Follow-ups uses
/// [clinicalFollowUpsRequirement]. Returns each tab’s atom `tab` requirement so
/// strip filtering traces to the inventory maps (e.g. Urgent →
/// [ClinicalUrgentAtomPermissions.tab], Waiting review →
/// [ClinicalWaitingReviewAtomPermissions.tab]).
AccessRequirement clinicalSectionTabRequirement(
  ClinicalWorkspaceSection section,
) {
  return switch (section) {
    ClinicalWorkspaceSection.followUps => ClinicalFollowUpsAtomPermissions.tab,
    ClinicalWorkspaceSection.all => ClinicalAllAtomPermissions.tab,
    ClinicalWorkspaceSection.waitingReview =>
      ClinicalWaitingReviewAtomPermissions.tab,
    ClinicalWorkspaceSection.urgent => ClinicalUrgentAtomPermissions.tab,
    ClinicalWorkspaceSection.resultsReady =>
      ClinicalResultsReadyAtomPermissions.tab,
    ClinicalWorkspaceSection.inConsultation =>
      ClinicalInConsultationAtomPermissions.tab,
    ClinicalWorkspaceSection.completed => ClinicalCompletedAtomPermissions.tab,
  };
}

/// Alias used by Follow-ups host call sites.
AccessRequirement clinicalSectionRequirement(ClinicalWorkspaceSection section) {
  return clinicalSectionTabRequirement(section);
}

bool canEnterClinicalWorkspace(AppAccessPolicy policy) {
  return clinicalWorkspaceEntryRequirement.isAllowed(policy);
}

bool canReadClinical(AppAccessPolicy policy) {
  return clinicalWorkspaceReadRequirement.isAllowed(policy);
}

bool canWriteClinical(AppAccessPolicy policy) {
  return clinicalWorkspaceWriteRequirement.isAllowed(policy);
}

bool canWriteClinicalLabOrder(AppAccessPolicy policy) {
  return clinicalLabOrderWriteRequirement.isAllowed(policy);
}

bool canWriteClinicalRadiologyOrder(AppAccessPolicy policy) {
  return clinicalRadiologyOrderWriteRequirement.isAllowed(policy);
}

bool canWriteClinicalPharmacyOrder(AppAccessPolicy policy) {
  return clinicalPharmacyOrderWriteRequirement.isAllowed(policy);
}

bool canRequestClinicalAdmission(AppAccessPolicy policy) {
  return clinicalAdmissionWriteRequirement.isAllowed(policy);
}

bool canReadClinicalDischargeFinancial(AppAccessPolicy policy) {
  return clinicalDischargeFinancialReadRequirement.isAllowed(policy);
}

bool canReadClinicalFollowUps(AppAccessPolicy policy) {
  return clinicalFollowUpsRequirement.isAllowed(policy);
}

bool canWriteClinicalFollowUps(AppAccessPolicy policy) {
  return clinicalFollowUpsWriteRequirement.isAllowed(policy);
}

bool canViewClinicalSection(
  AppAccessPolicy policy,
  ClinicalWorkspaceSection section,
) {
  return clinicalSectionTabRequirement(section).isAllowed(policy);
}

/// Sections the user may open; empty when no clinical read (and Follow-ups).
List<ClinicalWorkspaceSection> clinicalAllowedSections(AppAccessPolicy policy) {
  return ClinicalWorkspaceSection.values
      .where(
        (ClinicalWorkspaceSection section) =>
            canViewClinicalSection(policy, section),
      )
      .toList(growable: false);
}

ClinicalWorkspaceSection? clinicalFallbackSection(AppAccessPolicy policy) {
  final List<ClinicalWorkspaceSection> allowed = clinicalAllowedSections(
    policy,
  );
  if (allowed.isEmpty) {
    return null;
  }
  if (allowed.contains(ClinicalWorkspaceSection.all)) {
    return ClinicalWorkspaceSection.all;
  }
  return allowed.first;
}

/// All tab atom → permission mapping (inventory + matrix).
///
/// Outpatient clinical worklist (`?section=all` or default). Matrix nested
/// write rows are _(n/a)_; prompt narrative ∪ helpers still gate lab /
/// radiology / pharmacy / admission. Discharge Open billing uses
/// [clinicalDischargeFinancialReadRequirement] (`billing:read` ∩
/// `billing-payments`); dialog host reuses billing read requirement.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | All tab / count badge | navigate | read ∩ `clinical:read` |
/// | Search / filters / columns / pagination | read chrome | read ∩ |
/// | Empty / error / retry / loading | read chrome | read ∩ |
/// | Success snackbar / validation (authorized) | visible feedback | write ∪ / form |
/// | Row select → encounter detail | read | read ∩ |
/// | Next action Review encounter | navigate / read | read ∩ |
/// | Next action RECORD_VITALS / disposition | create / update | write ∪ source |
/// | Next action WorkflowActionButton | navigate / write | registry requirement |
/// | Detail Add note / diagnosis / procedure / refer / follow-up | create | write ∪ source |
/// | Detail Record/Edit vitals / Disposition | create / update | write ∪ source |
/// | Detail Request lab (+ catalog / billing nested) | create / update | lab order ∪ |
/// | Detail Request radiology (+ catalog / billing) | create / update | radiology order ∪ |
/// | Detail Prescribe (+ medicine / billing nested) | create | pharmacy order ∪ |
/// | Detail Request procedure (+ Review billing) | create-charge | write ∪ + clinical-request-billing |
/// | Detail Request admission | create | admission ∪ |
/// | Detail Print summary | export / read | read ∩ |
/// | Lab / radiology / pharmacy order mutate | update / delete | nested order ∪ |
/// | Diagnosis delete | delete | write ∪ source |
/// | Discharge Open billing / financial | nested read | billing:read ∩ |
/// | Follow-ups strip tab | navigate | [clinicalFollowUpsRequirement] |
/// | Route entry (deep link) | navigate | [RouteAccessCatalog.clinicalEntry] ∩ `clinical:read` |
///
/// Write keeps source ∪ `clinical:write` | `system:admin` rather than matrix ∩
/// `clinical:write` alone. Nested order / admission rows document prompt ∪
/// (matrix nested write _(n/a)_). Prompt route entry ∪ (`clinical:read` |
/// `clinical:write`) and `AppRoutes.clinical` ∪ map to catalog ∩
/// `clinical:read` — keep catalog.
abstract final class ClinicalAllAtomPermissions {
  static const AccessRequirement tab = clinicalWorkspaceReadRequirement;
  static const AccessRequirement listChrome = clinicalWorkspaceReadRequirement;
  static const AccessRequirement search = clinicalWorkspaceReadRequirement;
  static const AccessRequirement filters = clinicalWorkspaceReadRequirement;
  static const AccessRequirement settings = clinicalWorkspaceReadRequirement;
  static const AccessRequirement pagination = clinicalWorkspaceReadRequirement;
  static const AccessRequirement empty = clinicalWorkspaceReadRequirement;
  static const AccessRequirement loading = clinicalWorkspaceReadRequirement;
  static const AccessRequirement retry = clinicalWorkspaceReadRequirement;
  /// Authorized success snackbar path (mutation entry already write-gated).
  static const AccessRequirement success = clinicalWorkspaceWriteRequirement;
  /// Authorized form validation feedback (nested write dialogs).
  static const AccessRequirement validation =
      clinicalWorkspaceWriteRequirement;
  static const AccessRequirement rowSelect = clinicalWorkspaceReadRequirement;
  static const AccessRequirement detail = clinicalWorkspaceReadRequirement;
  static const AccessRequirement nextActionReview =
      clinicalWorkspaceReadRequirement;
  static const AccessRequirement create = clinicalWorkspaceWriteRequirement;
  static const AccessRequirement update = clinicalWorkspaceWriteRequirement;
  static const AccessRequirement delete = clinicalWorkspaceWriteRequirement;
  static const AccessRequirement write = clinicalWorkspaceWriteRequirement;
  static const AccessRequirement addNote = clinicalWorkspaceWriteRequirement;
  static const AccessRequirement recordVitals =
      clinicalWorkspaceWriteRequirement;
  static const AccessRequirement addDiagnosis =
      clinicalWorkspaceWriteRequirement;
  static const AccessRequirement recordProcedure =
      clinicalWorkspaceWriteRequirement;
  static const AccessRequirement refer = clinicalWorkspaceWriteRequirement;
  static const AccessRequirement followUp = clinicalWorkspaceWriteRequirement;
  static const AccessRequirement disposition =
      clinicalWorkspaceWriteRequirement;
  static const AccessRequirement requestLab = clinicalLabOrderWriteRequirement;
  static const AccessRequirement requestRadiology =
      clinicalRadiologyOrderWriteRequirement;
  static const AccessRequirement prescribe =
      clinicalPharmacyOrderWriteRequirement;
  static const AccessRequirement requestAdmission =
      clinicalAdmissionWriteRequirement;
  static const AccessRequirement printSummary =
      clinicalWorkspaceReadRequirement;
  static const AccessRequirement nestedLabWrite =
      clinicalLabOrderWriteRequirement;
  static const AccessRequirement nestedRadiologyWrite =
      clinicalRadiologyOrderWriteRequirement;
  static const AccessRequirement nestedPharmacyWrite =
      clinicalPharmacyOrderWriteRequirement;
  static const AccessRequirement nestedWrite =
      clinicalWorkspaceWriteRequirement;
  static const AccessRequirement nestedRead = clinicalWorkspaceReadRequirement;
  static const AccessRequirement dischargeFinancialRead =
      clinicalDischargeFinancialReadRequirement;
  static const AccessRequirement followUpsTab = clinicalFollowUpsRequirement;
  static const AccessRequirement entry = clinicalWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = clinicalWorkspaceEntryRequirement;
}

bool canViewClinicalAll(AppAccessPolicy policy) {
  return ClinicalAllAtomPermissions.tab.isAllowed(policy);
}

/// Atom → requirement map for Clinical Follow-ups (`/clinical?section=follow-ups`).
///
/// Inventory: `screens/clinical.md` → Follow-ups tab (`FollowUpWorklistPanel`).
/// Nested encounter / lab / radiology / pharmacy / admission / discharge UI is
/// **not** reachable from this tab (matrix nested rows _(n/a)_). Shared panel
/// defaults remain reception ∪; clinical host overrides with these gates.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Follow-ups strip tab | navigate | read ∩ `clinical:read` + `encounters-vitals` |
/// | Search / clear / Settings / columns | read chrome | read ∩ |
/// | Empty / loading / error / retry | read chrome | read ∩ |
/// | Success snackbar / validation (authorized) | visible feedback | write ∪ / form |
/// | Row select → Follow-up details | read | read ∩ |
/// | Detail Close (read-only footer) | progressive disclosure | read ∩ |
/// | Reschedule follow-up | update | write ∪ source |
/// | Mark completed | update | write ∪ source |
/// | Save follow-up (nested reschedule dialog) | update | write ∪ source |
/// | Route entry (deep link) | navigate | catalog ∩ `clinical:read` |
///
/// Write keeps source ∪ `clinical:write` | `system:admin` rather than matrix ∩
/// `clinical:write` alone. Prompt route entry ∪ read|write → keep
/// [RouteAccessCatalog.clinicalEntry] (∩ `clinical:read`).
abstract final class ClinicalFollowUpsAtomPermissions {
  static const AccessRequirement tab = clinicalFollowUpsRequirement;
  static const AccessRequirement listChrome = clinicalFollowUpsRequirement;
  static const AccessRequirement search = clinicalFollowUpsRequirement;
  static const AccessRequirement settings = clinicalFollowUpsRequirement;
  static const AccessRequirement empty = clinicalFollowUpsRequirement;
  static const AccessRequirement loading = clinicalFollowUpsRequirement;
  static const AccessRequirement retry = clinicalFollowUpsRequirement;
  /// Authorized success path after complete / reschedule (write-gated entry).
  static const AccessRequirement success = clinicalFollowUpsWriteRequirement;
  /// Authorized form validation feedback (nested reschedule dialog).
  static const AccessRequirement validation =
      clinicalFollowUpsWriteRequirement;
  static const AccessRequirement rowSelect = clinicalFollowUpsRequirement;
  static const AccessRequirement detail = clinicalFollowUpsRequirement;
  static const AccessRequirement close = clinicalFollowUpsRequirement;
  static const AccessRequirement create = clinicalFollowUpsWriteRequirement;
  static const AccessRequirement update = clinicalFollowUpsWriteRequirement;
  static const AccessRequirement delete = clinicalFollowUpsWriteRequirement;
  static const AccessRequirement reschedule = clinicalFollowUpsWriteRequirement;
  static const AccessRequirement markCompleted =
      clinicalFollowUpsWriteRequirement;
  static const AccessRequirement saveFollowUp =
      clinicalFollowUpsWriteRequirement;
  static const AccessRequirement write = clinicalFollowUpsWriteRequirement;
  /// Nested cross-module write — not used on this tab (matrix _(n/a)_).
  static const AccessRequirement nestedWrite =
      clinicalFollowUpsWriteRequirement;
  static const AccessRequirement nestedRead = clinicalFollowUpsRequirement;
  static const AccessRequirement entry = clinicalWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = clinicalWorkspaceEntryRequirement;
}

/// Atom → requirement map for In consultation (`/clinical?section=in-consultation`).
///
/// Active outpatient consultation worklist (`screens/clinical.md`); richest
/// nested action bar (same encounter detail chrome as All). Matrix nested
/// write / read rows are _(n/a)_; prompt narrative ∪ helpers still gate lab /
/// radiology / pharmacy / admission. Discharge Open billing reuses
/// [clinicalDischargeFinancialReadRequirement] (`billing:read` ∩
/// `billing-payments`); dialog host reuses billing read requirement.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | In consultation tab / count badge | navigate | read ∩ `clinical:read` |
/// | Search / clear / Filters / columns / pagination | read chrome | read ∩ |
/// | Empty / error / retry / loading | read chrome | read ∩ |
/// | Success snackbar / validation (authorized) | visible feedback | write ∪ / form |
/// | Row select → encounter detail | read | read ∩ |
/// | Next action Review encounter | navigate / read | read ∩ |
/// | Next action RECORD_VITALS / disposition | create / update | write ∪ source |
/// | Next action WorkflowActionButton | navigate / write | registry; absent if denied |
/// | Detail Add note / diagnosis / procedure / refer / follow-up | create | write ∪ source |
/// | Detail Record/Edit vitals / Disposition | create / update | write ∪ source |
/// | Detail Request lab (+ catalog / billing nested) | create / update | lab order ∪ |
/// | Detail Request radiology (+ catalog / billing) | create / update | radiology order ∪ |
/// | Detail Prescribe (+ medicine / billing nested) | create | pharmacy order ∪ |
/// | Detail Request admission | create | admission ∪ |
/// | Detail Print summary | export / read | read ∩ |
/// | Lab / radiology / pharmacy order mutate | update / delete | nested order ∪ |
/// | Diagnosis delete | delete | write ∪ source |
/// | Discharge Open billing / financial | nested read | billing:read ∩ |
/// | Route entry (deep link) | navigate | [RouteAccessCatalog.clinicalEntry] ∩ `clinical:read` |
///
/// Write keeps source ∪ `clinical:write` | `system:admin` rather than matrix ∩
/// `clinical:write` alone. Nested order / admission rows document prompt ∪
/// (matrix nested write _(n/a)_). Prompt route entry ∪ (`clinical:read` |
/// `clinical:write`) maps to catalog ∩ `clinical:read` — keep catalog.
abstract final class ClinicalInConsultationAtomPermissions {
  static const AccessRequirement tab = clinicalWorkspaceReadRequirement;
  static const AccessRequirement listChrome = clinicalWorkspaceReadRequirement;
  static const AccessRequirement search = clinicalWorkspaceReadRequirement;
  static const AccessRequirement filters = clinicalWorkspaceReadRequirement;
  static const AccessRequirement settings = clinicalWorkspaceReadRequirement;
  static const AccessRequirement pagination = clinicalWorkspaceReadRequirement;
  static const AccessRequirement empty = clinicalWorkspaceReadRequirement;
  static const AccessRequirement loading = clinicalWorkspaceReadRequirement;
  static const AccessRequirement retry = clinicalWorkspaceReadRequirement;
  /// Authorized success snackbar path (mutation entry already write-gated).
  static const AccessRequirement success = clinicalWorkspaceWriteRequirement;
  /// Authorized form validation feedback (nested write dialogs).
  static const AccessRequirement validation =
      clinicalWorkspaceWriteRequirement;
  static const AccessRequirement rowSelect = clinicalWorkspaceReadRequirement;
  static const AccessRequirement detail = clinicalWorkspaceReadRequirement;
  static const AccessRequirement nextActionReview =
      clinicalWorkspaceReadRequirement;
  static const AccessRequirement create = clinicalWorkspaceWriteRequirement;
  static const AccessRequirement update = clinicalWorkspaceWriteRequirement;
  static const AccessRequirement delete = clinicalWorkspaceWriteRequirement;
  static const AccessRequirement write = clinicalWorkspaceWriteRequirement;
  static const AccessRequirement addNote = clinicalWorkspaceWriteRequirement;
  static const AccessRequirement recordVitals =
      clinicalWorkspaceWriteRequirement;
  static const AccessRequirement addDiagnosis =
      clinicalWorkspaceWriteRequirement;
  static const AccessRequirement recordProcedure =
      clinicalWorkspaceWriteRequirement;
  static const AccessRequirement refer = clinicalWorkspaceWriteRequirement;
  static const AccessRequirement followUp = clinicalWorkspaceWriteRequirement;
  static const AccessRequirement disposition =
      clinicalWorkspaceWriteRequirement;
  static const AccessRequirement requestLab = clinicalLabOrderWriteRequirement;
  static const AccessRequirement requestRadiology =
      clinicalRadiologyOrderWriteRequirement;
  static const AccessRequirement prescribe =
      clinicalPharmacyOrderWriteRequirement;
  static const AccessRequirement requestAdmission =
      clinicalAdmissionWriteRequirement;
  static const AccessRequirement printSummary =
      clinicalWorkspaceReadRequirement;
  static const AccessRequirement nestedLabWrite =
      clinicalLabOrderWriteRequirement;
  static const AccessRequirement nestedRadiologyWrite =
      clinicalRadiologyOrderWriteRequirement;
  static const AccessRequirement nestedPharmacyWrite =
      clinicalPharmacyOrderWriteRequirement;
  static const AccessRequirement nestedWrite =
      clinicalWorkspaceWriteRequirement;
  static const AccessRequirement nestedRead = clinicalWorkspaceReadRequirement;
  static const AccessRequirement dischargeFinancialRead =
      clinicalDischargeFinancialReadRequirement;
  static const AccessRequirement entry = clinicalWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = clinicalWorkspaceEntryRequirement;
}

bool canViewClinicalInConsultation(AppAccessPolicy policy) {
  return ClinicalInConsultationAtomPermissions.tab.isAllowed(policy);
}

/// Results ready tab atom → permission mapping (inventory + matrix).
///
/// Worklist `?section=results-ready` (`screens/clinical.md`). Same outpatient
/// encounter chrome as All; distinctive surfaces are results-ready chips,
/// Results timeline, and lab / radiology order panels. Prompt context names
/// lab:read / radiology:read **domain** panels; matrix nested cross-module
/// read is _(n/a)_, so panel **read** stays ∩ `clinical:read` (+
/// `encounters-vitals`) — not a separate `lab:read` / `radiology:read` gate.
/// Nested **writes** use prompt narrative ∪ helpers (matrix nested write
/// _(n/a)_): lab / radiology / pharmacy / admission.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Results ready tab / count badge | navigate | read ∩ `clinical:read` |
/// | Search / filters / columns / pagination | read chrome | read ∩ |
/// | Results-ready summary chip / badge | read | read ∩ |
/// | Empty / error / retry / loading | read chrome | read ∩ |
/// | Success snackbar / validation (authorized) | visible feedback | write ∪ / form |
/// | Row select → encounter detail | read | read ∩ |
/// | Next action Review encounter / REVIEW_RESULTS | navigate / read | read ∩ |
/// | Next action RECORD_VITALS / disposition | create / update | write ∪ source |
/// | Next action WorkflowActionButton | navigate / write | registry; absent if denied |
/// | Detail Results timeline (lab rows) | read | [labResultsPanel] |
/// | Detail Results timeline (imaging rows) | read | [radiologyResultsPanel] |
/// | Detail Lab orders panel (data) | read | [labResultsPanel] |
/// | Detail Radiology orders panel (data) | read | [radiologyResultsPanel] |
/// | Detail Pharmacy orders / diagnoses panels | read | nestedRead ∩ |
/// | Detail Add note / diagnosis / procedure / refer / follow-up | create | write ∪ source |
/// | Detail Record/Edit vitals / Disposition | create / update | write ∪ source |
/// | Detail Request lab (+ catalog / billing nested) | create / update | lab order ∪ |
/// | Detail Request radiology (+ catalog / billing) | create / update | radiology order ∪ |
/// | Detail Prescribe (+ medicine / billing nested) | create | pharmacy order ∪ |
/// | Detail Request admission | create | admission ∪ |
/// | Detail Print summary | export / read | read ∩ |
/// | Lab / radiology / pharmacy order mutate | update / delete | nested order ∪ |
/// | Diagnosis delete | delete | write ∪ source |
/// | Discharge Open billing / financial | nested read | billing:read ∩ |
/// | Route entry (deep link) | navigate | [RouteAccessCatalog.clinicalEntry] ∩ `clinical:read` |
///
/// Write keeps source ∪ `clinical:write` | `system:admin` rather than matrix ∩
/// `clinical:write` alone. Nested order / admission rows document prompt ∪
/// (matrix nested write _(n/a)_). Prompt route entry ∪ (`clinical:read` |
/// `clinical:write`) maps to catalog ∩ `clinical:read` — keep catalog.
abstract final class ClinicalResultsReadyAtomPermissions {
  static const AccessRequirement tab = clinicalWorkspaceReadRequirement;
  static const AccessRequirement listChrome = clinicalWorkspaceReadRequirement;
  static const AccessRequirement search = clinicalWorkspaceReadRequirement;
  static const AccessRequirement filters = clinicalWorkspaceReadRequirement;
  static const AccessRequirement settings = clinicalWorkspaceReadRequirement;
  static const AccessRequirement pagination = clinicalWorkspaceReadRequirement;
  static const AccessRequirement resultsReadyChip =
      clinicalWorkspaceReadRequirement;
  static const AccessRequirement empty = clinicalWorkspaceReadRequirement;
  static const AccessRequirement loading = clinicalWorkspaceReadRequirement;
  static const AccessRequirement retry = clinicalWorkspaceReadRequirement;
  /// Authorized success snackbar path (mutation entry already write-gated).
  static const AccessRequirement success = clinicalWorkspaceWriteRequirement;
  /// Authorized form validation feedback (nested write dialogs).
  static const AccessRequirement validation =
      clinicalWorkspaceWriteRequirement;
  static const AccessRequirement rowSelect = clinicalWorkspaceReadRequirement;
  static const AccessRequirement detail = clinicalWorkspaceReadRequirement;
  static const AccessRequirement nextActionReview =
      clinicalWorkspaceReadRequirement;
  static const AccessRequirement resultsTimeline =
      clinicalWorkspaceReadRequirement;
  /// Lab-domain results / orders panel (context lab:read; matrix nested read n/a → clinical:read).
  static const AccessRequirement labResultsPanel =
      clinicalWorkspaceReadRequirement;
  /// Imaging-domain results / orders panel (context radiology:read; nested n/a → clinical:read).
  static const AccessRequirement radiologyResultsPanel =
      clinicalWorkspaceReadRequirement;
  static const AccessRequirement create = clinicalWorkspaceWriteRequirement;
  static const AccessRequirement update = clinicalWorkspaceWriteRequirement;
  static const AccessRequirement delete = clinicalWorkspaceWriteRequirement;
  static const AccessRequirement write = clinicalWorkspaceWriteRequirement;
  static const AccessRequirement addNote = clinicalWorkspaceWriteRequirement;
  static const AccessRequirement recordVitals =
      clinicalWorkspaceWriteRequirement;
  static const AccessRequirement addDiagnosis =
      clinicalWorkspaceWriteRequirement;
  static const AccessRequirement recordProcedure =
      clinicalWorkspaceWriteRequirement;
  static const AccessRequirement refer = clinicalWorkspaceWriteRequirement;
  static const AccessRequirement followUp = clinicalWorkspaceWriteRequirement;
  static const AccessRequirement disposition =
      clinicalWorkspaceWriteRequirement;
  static const AccessRequirement requestLab = clinicalLabOrderWriteRequirement;
  static const AccessRequirement requestRadiology =
      clinicalRadiologyOrderWriteRequirement;
  static const AccessRequirement prescribe =
      clinicalPharmacyOrderWriteRequirement;
  static const AccessRequirement requestAdmission =
      clinicalAdmissionWriteRequirement;
  static const AccessRequirement printSummary =
      clinicalWorkspaceReadRequirement;
  static const AccessRequirement nestedLabWrite =
      clinicalLabOrderWriteRequirement;
  static const AccessRequirement nestedRadiologyWrite =
      clinicalRadiologyOrderWriteRequirement;
  static const AccessRequirement nestedPharmacyWrite =
      clinicalPharmacyOrderWriteRequirement;
  static const AccessRequirement nestedWrite =
      clinicalWorkspaceWriteRequirement;
  static const AccessRequirement nestedRead = clinicalWorkspaceReadRequirement;
  static const AccessRequirement dischargeFinancialRead =
      clinicalDischargeFinancialReadRequirement;
  static const AccessRequirement entry = clinicalWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = clinicalWorkspaceEntryRequirement;
}

bool canViewClinicalResultsReady(AppAccessPolicy policy) {
  return ClinicalResultsReadyAtomPermissions.tab.isAllowed(policy);
}

bool canViewClinicalLabResultsPanel(AppAccessPolicy policy) {
  return ClinicalResultsReadyAtomPermissions.labResultsPanel.isAllowed(policy);
}

bool canViewClinicalRadiologyResultsPanel(AppAccessPolicy policy) {
  return ClinicalResultsReadyAtomPermissions.radiologyResultsPanel.isAllowed(
    policy,
  );
}

/// Atom → requirement map for Urgent (`/clinical?section=urgent`).
///
/// Urgent outpatient encounters (`isUrgent` + non-terminal). Same encounter
/// chrome as All / In consultation; distinctive surfaces are the Urgent tab
/// (danger count tone) and Urgent summary chips on rows / detail. Matrix
/// nested write rows are _(n/a)_; prompt narrative ∪ helpers still gate lab /
/// radiology / pharmacy / admission. Discharge Open billing uses
/// [clinicalDischargeFinancialReadRequirement] (`billing:read` ∩
/// `billing-payments`).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Urgent tab / count badge | navigate | read ∩ `clinical:read` |
/// | Search / filters / columns / pagination | read chrome | read ∩ |
/// | Urgent summary chip / badge (row + detail) | read | read ∩ |
/// | Empty / error / retry / loading | read chrome | read ∩ |
/// | Success snackbar / validation (authorized) | visible feedback | write ∪ / form |
/// | Row select → encounter detail | read | read ∩ |
/// | Next action Review encounter | navigate / read | read ∩ |
/// | Next action RECORD_VITALS / disposition | create / update | write ∪ source |
/// | Next action WorkflowActionButton | navigate / write | registry; absent if denied |
/// | Detail Add note / diagnosis / procedure / refer / follow-up | create | write ∪ source |
/// | Detail Record/Edit vitals / Disposition | create / update | write ∪ source |
/// | Detail Request lab (+ catalog / billing nested) | create / update | lab order ∪ |
/// | Detail Request radiology (+ catalog / billing) | create / update | radiology order ∪ |
/// | Detail Prescribe (+ medicine / billing nested) | create | pharmacy order ∪ |
/// | Detail Request admission | create | admission ∪ |
/// | Detail Print summary | export / read | read ∩ |
/// | Lab / radiology / pharmacy order mutate | update / delete | nested order ∪ |
/// | Diagnosis delete | delete | write ∪ source |
/// | Discharge Open billing / financial | nested read | billing:read ∩ |
/// | Route entry (deep link) | navigate | [RouteAccessCatalog.clinicalEntry] ∩ `clinical:read` |
///
/// Write keeps source ∪ `clinical:write` | `system:admin` rather than matrix ∩
/// `clinical:write` alone. Nested order / admission rows document prompt ∪
/// (matrix nested write _(n/a)_). Prompt route entry ∪ (`clinical:read` |
/// `clinical:write`) and `AppRoutes.clinical` ∪ map to catalog ∩
/// `clinical:read` — keep catalog.
abstract final class ClinicalUrgentAtomPermissions {
  static const AccessRequirement tab = clinicalWorkspaceReadRequirement;
  static const AccessRequirement listChrome = clinicalWorkspaceReadRequirement;
  static const AccessRequirement search = clinicalWorkspaceReadRequirement;
  static const AccessRequirement filters = clinicalWorkspaceReadRequirement;
  static const AccessRequirement settings = clinicalWorkspaceReadRequirement;
  static const AccessRequirement pagination = clinicalWorkspaceReadRequirement;
  static const AccessRequirement urgentChip = clinicalWorkspaceReadRequirement;
  static const AccessRequirement empty = clinicalWorkspaceReadRequirement;
  static const AccessRequirement loading = clinicalWorkspaceReadRequirement;
  static const AccessRequirement retry = clinicalWorkspaceReadRequirement;
  /// Authorized success snackbar path (mutation entry already write-gated).
  static const AccessRequirement success = clinicalWorkspaceWriteRequirement;
  /// Authorized form validation feedback (nested write dialogs).
  static const AccessRequirement validation =
      clinicalWorkspaceWriteRequirement;
  static const AccessRequirement rowSelect = clinicalWorkspaceReadRequirement;
  static const AccessRequirement detail = clinicalWorkspaceReadRequirement;
  static const AccessRequirement nextActionReview =
      clinicalWorkspaceReadRequirement;
  static const AccessRequirement create = clinicalWorkspaceWriteRequirement;
  static const AccessRequirement update = clinicalWorkspaceWriteRequirement;
  static const AccessRequirement delete = clinicalWorkspaceWriteRequirement;
  static const AccessRequirement write = clinicalWorkspaceWriteRequirement;
  static const AccessRequirement addNote = clinicalWorkspaceWriteRequirement;
  static const AccessRequirement recordVitals =
      clinicalWorkspaceWriteRequirement;
  static const AccessRequirement addDiagnosis =
      clinicalWorkspaceWriteRequirement;
  static const AccessRequirement recordProcedure =
      clinicalWorkspaceWriteRequirement;
  static const AccessRequirement refer = clinicalWorkspaceWriteRequirement;
  static const AccessRequirement followUp = clinicalWorkspaceWriteRequirement;
  static const AccessRequirement disposition =
      clinicalWorkspaceWriteRequirement;
  static const AccessRequirement requestLab = clinicalLabOrderWriteRequirement;
  static const AccessRequirement requestRadiology =
      clinicalRadiologyOrderWriteRequirement;
  static const AccessRequirement requestAdmission =
      clinicalAdmissionWriteRequirement;
  static const AccessRequirement prescribe =
      clinicalPharmacyOrderWriteRequirement;
  static const AccessRequirement printSummary =
      clinicalWorkspaceReadRequirement;
  static const AccessRequirement nestedLabWrite =
      clinicalLabOrderWriteRequirement;
  static const AccessRequirement nestedRadiologyWrite =
      clinicalRadiologyOrderWriteRequirement;
  static const AccessRequirement nestedPharmacyWrite =
      clinicalPharmacyOrderWriteRequirement;
  static const AccessRequirement nestedWrite =
      clinicalWorkspaceWriteRequirement;
  static const AccessRequirement nestedRead = clinicalWorkspaceReadRequirement;
  static const AccessRequirement dischargeFinancialRead =
      clinicalDischargeFinancialReadRequirement;
  static const AccessRequirement entry = clinicalWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = clinicalWorkspaceEntryRequirement;
}

bool canViewClinicalUrgent(AppAccessPolicy policy) {
  return ClinicalUrgentAtomPermissions.tab.isAllowed(policy);
}

/// Atom → requirement map for Waiting review (`/clinical?section=waiting-review`).
///
/// Outpatient encounters awaiting clinician review (`WAITING_DOCTOR_REVIEW` /
/// review-stage aliases). Same encounter chrome as All / Urgent; distinctive
/// surfaces are the Waiting review tab (warning count tone) and review-stage
/// next actions (`DOCTOR_REVIEW` / Clinical notes). Matrix nested write rows
/// are _(n/a)_; prompt narrative ∪ helpers still gate lab / radiology /
/// pharmacy / admission. Discharge Open billing uses
/// [clinicalDischargeFinancialReadRequirement] (`billing:read` ∩
/// `billing-payments`).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Waiting review tab | navigate | read ∩ `clinical:read` |
/// | Search / filters / columns / pagination | read chrome | read ∩ |
/// | Waiting review tab count / summary badge | read | read ∩ |
/// | Empty / loading / error / retry | read chrome | read ∩ |
/// | Success snackbar / validation (authorized) | visible feedback | write ∪ / form |
/// | Row select → encounter detail | read | read ∩ |
/// | Next action Review encounter / DOCTOR_REVIEW | navigate / read | read ∩ |
/// | Next action RECORD_VITALS / disposition | create / update | write ∪ source |
/// | Next action WorkflowActionButton | navigate / write | registry; absent if denied |
/// | Detail Add note / diagnosis / procedure / refer / follow-up | create | write ∪ source |
/// | Detail Record/Edit vitals / Disposition | create / update | write ∪ source |
/// | Detail Request lab (+ catalog / billing nested) | create / update | lab order ∪ |
/// | Detail Request radiology (+ catalog / billing) | create / update | radiology order ∪ |
/// | Detail Prescribe (+ medicine / billing nested) | create | pharmacy order ∪ |
/// | Detail Request admission | create | admission ∪ |
/// | Detail Print summary | export / read | read ∩ |
/// | Lab / radiology / pharmacy order mutate | update / delete | nested order ∪ |
/// | Diagnosis delete | delete | write ∪ source |
/// | Discharge Open billing / financial | nested read | billing:read ∩ |
/// | Route entry (deep link) | navigate | [RouteAccessCatalog.clinicalEntry] ∩ `clinical:read` |
///
/// Write keeps source ∪ `clinical:write` | `system:admin` rather than matrix ∩
/// `clinical:write` alone. Nested order / admission rows document prompt ∪
/// (matrix nested write _(n/a)_). Prompt route entry ∪ (`clinical:read` |
/// `clinical:write`) maps to catalog ∩ `clinical:read` — keep catalog.
abstract final class ClinicalWaitingReviewAtomPermissions {
  static const AccessRequirement tab = clinicalWorkspaceReadRequirement;
  static const AccessRequirement listChrome = clinicalWorkspaceReadRequirement;
  static const AccessRequirement search = clinicalWorkspaceReadRequirement;
  static const AccessRequirement filters = clinicalWorkspaceReadRequirement;
  static const AccessRequirement settings = clinicalWorkspaceReadRequirement;
  static const AccessRequirement pagination = clinicalWorkspaceReadRequirement;
  static const AccessRequirement waitingReviewChip =
      clinicalWorkspaceReadRequirement;
  static const AccessRequirement empty = clinicalWorkspaceReadRequirement;
  static const AccessRequirement loading = clinicalWorkspaceReadRequirement;
  static const AccessRequirement retry = clinicalWorkspaceReadRequirement;
  /// Authorized success snackbar path (mutation entry already write-gated).
  static const AccessRequirement success = clinicalWorkspaceWriteRequirement;
  /// Authorized form validation feedback (nested write dialogs).
  static const AccessRequirement validation =
      clinicalWorkspaceWriteRequirement;
  static const AccessRequirement rowSelect = clinicalWorkspaceReadRequirement;
  static const AccessRequirement detail = clinicalWorkspaceReadRequirement;
  static const AccessRequirement nextActionReview =
      clinicalWorkspaceReadRequirement;
  static const AccessRequirement create = clinicalWorkspaceWriteRequirement;
  static const AccessRequirement update = clinicalWorkspaceWriteRequirement;
  static const AccessRequirement delete = clinicalWorkspaceWriteRequirement;
  static const AccessRequirement write = clinicalWorkspaceWriteRequirement;
  static const AccessRequirement addNote = clinicalWorkspaceWriteRequirement;
  static const AccessRequirement recordVitals =
      clinicalWorkspaceWriteRequirement;
  static const AccessRequirement addDiagnosis =
      clinicalWorkspaceWriteRequirement;
  static const AccessRequirement recordProcedure =
      clinicalWorkspaceWriteRequirement;
  static const AccessRequirement refer = clinicalWorkspaceWriteRequirement;
  static const AccessRequirement followUp = clinicalWorkspaceWriteRequirement;
  static const AccessRequirement disposition =
      clinicalWorkspaceWriteRequirement;
  static const AccessRequirement requestLab = clinicalLabOrderWriteRequirement;
  static const AccessRequirement requestRadiology =
      clinicalRadiologyOrderWriteRequirement;
  static const AccessRequirement prescribe =
      clinicalPharmacyOrderWriteRequirement;
  static const AccessRequirement requestAdmission =
      clinicalAdmissionWriteRequirement;
  static const AccessRequirement printSummary =
      clinicalWorkspaceReadRequirement;
  static const AccessRequirement nestedLabWrite =
      clinicalLabOrderWriteRequirement;
  static const AccessRequirement nestedRadiologyWrite =
      clinicalRadiologyOrderWriteRequirement;
  static const AccessRequirement nestedPharmacyWrite =
      clinicalPharmacyOrderWriteRequirement;
  static const AccessRequirement nestedWrite =
      clinicalWorkspaceWriteRequirement;
  static const AccessRequirement nestedRead = clinicalWorkspaceReadRequirement;
  static const AccessRequirement dischargeFinancialRead =
      clinicalDischargeFinancialReadRequirement;
  static const AccessRequirement entry = clinicalWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = clinicalWorkspaceEntryRequirement;
}

bool canViewClinicalWaitingReview(AppAccessPolicy policy) {
  return ClinicalWaitingReviewAtomPermissions.tab.isAllowed(policy);
}

/// Billing action classes for Clinical Waiting review tab inventory (Req 1).
enum ClinicalWaitingReviewFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBillable,
}

/// Financial atom reachable from Waiting review (`?section=waiting-review`).
final class ClinicalWaitingReviewFinancialAtom {
  const ClinicalWaitingReviewFinancialAtom({
    required this.id,
    required this.classification,
    this.auditReason,
    this.billingPath,
  });

  final String id;
  final ClinicalWaitingReviewFinancialClass classification;

  /// Explicit not-billable protocol when [classification] is notBillable.
  final String? auditReason;

  /// Shared Billing / clinical-request path when billable.
  final String? billingPath;
}

/// Canonical Waiting-review financial inventory (AC1).
///
/// Tab is a scoped outpatient worklist (`WAITING_DOCTOR_REVIEW` / review-stage
/// aliases) over the same encounter detail chrome as All/Urgent. Billable
/// atoms reuse clinical-request billing + Billing module; cashier collect /
/// issue / adjust stay on Billing (pay-now only via request billing panel when
/// `billing:write`). Consult-on-review and follow-up visit fees are not mounted
/// here (`NOT_BILLED` / unmounted create-charge docs).
const List<ClinicalWaitingReviewFinancialAtom>
clinicalWaitingReviewFinancialInventory =
    <ClinicalWaitingReviewFinancialAtom>[
      ClinicalWaitingReviewFinancialAtom(
        id: 'tab_chrome',
        classification: ClinicalWaitingReviewFinancialClass.notBillable,
        auditReason: 'NOT_REQUIRED',
      ),
      ClinicalWaitingReviewFinancialAtom(
        id: 'search_filters_pagination',
        classification: ClinicalWaitingReviewFinancialClass.notBillable,
        auditReason: 'NOT_REQUIRED',
      ),
      ClinicalWaitingReviewFinancialAtom(
        id: 'waiting_review_count_chip',
        classification: ClinicalWaitingReviewFinancialClass.notBillable,
        auditReason: 'NOT_REQUIRED',
      ),
      ClinicalWaitingReviewFinancialAtom(
        id: 'empty_loading_error_retry',
        classification: ClinicalWaitingReviewFinancialClass.notBillable,
        auditReason: 'NOT_REQUIRED',
      ),
      ClinicalWaitingReviewFinancialAtom(
        id: 'row_select_open_encounter',
        classification: ClinicalWaitingReviewFinancialClass.notBillable,
        auditReason: 'NOT_REQUIRED',
      ),
      ClinicalWaitingReviewFinancialAtom(
        id: 'next_action_doctor_review',
        classification: ClinicalWaitingReviewFinancialClass.notBillable,
        auditReason: 'NOT_REQUIRED',
      ),
      ClinicalWaitingReviewFinancialAtom(
        id: 'next_action_record_vitals',
        classification: ClinicalWaitingReviewFinancialClass.notBillable,
        auditReason: 'NOT_BILLED',
      ),
      ClinicalWaitingReviewFinancialAtom(
        id: 'next_action_disposition',
        classification: ClinicalWaitingReviewFinancialClass.notBillable,
        auditReason: 'NOT_BILLED',
      ),
      ClinicalWaitingReviewFinancialAtom(
        id: 'results_chronology',
        classification: ClinicalWaitingReviewFinancialClass.notBillable,
        auditReason: 'NOT_REQUIRED',
      ),
      ClinicalWaitingReviewFinancialAtom(
        id: 'print_summary',
        classification: ClinicalWaitingReviewFinancialClass.notBillable,
        auditReason: 'NOT_REQUIRED',
      ),
      ClinicalWaitingReviewFinancialAtom(
        id: 'add_note',
        classification: ClinicalWaitingReviewFinancialClass.notBillable,
        auditReason: 'NOT_BILLED',
      ),
      ClinicalWaitingReviewFinancialAtom(
        id: 'add_diagnosis',
        classification: ClinicalWaitingReviewFinancialClass.notBillable,
        auditReason: 'NOT_BILLED',
      ),
      ClinicalWaitingReviewFinancialAtom(
        id: 'refer',
        classification: ClinicalWaitingReviewFinancialClass.notBillable,
        auditReason: 'NOT_BILLED',
      ),
      ClinicalWaitingReviewFinancialAtom(
        id: 'follow_up',
        classification: ClinicalWaitingReviewFinancialClass.notBillable,
        auditReason: 'NOT_BILLED',
      ),
      ClinicalWaitingReviewFinancialAtom(
        id: 'record_vitals',
        classification: ClinicalWaitingReviewFinancialClass.notBillable,
        auditReason: 'NOT_BILLED',
      ),
      ClinicalWaitingReviewFinancialAtom(
        id: 'disposition',
        classification: ClinicalWaitingReviewFinancialClass.notBillable,
        auditReason: 'NOT_BILLED',
      ),
      ClinicalWaitingReviewFinancialAtom(
        id: 'consult_charge_on_doctor_review',
        classification: ClinicalWaitingReviewFinancialClass.notBillable,
        auditReason: 'NOT_BILLED',
      ),
      ClinicalWaitingReviewFinancialAtom(
        id: 'request_lab',
        classification: ClinicalWaitingReviewFinancialClass.createCharge,
        billingPath: 'clinical-request-billing/lab-order',
      ),
      ClinicalWaitingReviewFinancialAtom(
        id: 'request_lab_pay_now',
        classification: ClinicalWaitingReviewFinancialClass.settle,
        billingPath: 'clinical-request-billing/receive-payment',
      ),
      ClinicalWaitingReviewFinancialAtom(
        id: 'cancel_lab_order',
        classification: ClinicalWaitingReviewFinancialClass.reverse,
        billingPath: 'clinical-request-billing/reverse',
      ),
      ClinicalWaitingReviewFinancialAtom(
        id: 'request_radiology',
        classification: ClinicalWaitingReviewFinancialClass.createCharge,
        billingPath: 'clinical-request-billing/radiology-order',
      ),
      ClinicalWaitingReviewFinancialAtom(
        id: 'request_radiology_pay_now',
        classification: ClinicalWaitingReviewFinancialClass.settle,
        billingPath: 'clinical-request-billing/receive-payment',
      ),
      ClinicalWaitingReviewFinancialAtom(
        id: 'cancel_radiology_order',
        classification: ClinicalWaitingReviewFinancialClass.reverse,
        billingPath: 'clinical-request-billing/reverse',
      ),
      ClinicalWaitingReviewFinancialAtom(
        id: 'prescribe',
        classification: ClinicalWaitingReviewFinancialClass.createCharge,
        billingPath: 'clinical-request-billing/pharmacy-order',
      ),
      ClinicalWaitingReviewFinancialAtom(
        id: 'prescribe_pay_now',
        classification: ClinicalWaitingReviewFinancialClass.settle,
        billingPath: 'clinical-request-billing/receive-payment',
      ),
      ClinicalWaitingReviewFinancialAtom(
        id: 'cancel_pharmacy_order',
        classification: ClinicalWaitingReviewFinancialClass.reverse,
        billingPath: 'clinical-request-billing/reverse',
      ),
      ClinicalWaitingReviewFinancialAtom(
        id: 'request_procedure',
        classification: ClinicalWaitingReviewFinancialClass.createCharge,
        billingPath: 'clinical-request-billing/procedure',
      ),
      ClinicalWaitingReviewFinancialAtom(
        id: 'request_procedure_pay_now',
        classification: ClinicalWaitingReviewFinancialClass.settle,
        billingPath: 'clinical-request-billing/receive-payment',
      ),
      ClinicalWaitingReviewFinancialAtom(
        id: 'request_admission',
        classification: ClinicalWaitingReviewFinancialClass.defer,
        billingPath: 'clinical-request-billing/admission-on-start',
        auditReason: 'NOT_REQUIRED',
      ),
      ClinicalWaitingReviewFinancialAtom(
        id: 'discharge_open_billing',
        classification: ClinicalWaitingReviewFinancialClass.notBillable,
        auditReason: 'NOT_REQUIRED',
      ),
    ];

/// Billable Waiting-review atoms must point at shared clinical-request Billing.
bool clinicalWaitingReviewBillableAtomsUseSharedBilling() {
  return clinicalWaitingReviewFinancialInventory
      .where(
        (ClinicalWaitingReviewFinancialAtom atom) =>
            atom.classification !=
            ClinicalWaitingReviewFinancialClass.notBillable,
      )
      .every(
        (ClinicalWaitingReviewFinancialAtom atom) =>
            atom.billingPath != null &&
            atom.billingPath!.startsWith('clinical-request-billing'),
      );
}

/// Completed tab atom → permission mapping (inventory + matrix).
///
/// Same-day terminal outpatient encounters (`?section=completed`). Prefer
/// read; reopen / mutations need write. No dedicated reopen control in
/// `screens/clinical.md` — [reopen] maps post-completion encounter write
/// mutations (notes / orders / diagnoses). Vitals and disposition stay
/// non-terminal-only (hidden for completed rows). Matrix nested write rows
/// are _(n/a)_; prompt narrative ∪ helpers still gate lab / radiology /
/// pharmacy / admission. Discharge Open billing uses
/// [clinicalDischargeFinancialReadRequirement] (`billing:read` ∩
/// `billing-payments`).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Completed tab / count badge | navigate | read ∩ `clinical:read` |
/// | Search / filters / columns / pagination | read chrome | read ∩ |
/// | Completed tab count / summary chip | read | read ∩ |
/// | Empty / error / retry / loading | read chrome | read ∩ |
/// | Success snackbar / validation (authorized) | visible feedback | write ∪ / form |
/// | Row select → encounter detail | read | read ∩ |
/// | Next action Review encounter | navigate / read | read ∩ |
/// | Next action WorkflowActionButton | navigate / write | registry; absent if denied |
/// | Next action RECORD_VITALS / disposition | create / update | write ∪ (non-terminal; N/A here) |
/// | Detail Add note / diagnosis / procedure / refer / follow-up | create | write ∪ source ([reopen]) |
/// | Detail Record/Edit vitals / Disposition | create / update | write ∪ (non-terminal; absent) |
/// | Detail Request lab (+ catalog / billing nested) | create / update | lab order ∪ |
/// | Detail Request radiology (+ catalog / billing) | create / update | radiology order ∪ |
/// | Detail Prescribe (+ medicine / billing nested) | create | pharmacy order ∪ |
/// | Detail Request admission | create | admission ∪ |
/// | Detail Print summary | export / read | read ∩ |
/// | Lab / radiology / pharmacy order mutate | update / delete | nested order ∪ |
/// | Diagnosis delete | delete | write ∪ source |
/// | Discharge Open billing / financial | nested read | billing:read ∩ |
/// | Route entry (deep link) | navigate | [RouteAccessCatalog.clinicalEntry] ∩ `clinical:read` |
///
/// Write keeps source ∪ `clinical:write` | `system:admin` rather than matrix ∩
/// `clinical:write` alone. Nested order / admission rows document prompt
/// narrative ∪ (matrix nested write _(n/a)_). Prompt route entry ∪
/// (`clinical:read` | `clinical:write`) maps to catalog ∩ `clinical:read` —
/// keep catalog.
abstract final class ClinicalCompletedAtomPermissions {
  static const AccessRequirement tab = clinicalWorkspaceReadRequirement;
  static const AccessRequirement listChrome = clinicalWorkspaceReadRequirement;
  static const AccessRequirement search = clinicalWorkspaceReadRequirement;
  static const AccessRequirement filters = clinicalWorkspaceReadRequirement;
  static const AccessRequirement settings = clinicalWorkspaceReadRequirement;
  static const AccessRequirement pagination = clinicalWorkspaceReadRequirement;
  static const AccessRequirement completedChip = clinicalWorkspaceReadRequirement;
  static const AccessRequirement empty = clinicalWorkspaceReadRequirement;
  static const AccessRequirement loading = clinicalWorkspaceReadRequirement;
  static const AccessRequirement retry = clinicalWorkspaceReadRequirement;
  /// Authorized success snackbar path (mutation entry already write-gated).
  static const AccessRequirement success = clinicalWorkspaceWriteRequirement;
  /// Authorized form validation feedback (nested write dialogs).
  static const AccessRequirement validation =
      clinicalWorkspaceWriteRequirement;
  static const AccessRequirement rowSelect = clinicalWorkspaceReadRequirement;
  static const AccessRequirement detail = clinicalWorkspaceReadRequirement;
  static const AccessRequirement openEncounter =
      clinicalWorkspaceReadRequirement;
  static const AccessRequirement nextActionReview =
      clinicalWorkspaceReadRequirement;
  static const AccessRequirement create = clinicalWorkspaceWriteRequirement;
  static const AccessRequirement update = clinicalWorkspaceWriteRequirement;
  static const AccessRequirement delete = clinicalWorkspaceWriteRequirement;
  static const AccessRequirement write = clinicalWorkspaceWriteRequirement;
  /// Post-completion encounter mutations (no dedicated reopen control).
  static const AccessRequirement reopen = clinicalWorkspaceWriteRequirement;
  static const AccessRequirement addNote = clinicalWorkspaceWriteRequirement;
  static const AccessRequirement recordVitals =
      clinicalWorkspaceWriteRequirement;
  static const AccessRequirement addDiagnosis =
      clinicalWorkspaceWriteRequirement;
  static const AccessRequirement recordProcedure =
      clinicalWorkspaceWriteRequirement;
  static const AccessRequirement refer = clinicalWorkspaceWriteRequirement;
  static const AccessRequirement followUp = clinicalWorkspaceWriteRequirement;
  static const AccessRequirement disposition =
      clinicalWorkspaceWriteRequirement;
  static const AccessRequirement requestLab = clinicalLabOrderWriteRequirement;
  static const AccessRequirement requestRadiology =
      clinicalRadiologyOrderWriteRequirement;
  static const AccessRequirement prescribe =
      clinicalPharmacyOrderWriteRequirement;
  static const AccessRequirement requestAdmission =
      clinicalAdmissionWriteRequirement;
  static const AccessRequirement printSummary =
      clinicalWorkspaceReadRequirement;
  static const AccessRequirement nestedLabWrite =
      clinicalLabOrderWriteRequirement;
  static const AccessRequirement nestedRadiologyWrite =
      clinicalRadiologyOrderWriteRequirement;
  static const AccessRequirement nestedPharmacyWrite =
      clinicalPharmacyOrderWriteRequirement;
  static const AccessRequirement nestedWrite =
      clinicalWorkspaceWriteRequirement;
  static const AccessRequirement nestedRead = clinicalWorkspaceReadRequirement;
  static const AccessRequirement dischargeFinancialRead =
      clinicalDischargeFinancialReadRequirement;
  static const AccessRequirement entry = clinicalWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = clinicalWorkspaceEntryRequirement;
}

bool canViewClinicalCompleted(AppAccessPolicy policy) {
  return ClinicalCompletedAtomPermissions.tab.isAllowed(policy);
}

/// Billing action classes for Clinical Completed tab inventory (Req 1).
enum ClinicalCompletedFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBillable,
}

/// Financial atom reachable from Clinical Completed (`?section=completed`).
final class ClinicalCompletedFinancialAtom {
  const ClinicalCompletedFinancialAtom({
    required this.id,
    required this.classification,
    this.auditReason,
    this.billingPath,
  });

  final String id;
  final ClinicalCompletedFinancialClass classification;

  /// Explicit not-billable protocol when [classification] is notBillable.
  final String? auditReason;

  /// Shared Billing / clinical-request path when billable.
  final String? billingPath;
}

/// Canonical Completed-tab financial inventory (AC1). Billable atoms reuse
/// clinical-request billing + Billing module; no parallel ledgers.
const List<ClinicalCompletedFinancialAtom> clinicalCompletedFinancialInventory =
    <ClinicalCompletedFinancialAtom>[
      ClinicalCompletedFinancialAtom(
        id: 'tab_chrome',
        classification: ClinicalCompletedFinancialClass.notBillable,
        auditReason: 'NOT_REQUIRED',
      ),
      ClinicalCompletedFinancialAtom(
        id: 'search_filters_pagination',
        classification: ClinicalCompletedFinancialClass.notBillable,
        auditReason: 'NOT_REQUIRED',
      ),
      ClinicalCompletedFinancialAtom(
        id: 'row_select_open_encounter',
        classification: ClinicalCompletedFinancialClass.notBillable,
        auditReason: 'NOT_REQUIRED',
      ),
      ClinicalCompletedFinancialAtom(
        id: 'print_summary',
        classification: ClinicalCompletedFinancialClass.notBillable,
        auditReason: 'NOT_REQUIRED',
      ),
      ClinicalCompletedFinancialAtom(
        id: 'add_note',
        classification: ClinicalCompletedFinancialClass.notBillable,
        auditReason: 'NOT_REQUIRED',
      ),
      ClinicalCompletedFinancialAtom(
        id: 'add_diagnosis',
        classification: ClinicalCompletedFinancialClass.notBillable,
        auditReason: 'NOT_REQUIRED',
      ),
      ClinicalCompletedFinancialAtom(
        id: 'refer',
        classification: ClinicalCompletedFinancialClass.notBillable,
        auditReason: 'NOT_REQUIRED',
      ),
      ClinicalCompletedFinancialAtom(
        id: 'follow_up',
        classification: ClinicalCompletedFinancialClass.notBillable,
        auditReason: 'NOT_REQUIRED',
      ),
      ClinicalCompletedFinancialAtom(
        id: 'record_vitals',
        classification: ClinicalCompletedFinancialClass.notBillable,
        auditReason: 'NOT_REQUIRED',
      ),
      ClinicalCompletedFinancialAtom(
        id: 'disposition',
        classification: ClinicalCompletedFinancialClass.notBillable,
        auditReason: 'NOT_REQUIRED',
      ),
      ClinicalCompletedFinancialAtom(
        id: 'request_lab',
        classification: ClinicalCompletedFinancialClass.createCharge,
        billingPath: 'clinical-request-billing/lab-order',
      ),
      ClinicalCompletedFinancialAtom(
        id: 'request_lab_pay_now',
        classification: ClinicalCompletedFinancialClass.settle,
        billingPath: 'clinical-request-billing/receive-payment',
      ),
      ClinicalCompletedFinancialAtom(
        id: 'cancel_lab_order',
        classification: ClinicalCompletedFinancialClass.reverse,
        billingPath: 'clinical-request-billing/reverse',
      ),
      ClinicalCompletedFinancialAtom(
        id: 'request_radiology',
        classification: ClinicalCompletedFinancialClass.createCharge,
        billingPath: 'clinical-request-billing/radiology-order',
      ),
      ClinicalCompletedFinancialAtom(
        id: 'request_radiology_pay_now',
        classification: ClinicalCompletedFinancialClass.settle,
        billingPath: 'clinical-request-billing/receive-payment',
      ),
      ClinicalCompletedFinancialAtom(
        id: 'cancel_radiology_order',
        classification: ClinicalCompletedFinancialClass.reverse,
        billingPath: 'clinical-request-billing/reverse',
      ),
      ClinicalCompletedFinancialAtom(
        id: 'prescribe',
        classification: ClinicalCompletedFinancialClass.createCharge,
        billingPath: 'clinical-request-billing/pharmacy-order',
      ),
      ClinicalCompletedFinancialAtom(
        id: 'prescribe_pay_now',
        classification: ClinicalCompletedFinancialClass.settle,
        billingPath: 'clinical-request-billing/receive-payment',
      ),
      ClinicalCompletedFinancialAtom(
        id: 'cancel_pharmacy_order',
        classification: ClinicalCompletedFinancialClass.reverse,
        billingPath: 'clinical-request-billing/reverse',
      ),
      ClinicalCompletedFinancialAtom(
        id: 'request_procedure',
        classification: ClinicalCompletedFinancialClass.createCharge,
        billingPath: 'clinical-request-billing/procedure',
      ),
      ClinicalCompletedFinancialAtom(
        id: 'request_procedure_pay_now',
        classification: ClinicalCompletedFinancialClass.settle,
        billingPath: 'clinical-request-billing/receive-payment',
      ),
      ClinicalCompletedFinancialAtom(
        id: 'request_admission',
        classification: ClinicalCompletedFinancialClass.defer,
        billingPath: 'clinical-request-billing/admission-on-start',
        auditReason: 'NOT_REQUIRED',
      ),
      ClinicalCompletedFinancialAtom(
        id: 'discharge_open_billing',
        classification: ClinicalCompletedFinancialClass.notBillable,
        auditReason: 'NOT_REQUIRED',
      ),
    ];

bool clinicalCompletedBillableAtomsUseSharedBilling() {
  return clinicalCompletedFinancialInventory
      .where(
        (ClinicalCompletedFinancialAtom atom) =>
            atom.classification != ClinicalCompletedFinancialClass.notBillable,
      )
      .every(
        (ClinicalCompletedFinancialAtom atom) =>
            atom.billingPath != null &&
            atom.billingPath!.startsWith('clinical-request-billing'),
      );
}
