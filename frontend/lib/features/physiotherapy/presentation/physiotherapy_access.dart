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

/// Shared Follow-ups worklist read — matrix ∪ `clinical:read` | `patient:read`
/// + `physiotherapy` (same as workspace read).
const AccessRequirement physiotherapyFollowUpsRequirement =
    physiotherapyWorkspaceReadRequirement;

/// Shared Follow-ups complete / reschedule — matrix ∩ `clinical:write` +
/// `physiotherapy`.
const AccessRequirement physiotherapyFollowUpsWriteRequirement =
    physiotherapyWorkspaceWriteRequirement;

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
    PhysiotherapyQueueScope.referrals =>
      PhysiotherapyReferralsAtomPermissions.tab,
    PhysiotherapyQueueScope.activePlans =>
      PhysiotherapyActivePlansAtomPermissions.tab,
    PhysiotherapyQueueScope.followUpDue =>
      PhysiotherapyFollowUpDueAtomPermissions.tab,
    PhysiotherapyQueueScope.missed => PhysiotherapyMissedAtomPermissions.tab,
    PhysiotherapyQueueScope.completed =>
      PhysiotherapyCompletedAtomPermissions.tab,
    PhysiotherapyQueueScope.today ||
    PhysiotherapyQueueScope.all => physiotherapyWorkspaceReadRequirement,
  };
}

bool canViewPhysiotherapyTab(
  AppAccessPolicy policy,
  PhysiotherapyQueueScope scope,
) {
  return physiotherapySectionTabRequirement(scope).isAllowed(policy);
}

bool canViewPhysiotherapyReferrals(AppAccessPolicy policy) {
  return PhysiotherapyReferralsAtomPermissions.tab.isAllowed(policy);
}

bool canViewPhysiotherapyActivePlans(AppAccessPolicy policy) {
  return PhysiotherapyActivePlansAtomPermissions.tab.isAllowed(policy);
}

bool canViewPhysiotherapyFollowUpDue(AppAccessPolicy policy) {
  return PhysiotherapyFollowUpDueAtomPermissions.tab.isAllowed(policy);
}

bool canViewPhysiotherapyMissed(AppAccessPolicy policy) {
  return PhysiotherapyMissedAtomPermissions.tab.isAllowed(policy);
}

bool canViewPhysiotherapyCompleted(AppAccessPolicy policy) {
  return PhysiotherapyCompletedAtomPermissions.tab.isAllowed(policy);
}

bool canViewPhysiotherapyFollowUps(AppAccessPolicy policy) {
  return PhysiotherapyFollowUpsAtomPermissions.tab.isAllowed(policy);
}

bool canReadPhysiotherapyFollowUps(AppAccessPolicy policy) {
  return physiotherapyFollowUpsRequirement.isAllowed(policy);
}

