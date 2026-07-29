import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/physiotherapy/domain/entities/physiotherapy_entities.dart';

/// Module entitlement for the physiotherapy workspace route and queue tabs.
const String physiotherapyModule = 'physiotherapy';

/// View / read UI (matrix ∪): `clinical:read` | `patient:read` + module.
///
/// Billing-only route entry does **not** satisfy tab chrome — see [routeEntry].
/// Referrals intake may allow `patient:read` readers without write.
const AccessRequirement physiotherapyWorkspaceReadRequirement =
    AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.clinicalRead,
        AppPermissions.patientRead,
      ],
      activeModules: <String>[physiotherapyModule],
    );

/// Alias used by tab atom maps / prompts.
const AccessRequirement physiotherapyReadRequirement =
    physiotherapyWorkspaceReadRequirement;

/// Route entry — [RouteAccessCatalog.physiotherapyEntry] matches
/// [AppRoutes.physiotherapy] ∪ `clinical:read` | `clinical:write` |
/// `patient:read` | `billing:read` + module. Matrix Active-plans chrome still
/// uses [physiotherapyWorkspaceReadRequirement] (no `billing:read` alone).
const AccessRequirement physiotherapyWorkspaceEntryRequirement =
    RouteAccessCatalog.physiotherapyEntry;

/// Prompt / AppRoutes route-entry ∪ alias (same as catalog entry).
const AccessRequirement physiotherapyWorkspaceRouteUnionRequirement =
    RouteAccessCatalog.physiotherapyEntry;

/// Create / update / delete therapy plan & session mutations.
///
/// Matrix ∩ `clinical:write` + `physiotherapy`. Therapy plans/sessions need
/// `clinical:write`; `patient:write` alone must not unlock mutations.
const AccessRequirement physiotherapyWorkspaceWriteRequirement =
    AccessRequirement(
      allPermissions: <AppPermission>[AppPermissions.clinicalWrite],
      activeModules: <String>[physiotherapyModule],
    );

/// Alias used by tab atom maps / prompts.
const AccessRequirement physiotherapyWriteRequirement =
    physiotherapyWorkspaceWriteRequirement;

/// Print / read-only next actions (matrix read ∪).
const AccessRequirement physiotherapyNextActionReadRequirement =
    physiotherapyWorkspaceReadRequirement;

/// Mutating next actions (matrix ∩ `clinical:write`).
const AccessRequirement physiotherapyNextActionWriteRequirement =
    physiotherapyWorkspaceWriteRequirement;

/// Billing status column / detail chip (prompt: billing chips need
/// `billing:read`). Reuses [billingReadRequirement]
/// (`billing:read` ∩ `billing-payments`).
const AccessRequirement physiotherapyBillingReadRequirement =
    billingReadRequirement;

/// Stable tab-strip order for physiotherapy workspace chrome.
const List<PhysiotherapyQueueScope> physiotherapyTabStripOrder =
    <PhysiotherapyQueueScope>[
      PhysiotherapyQueueScope.referrals,
      PhysiotherapyQueueScope.today,
      PhysiotherapyQueueScope.activePlans,
      PhysiotherapyQueueScope.followUpDue,
      PhysiotherapyQueueScope.missed,
      PhysiotherapyQueueScope.completed,
    ];

bool canReadPhysiotherapy(AppAccessPolicy policy) {
  return physiotherapyWorkspaceReadRequirement.isAllowed(policy);
}

bool canWritePhysiotherapy(AppAccessPolicy policy) {
  return physiotherapyWorkspaceWriteRequirement.isAllowed(policy);
}

bool canEnterPhysiotherapyWorkspace(AppAccessPolicy policy) {
  return physiotherapyWorkspaceEntryRequirement.isAllowed(policy);
}

bool canViewPhysiotherapyBilling(AppAccessPolicy policy) {
  return physiotherapyBillingReadRequirement.isAllowed(policy);
}

/// Per-section tab strip gate. Prefer tab `*AtomPermissions.tab` when present.
AccessRequirement physiotherapySectionTabRequirement(
  PhysiotherapyQueueScope scope,
) {
  return switch (scope) {
    PhysiotherapyQueueScope.activePlans =>
      PhysiotherapyActivePlansAtomPermissions.tab,
    PhysiotherapyQueueScope.referrals ||
    PhysiotherapyQueueScope.today ||
    PhysiotherapyQueueScope.followUpDue ||
    PhysiotherapyQueueScope.missed ||
    PhysiotherapyQueueScope.completed ||
    PhysiotherapyQueueScope.all => physiotherapyWorkspaceReadRequirement,
  };
}

bool canViewPhysiotherapyTab(
  AppAccessPolicy policy,
  PhysiotherapyQueueScope scope,
) {
  return physiotherapySectionTabRequirement(scope).isAllowed(policy);
}

bool canViewPhysiotherapyActivePlans(AppAccessPolicy policy) {
  return PhysiotherapyActivePlansAtomPermissions.tab.isAllowed(policy);
}

List<PhysiotherapyQueueScope> physiotherapyAllowedScopes(
  AppAccessPolicy policy,
) {
  return physiotherapyTabStripOrder
      .where(
        (PhysiotherapyQueueScope scope) =>
            canViewPhysiotherapyTab(policy, scope),
      )
      .toList(growable: false);
}

