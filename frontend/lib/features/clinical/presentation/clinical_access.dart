import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
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

/// Route entry (∪): `clinical:read` | `clinical:write` — matches
/// [AppRoutes.clinical] `requiredAnyPermissions`.
const AccessRequirement clinicalWorkspaceEntryRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.clinicalRead,
    AppPermissions.clinicalWrite,
  ],
  activeModules: <String>[clinicalEncountersVitalsModule],
);

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
const AccessRequirement clinicalDischargeFinancialReadRequirement =
    AccessRequirement(
      allPermissions: <AppPermission>[AppPermissions.billingRead],
      activeModules: <String>['billing-payments'],
    );

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
AccessRequirement clinicalSectionTabRequirement(
  ClinicalWorkspaceSection section,
) {
  return switch (section) {
    ClinicalWorkspaceSection.followUps => clinicalFollowUpsRequirement,
    _ => clinicalWorkspaceReadRequirement,
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
  if (section.isFollowUps) {
    return canReadClinicalFollowUps(policy);
  }
  // Non–Follow-ups tabs stay available for users who already reached the
  // workspace. Other tab scans may tighten [clinicalSectionTabRequirement]
  // in page chrome separately.
  return true;
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
/// Outpatient clinical worklist (`?section=all` or default). Nested order
/// writes use prompt narrative ∪ helpers rather than matrix nested _(n/a)_.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | All tab | navigate | read ∩ `clinical:read` |
/// | Search / filters / columns / pagination | read chrome | read ∩ |
/// | Empty / error / retry | read chrome | read ∩ |
/// | Row select → encounter detail | read | read ∩ |
/// | Next action Review encounter | navigate / read | read ∩ |
/// | Next action RECORD_VITALS / disposition | create / update | write ∪ source |
/// | Next action WorkflowActionButton | navigate / write | registry requirement |
/// | Detail Add note / diagnosis / procedure / refer / follow-up | create | write ∪ source |
/// | Detail Record/Edit vitals / Disposition | create / update | write ∪ source |
/// | Detail Request lab | create / update | lab order ∪ |
/// | Detail Request radiology | create / update | radiology order ∪ |
/// | Detail Prescribe | create | pharmacy order ∪ |
/// | Detail Request admission | create | admission ∪ |
/// | Detail Print summary | export / read | read ∩ |
/// | Lab / radiology / pharmacy order mutate | update / delete | nested order ∪ |
/// | Diagnosis delete | delete | write ∪ source |
/// | Discharge Open billing / financial | nested read | billing:read ∩ |
/// | Follow-ups strip tab | navigate | [clinicalFollowUpsRequirement] |
/// | Route entry (deep link) | navigate | read ∪ write |
///
/// Write keeps source ∪ `clinical:write` | `system:admin` rather than matrix ∩
/// `clinical:write` alone. Nested order / admission rows document prompt ∪.
abstract final class ClinicalAllAtomPermissions {
  static const AccessRequirement tab = clinicalWorkspaceReadRequirement;
  static const AccessRequirement listChrome = clinicalWorkspaceReadRequirement;
  static const AccessRequirement detail = clinicalWorkspaceReadRequirement;
  static const AccessRequirement create = clinicalWorkspaceWriteRequirement;
  static const AccessRequirement update = clinicalWorkspaceWriteRequirement;
  static const AccessRequirement delete = clinicalWorkspaceWriteRequirement;
  static const AccessRequirement write = clinicalWorkspaceWriteRequirement;
  static const AccessRequirement addNote = clinicalWorkspaceWriteRequirement;
  static const AccessRequirement recordVitals = clinicalWorkspaceWriteRequirement;
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

/// Atom → requirement map for Clinical Follow-ups (`/clinical?section=follow-ups`).
abstract final class ClinicalFollowUpsAtomPermissions {
  static const AccessRequirement tab = clinicalFollowUpsRequirement;
  static const AccessRequirement listChrome = clinicalFollowUpsRequirement;
  static const AccessRequirement search = clinicalFollowUpsRequirement;
  static const AccessRequirement settings = clinicalFollowUpsRequirement;
  static const AccessRequirement rowSelect = clinicalFollowUpsRequirement;
  static const AccessRequirement detail = clinicalFollowUpsRequirement;
  static const AccessRequirement retry = clinicalFollowUpsRequirement;
  static const AccessRequirement reschedule = clinicalFollowUpsWriteRequirement;
  static const AccessRequirement markCompleted =
      clinicalFollowUpsWriteRequirement;
  static const AccessRequirement saveFollowUp =
      clinicalFollowUpsWriteRequirement;
  static const AccessRequirement write = clinicalFollowUpsWriteRequirement;
  static const AccessRequirement routeEntry = clinicalWorkspaceEntryRequirement;
}