bool canWritePhysiotherapyFollowUps(AppAccessPolicy policy) {
  return physiotherapyFollowUpsWriteRequirement.isAllowed(policy);
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

/// Referrals tab atom → permission mapping (inventory + matrix).
///
/// Incoming therapy referrals (`/physiotherapy?section=referrals`). Nested
/// cross-module matrix rows are _(n/a)_ except billing status chips/columns
/// ([billingColumn] / [billingChip] — ∩ `billing:read` + `billing-payments`).
/// Create/update/delete keep matrix ∩ `clinical:write` + module. Route entry ∪
/// is [routeEntry] (includes `billing:read` alone for shell entry, not tab
/// chrome). Next action on this tab is Accept referral ([acceptReferral]).
/// Referrals intake may allow `patient:read` readers without write.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Referrals tab / count badge | navigate | read ∪ ([tab]) |
/// | Search / Clear / Filters / Settings / columns | read chrome | ([listChrome]) |
/// | Status filter (REFERRAL / ACCEPTED / ASSESSMENT) | read chrome | ([filters]) |
/// | Empty / error / retry / loading | read chrome | ([empty] / [loading] / [retry]) |
/// | Success snackbar / validation (authorized) | visible feedback | write / form |
/// | Row select → therapy detail | read | ([detail]) |
/// | Next action Accept referral | create / update | write ∩ ([acceptReferral]) |
/// | Optional billing column | data read | ([billingColumn]) |
/// | Detail complementary writes (plan, note, session, close…) | create / update / delete | write ∩ |
/// | Detail billing authorization chip | nested read | ([billingChip]) |
/// | Detail print instructions | read / export | ([printInstructions]) |
/// | Nested Accept referral / mutation dialogs | create / update | write ∩ |
/// | Route entry (deep link) | navigate | clinical \| patient \| billing:read ([routeEntry]) |
abstract final class PhysiotherapyReferralsAtomPermissions {
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
  static const AccessRequirement acceptReferral =
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
  static const AccessRequirement scheduleFollowUp =
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

/// Completed tab atom → permission mapping (inventory + matrix).
///
/// Completed plans (`/physiotherapy?section=completed`). Read-heavy: row next
/// action is Print instructions ([printInstructions] — read ∪). Nested
/// cross-module matrix rows are _(n/a)_ except billing status chips/columns
/// ([billingColumn] / [billingChip] — ∩ `billing:read` + `billing-payments`).
/// Detail complementary create/update/delete keep matrix ∩ `clinical:write` +
/// module. Route entry ∪ is [routeEntry] (includes `billing:read` alone for
/// shell entry, not tab chrome). Therapy plans/sessions need `clinical:write`.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Completed tab / count badge | navigate | read ∪ ([tab]) |
/// | Search / Clear / Filters / Settings / columns | read chrome | ([listChrome]) |
/// | Empty / error / retry / loading | read chrome | ([empty] / [loading] / [retry]) |
/// | Success snackbar / validation (authorized) | visible feedback | write / form |
/// | Row select → therapy detail | read | ([detail]) |
/// | Next action Print instructions | read / export | ([printInstructions] / [nextAction]) |
/// | Optional billing column | data read | ([billingColumn]) |
/// | Detail complementary writes (plan, note, session, close…) | create / update / delete | write ∩ |
/// | Detail billing authorization chip | nested read | ([billingChip]) |
/// | Detail print instructions (when not row next-action) | read / export | ([printInstructions]) |
/// | Nested mutation dialogs | create / update | write ∩ |
/// | Route entry (deep link) | navigate | clinical \| patient \| billing:read ([routeEntry]) |
abstract final class PhysiotherapyCompletedAtomPermissions {
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
  /// Row next action on Completed is Print instructions (read ∪), not write.
  static const AccessRequirement nextAction =
      physiotherapyWorkspaceReadRequirement;
  static const AccessRequirement nextActionWrite =
      physiotherapyWorkspaceWriteRequirement;
  static const AccessRequirement printInstructions =
      physiotherapyWorkspaceReadRequirement;
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
  static const AccessRequirement scheduleFollowUp =
      physiotherapyWorkspaceWriteRequirement;
  static const AccessRequirement closeEpisode =
      physiotherapyWorkspaceWriteRequirement;
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

/// Follow-up due tab atom → permission mapping (inventory + matrix).
///
/// Due therapy follow-ups (`/physiotherapy?section=follow-up`). Nested
/// cross-module matrix rows are _(n/a)_ except billing status chips/columns
/// ([billingColumn] / [billingChip] — ∩ `billing:read` + `billing-payments`).
/// Create/update/delete keep matrix ∩ `clinical:write` + module. Route entry ∪
/// is [routeEntry] (includes `billing:read` alone for shell entry, not tab
/// chrome). Next action on this tab is Schedule follow-up ([scheduleFollowUp]).
/// Referrals intake may allow `patient:read` readers without write.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Follow-up due tab / count badge | navigate | read ∪ ([tab]) |
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
abstract final class PhysiotherapyFollowUpDueAtomPermissions {
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

/// Missed tab atom → permission mapping (inventory + matrix).
///
/// Missed sessions (`/physiotherapy?section=missed`). Nested cross-module
/// matrix rows are _(n/a)_ except billing status chips/columns
/// ([billingColumn] / [billingChip] — ∩ `billing:read` + `billing-payments`).
/// Create/update/delete keep matrix ∩ `clinical:write` + module. Route entry ∪
/// is [routeEntry] (includes `billing:read` alone for shell entry, not tab
/// chrome). Row next action is Mark attendance ([markAttendance]); reschedule
/// (Schedule session / Schedule follow-up in detail) needs write ∩
/// ([scheduleSession] / [scheduleFollowUp]). Therapy plans/sessions need
/// `clinical:write`. Referrals intake may allow `patient:read` readers without
/// write.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Missed tab / count badge | navigate | read ∪ ([tab]) |
/// | Search / Clear / Filters / Settings / columns | read chrome | ([listChrome]) |
/// | Empty / error / retry / loading | read chrome | ([empty] / [loading] / [retry]) |
/// | Success snackbar / validation (authorized) | visible feedback | write / form |
/// | Row select → therapy detail | read | ([detail]) |
/// | Next action Mark attendance | update | write ∩ ([markAttendance] / [nextAction]) |
/// | Detail reschedule (Schedule session / follow-up) | create / update | write ∩ |
/// | Optional billing column | data read | ([billingColumn]) |
/// | Detail complementary writes (plan, note, session, close…) | create / update / delete | write ∩ |
/// | Detail billing authorization chip | nested read | ([billingChip]) |
/// | Detail print instructions | read / export | ([printInstructions]) |
/// | Nested mutation dialogs (attendance, schedule…) | create / update | write ∩ |
/// | Route entry (deep link) | navigate | clinical \| patient \| billing:read ([routeEntry]) |
abstract final class PhysiotherapyMissedAtomPermissions {
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
  static const AccessRequirement markAttendance =
      physiotherapyWorkspaceWriteRequirement;
  static const AccessRequirement scheduleSession =
      physiotherapyWorkspaceWriteRequirement;
  static const AccessRequirement scheduleFollowUp =
      physiotherapyWorkspaceWriteRequirement;
  static const AccessRequirement updatePlan =
      physiotherapyWorkspaceWriteRequirement;
  static const AccessRequirement addProgressNote =
      physiotherapyWorkspaceWriteRequirement;
  static const AccessRequirement recordSession =
      physiotherapyWorkspaceWriteRequirement;
  static const AccessRequirement recordAssessment =
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

/// Follow-ups tab atom → permission mapping (inventory + matrix).
///
/// Shared follow-up worklist (`/physiotherapy?section=follow-ups`). Hosted via
/// [FollowUpWorklistPanel] with physiotherapy read/write overrides. Nested
/// cross-module matrix rows are _(n/a)_ — billing chips / therapy plan writes
/// are **not** reachable from this tab (those live on queue tabs / detail).
/// Create / update / delete use matrix ∩ `clinical:write` via
/// [physiotherapyFollowUpsWriteRequirement]. Route entry keeps catalog ∪
/// ([routeEntry]); tab chrome stays ∪ `clinical:read` | `patient:read` +
/// module. Billing-only route entry does **not** satisfy Follow-ups chrome.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Follow-ups tab / count badge | navigate | read ∪ ([tab]) |
/// | Search / Clear / Settings / columns | read chrome | ([listChrome]) |
/// | Empty / error / retry / loading | read chrome | ([empty] / [loading] / [retry]) |
/// | Success snackbar / validation (authorized) | visible feedback | write ∩ / form |
/// | Row select → Follow-up details | read | ([detail]) |
/// | Detail Close (read-only footer) | progressive disclosure | ([close]) |
/// | Reschedule follow-up | update | write ∩ ([reschedule]) |
/// | Mark completed | update | write ∩ ([markCompleted] / [complete]) |
/// | Save follow-up (nested reschedule dialog) | update | write ∩ ([saveFollowUp]) |
/// | Hard delete / void | delete | write ∩ ([delete]) — not mounted |
/// | Therapy plan / session / billing chip | nested | _(n/a)_ — not reachable |
/// | Route entry (deep link) | navigate | clinical \| patient \| billing:read ([routeEntry]) |
abstract final class PhysiotherapyFollowUpsAtomPermissions {
  static const AccessRequirement tab = physiotherapyFollowUpsRequirement;
  static const AccessRequirement listChrome = physiotherapyFollowUpsRequirement;
  static const AccessRequirement search = physiotherapyFollowUpsRequirement;
  static const AccessRequirement settings = physiotherapyFollowUpsRequirement;
  static const AccessRequirement empty = physiotherapyFollowUpsRequirement;
  static const AccessRequirement loading = physiotherapyFollowUpsRequirement;
  static const AccessRequirement retry = physiotherapyFollowUpsRequirement;

  /// Authorized success path after complete / reschedule (write-gated entry).
  static const AccessRequirement success =
      physiotherapyFollowUpsWriteRequirement;

  /// Authorized form validation feedback (nested reschedule dialog).
  static const AccessRequirement validation =
      physiotherapyFollowUpsWriteRequirement;
  static const AccessRequirement rowSelect = physiotherapyFollowUpsRequirement;
  static const AccessRequirement detail = physiotherapyFollowUpsRequirement;
  static const AccessRequirement close = physiotherapyFollowUpsRequirement;
  static const AccessRequirement create =
      physiotherapyFollowUpsWriteRequirement;
  static const AccessRequirement update =
      physiotherapyFollowUpsWriteRequirement;
  static const AccessRequirement delete =
      physiotherapyFollowUpsWriteRequirement;
  static const AccessRequirement reschedule =
      physiotherapyFollowUpsWriteRequirement;
  static const AccessRequirement markCompleted =
      physiotherapyFollowUpsWriteRequirement;
  static const AccessRequirement complete =
      physiotherapyFollowUpsWriteRequirement;
  static const AccessRequirement saveFollowUp =
      physiotherapyFollowUpsWriteRequirement;
  static const AccessRequirement write =
      physiotherapyFollowUpsWriteRequirement;

  /// Nested cross-module — matrix _(n/a)_; reuses write ∩ / read ∪.
  static const AccessRequirement nestedWrite =
      physiotherapyFollowUpsWriteRequirement;
  static const AccessRequirement nestedRead = physiotherapyFollowUpsRequirement;

  /// Documented for inventory parity; billing chips are not on this tab.
  static const AccessRequirement billingColumn =
      physiotherapyBillingReadRequirement;
  static const AccessRequirement billingChip =
      physiotherapyBillingReadRequirement;
  static const AccessRequirement entry = physiotherapyWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry =
      physiotherapyWorkspaceEntryRequirement;
  static const AccessRequirement routeEntryUnion =
      physiotherapyWorkspaceRouteUnionRequirement;
  static const AccessRequirement catalogEntry =
      RouteAccessCatalog.physiotherapyEntry;
  static const AccessRequirement read = physiotherapyFollowUpsRequirement;
}