PhysiotherapyQueueScope? physiotherapyFallbackScope(AppAccessPolicy policy) {
  final List<PhysiotherapyQueueScope> allowed =
      physiotherapyAllowedScopes(policy);
  if (allowed.isEmpty) {
    return null;
  }
  if (allowed.contains(PhysiotherapyQueueScope.referrals)) {
    return PhysiotherapyQueueScope.referrals;
  }
  return allowed.first;
}

/// Active plans tab atom → permission mapping (inventory + matrix).
///
/// Active therapy plans (`/physiotherapy?section=active-plans`). Nested
/// cross-module matrix rows are _(n/a)_ except billing status chips/columns
/// ([billingColumn] / [billingChip] — ∩ `billing:read` + `billing-payments`).
/// Create/update/delete keep matrix ∩ `clinical:write` + module. Route entry ∪
/// is [routeEntry] (includes `billing:read` alone for shell entry, not tab
/// chrome). Next action on this tab is Schedule follow-up ([scheduleFollowUp]).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Active plans tab / count badge | navigate | read ∪ ([tab]) |
/// | Search / Clear / Filters / Settings / columns | read chrome | ([listChrome]) |
/// | Empty / error / retry / loading | read chrome | ([empty] / [loading] / [retry]) |
/// | Success snackbar / validation (authorized) | visible feedback | write / form |
/// | Row select → therapy detail | read | ([detail]) |
/// | Next action Schedule follow-up | create / update | write ∩ ([scheduleFollowUp]) |
/// | Optional billing column | data read | ([billingColumn]) |
/// | Detail complementary writes (plan, note, session, close…) | create / update / delete | write ∩ |
/// | Detail billing authorization chip | nested read | ([billingChip]) |
/// | Detail print instructions | read / export | ([printInstructions]) |
/// | Nested mutation dialogs | create / update | write ∩ |
/// | Route entry (deep link) | navigate | clinical \| patient \| billing:read ([routeEntry]) |
abstract final class PhysiotherapyActivePlansAtomPermissions {
  static const AccessRequirement tab = physiotherapyWorkspaceReadRequirement;
  static const AccessRequirement listChrome =
      physiotherapyWorkspaceReadRequirement;
  static const AccessRequirement search = physiotherapyWorkspaceReadRequirement;
  static const AccessRequirement filters = physiotherapyWorkspaceReadRequirement;
  static const AccessRequirement settings =
      physiotherapyWorkspaceReadRequirement;
  static const AccessRequirement pagination =
      physiotherapyWorkspaceReadRequirement;
  static const AccessRequirement empty = physiotherapyWorkspaceReadRequirement;
  static const AccessRequirement loading = physiotherapyWorkspaceReadRequirement;
  static const AccessRequirement retry = physiotherapyWorkspaceReadRequirement;
  static const AccessRequirement success =
      physiotherapyWorkspaceWriteRequirement;
  static const AccessRequirement validation =
      physiotherapyWorkspaceWriteRequirement;
  static const AccessRequirement rowSelect =
      physiotherapyWorkspaceReadRequirement;
  static const AccessRequirement detail = physiotherapyWorkspaceReadRequirement;
  static const AccessRequirement create = physiotherapyWorkspaceWriteRequirement;
  static const AccessRequirement update = physiotherapyWorkspaceWriteRequirement;
  static const AccessRequirement delete = physiotherapyWorkspaceWriteRequirement;
  static const AccessRequirement write = physiotherapyWorkspaceWriteRequirement;
  static const AccessRequirement nextAction =
      physiotherapyWorkspaceWriteRequirement;
  static const AccessRequirement scheduleFollowUp =
      physiotherapyWorkspaceWriteRequirement;
  static const AccessRequirement updatePlan =
      physiotherapyWorkspaceWriteRequirement;
  static const AccessRequirement addProgressNote =
      physiotherapyWorkspaceWriteRequirement;
  static const AccessRequirement scheduleSession =
      physiotherapyWorkspaceWriteRequirement;
  static const AccessRequirement recordSession =
      physiotherapyWorkspaceWriteRequirement;
  static const AccessRequirement recordAssessment =
      physiotherapyWorkspaceWriteRequirement;
  static const AccessRequirement markAttendance =
      physiotherapyWorkspaceWriteRequirement;
  static const AccessRequirement acceptReferral =
      physiotherapyWorkspaceWriteRequirement;
  static const AccessRequirement closeEpisode =
      physiotherapyWorkspaceWriteRequirement;
  static const AccessRequirement printInstructions =
      physiotherapyWorkspaceReadRequirement;
  static const AccessRequirement billingColumn =
      physiotherapyBillingReadRequirement;
  static const AccessRequirement billingChip =
      physiotherapyBillingReadRequirement;
  static const AccessRequirement nestedWrite =
      physiotherapyWorkspaceWriteRequirement;
  static const AccessRequirement nestedRead =
      physiotherapyWorkspaceReadRequirement;
  static const AccessRequirement entry = physiotherapyWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry =
      physiotherapyWorkspaceEntryRequirement;
  static const AccessRequirement routeEntryUnion =
      physiotherapyWorkspaceRouteUnionRequirement;
  static const AccessRequirement catalogEntry =
      RouteAccessCatalog.physiotherapyEntry;
}
