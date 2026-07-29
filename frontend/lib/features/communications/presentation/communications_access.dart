import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/features/communications/domain/entities/communications_entities.dart';

/// Module entitlement for the communications workspace route and panels.
const String communicationsModule = 'notifications-communications';

/// Alias used by Deliveries / newer call sites.
const String communicationsActiveModule = communicationsModule;

/// View / read UI (matrix ∩ `communications:read`).
const AccessRequirement communicationsWorkspaceReadRequirement =
    AccessRequirement(
      allPermissions: <AppPermission>[AppPermissions.communicationsRead],
      activeModules: <String>[communicationsModule],
    );

/// Alias used by tab atom maps / prompts.
const AccessRequirement communicationsReadRequirement =
    communicationsWorkspaceReadRequirement;

/// Route entry (∪): `communications:read` | `communications:write` — matches
/// [AppRoutes.communications] `requiredAnyPermissions`.
const AccessRequirement communicationsWorkspaceEntryRequirement =
    AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.communicationsRead,
        AppPermissions.communicationsWrite,
      ],
      activeModules: <String>[communicationsModule],
    );

/// Create / update mutations (matrix ∩ `communications:write`).
///
/// Source inventory (`screens/communications.md`) gates New message/group,
/// compose, thread menu (favorite / flag / mark read / archive / members) on
/// write — not delete. Backend archive / participant routes use WRITE.
const AccessRequirement communicationsWorkspaceWriteRequirement =
    AccessRequirement(
      allPermissions: <AppPermission>[AppPermissions.communicationsWrite],
      activeModules: <String>[communicationsModule],
    );

/// Alias used by tab atom maps / prompts.
const AccessRequirement communicationsWriteRequirement =
    communicationsWorkspaceWriteRequirement;

/// Hard delete / notification archive (matrix ∩ `communications:delete`).
///
/// Backend `POST /notifications/bulk/archive` and hard delete of threads /
/// templates authorize with `communications:delete`. Conversation archive on
/// Messages remains under [communicationsWorkspaceWriteRequirement] (backend
/// WRITE). Prefer this requirement for notification Archive and hard deletes.
const AccessRequirement communicationsWorkspaceDeleteRequirement =
    AccessRequirement(
      allPermissions: <AppPermission>[AppPermissions.communicationsDelete],
      activeModules: <String>[communicationsModule],
    );

/// Alias used by tab atom maps / prompts.
const AccessRequirement communicationsDeleteRequirement =
    communicationsWorkspaceDeleteRequirement;

/// Per-panel tab strip gate. Panels share workspace read until a tab prompt
/// documents a narrower requirement.
AccessRequirement communicationsPanelTabRequirement(
  CommunicationsPanel panel,
) {
  return switch (panel) {
    CommunicationsPanel.inbox => CommunicationsMessagesAtomPermissions.tab,
    CommunicationsPanel.notifications =>
      CommunicationsNotificationsAtomPermissions.tab,
    CommunicationsPanel.deliveries =>
      CommunicationsDeliveriesAtomPermissions.tab,
    CommunicationsPanel.templates =>
      CommunicationsTemplatesAtomPermissions.tab,
  };
}

AccessRequirement communicationsPanelReadRequirement(CommunicationsPanel panel) {
  return communicationsPanelTabRequirement(panel);
}

bool canReadCommunications(AppAccessPolicy policy) {
  return communicationsWorkspaceReadRequirement.isAllowed(policy);
}

bool canWriteCommunications(AppAccessPolicy policy) {
  return communicationsWorkspaceWriteRequirement.isAllowed(policy);
}

bool canDeleteCommunications(AppAccessPolicy policy) {
  return communicationsWorkspaceDeleteRequirement.isAllowed(policy);
}

bool canEnterCommunications(AppAccessPolicy policy) {
  return communicationsWorkspaceEntryRequirement.isAllowed(policy);
}

/// Alias matching route-entry naming used by Deliveries / Messages tests.
bool canEnterCommunicationsWorkspace(AppAccessPolicy policy) {
  return canEnterCommunications(policy);
}

bool canViewCommunicationsPanel(
  AppAccessPolicy policy,
  CommunicationsPanel panel,
) {
  return communicationsPanelTabRequirement(panel).isAllowed(policy);
}

/// Panels the policy may show in the workspace tab strip.
List<CommunicationsPanel> communicationsAllowedPanels(AppAccessPolicy policy) {
  return <CommunicationsPanel>[
    for (final CommunicationsPanel panel in CommunicationsPanel.values)
      if (canViewCommunicationsPanel(policy, panel)) panel,
  ];
}

/// First authorized panel (prefer inbox), or null when none are visible.
CommunicationsPanel? communicationsFallbackPanel(AppAccessPolicy policy) {
  final List<CommunicationsPanel> panels = communicationsAllowedPanels(policy);
  if (panels.isEmpty) {
    return null;
  }
  if (panels.contains(CommunicationsPanel.inbox)) {
    return CommunicationsPanel.inbox;
  }
  return panels.first;
}

/// Messages (inbox) tab atom → permission mapping (inventory + matrix).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Messages tab | navigate | read ∩ `communications:read` |
/// | Search / message filters / Load more | read chrome | read ∩ |
/// | Empty / loading / error / retry | read chrome | read ∩ |
/// | Select conversation → thread | read | read ∩ |
/// | Thread back (narrow) | navigate | read ∩ |
/// | New message / New group | create | write ∩ `communications:write` |
/// | Compose / Send / Attach / Reply | create / update | write ∩ |
/// | Thread menu favorite / flag / mark read / archive | update | write ∩ |
/// | Manage members (+ add/remove) | update | write ∩ |
/// | Delete thread (not in inventory UI) | delete | delete ∩ `communications:delete` |
/// | Nested cross-module read/write | — | _(n/a)_ |
/// | Route entry (deep link) | navigate | read ∪ write |
///
/// Archive on conversation thread menu is update/write per source inventory +
/// backend WRITE authorize. Notification Archive (other tab) uses delete ∩.
/// Matrix delete applies to hard delete thread/template when exposed.
/// Nested cross-module matrix rows are _(n/a)_.
abstract final class CommunicationsMessagesAtomPermissions {
  static const AccessRequirement tab = communicationsWorkspaceReadRequirement;
  static const AccessRequirement listChrome =
      communicationsWorkspaceReadRequirement;
  static const AccessRequirement search =
      communicationsWorkspaceReadRequirement;
  static const AccessRequirement filters =
      communicationsWorkspaceReadRequirement;
  static const AccessRequirement pagination =
      communicationsWorkspaceReadRequirement;
  static const AccessRequirement empty = communicationsWorkspaceReadRequirement;
  static const AccessRequirement loading =
      communicationsWorkspaceReadRequirement;
  static const AccessRequirement retry = communicationsWorkspaceReadRequirement;
  static const AccessRequirement rowSelect =
      communicationsWorkspaceReadRequirement;
  static const AccessRequirement detail =
      communicationsWorkspaceReadRequirement;
  static const AccessRequirement thread = communicationsWorkspaceReadRequirement;
  static const AccessRequirement create =
      communicationsWorkspaceWriteRequirement;
  static const AccessRequirement update =
      communicationsWorkspaceWriteRequirement;
  static const AccessRequirement delete =
      communicationsWorkspaceDeleteRequirement;
  static const AccessRequirement write =
      communicationsWorkspaceWriteRequirement;
  static const AccessRequirement newMessage =
      communicationsWorkspaceWriteRequirement;
  static const AccessRequirement newGroup =
      communicationsWorkspaceWriteRequirement;
  static const AccessRequirement compose =
      communicationsWorkspaceWriteRequirement;
  static const AccessRequirement threadMenu =
      communicationsWorkspaceWriteRequirement;
  static const AccessRequirement manageMembers =
      communicationsWorkspaceWriteRequirement;
  static const AccessRequirement nestedWrite =
      communicationsWorkspaceWriteRequirement;
  static const AccessRequirement nestedRead =
      communicationsWorkspaceReadRequirement;
  static const AccessRequirement entry =
      communicationsWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry =
      communicationsWorkspaceEntryRequirement;
}

/// Notifications tab atom → permission mapping (inventory + matrix).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Notifications tab | navigate | [tab] read ∩ `communications:read` |
/// | Search / Clear / Filters / Settings / pagination | read chrome | [listChrome] |
/// | Empty / error / retry / loading | read chrome | [listChrome] / page |
/// | Row select → detail | read | [rowSelect] / [detail] |
/// | Next action Mark read / Mark unread | update | [markRead] / [update] write ∩ |
/// | Next action View (read-only) | read / navigate | [view] / [nextAction] read ∩ |
/// | Detail content / delivery history | read | [detail] |
/// | Detail Open linked record (body) | navigate | [openLinked] read ∩ |
/// | Detail Archive (+ confirm) | delete | [archive] / [delete] delete ∩ |
/// | Tab-strip New message / New group | create | _(Messages only)_ [create] |
/// | Nested cross-module read / write | — | _(n/a)_ |
/// | Route entry (deep link) | navigate | [routeEntry] read ∪ write |
///
/// Matrix nested cross-module rows are _(n/a)_. Notification Archive uses
/// matrix ∩ `communications:delete` (backend bulk archive). Earlier inventory
/// gated Archive on write — aligned to matrix + backend; mapping noted in tests.
abstract final class CommunicationsNotificationsAtomPermissions {
  static const AccessRequirement tab = communicationsWorkspaceReadRequirement;
  static const AccessRequirement listChrome =
      communicationsWorkspaceReadRequirement;
  static const AccessRequirement search =
      communicationsWorkspaceReadRequirement;
  static const AccessRequirement filters =
      communicationsWorkspaceReadRequirement;
  static const AccessRequirement pagination =
      communicationsWorkspaceReadRequirement;
  static const AccessRequirement empty = communicationsWorkspaceReadRequirement;
  static const AccessRequirement loading =
      communicationsWorkspaceReadRequirement;
  static const AccessRequirement retry = communicationsWorkspaceReadRequirement;
  static const AccessRequirement rowSelect =
      communicationsWorkspaceReadRequirement;
  static const AccessRequirement detail = communicationsWorkspaceReadRequirement;
  static const AccessRequirement view = communicationsWorkspaceReadRequirement;
  static const AccessRequirement nextAction =
      communicationsWorkspaceReadRequirement;
  static const AccessRequirement openLinked =
      communicationsWorkspaceReadRequirement;
  static const AccessRequirement create = communicationsWorkspaceWriteRequirement;
  static const AccessRequirement update = communicationsWorkspaceWriteRequirement;
  static const AccessRequirement delete =
      communicationsWorkspaceDeleteRequirement;
  static const AccessRequirement write = communicationsWorkspaceWriteRequirement;
  static const AccessRequirement markRead =
      communicationsWorkspaceWriteRequirement;
  static const AccessRequirement markUnread =
      communicationsWorkspaceWriteRequirement;
  static const AccessRequirement archive =
      communicationsWorkspaceDeleteRequirement;
  static const AccessRequirement nestedWrite =
      communicationsWorkspaceWriteRequirement;
  static const AccessRequirement nestedRead =
      communicationsWorkspaceReadRequirement;
  static const AccessRequirement entry = communicationsWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry =
      communicationsWorkspaceEntryRequirement;
  static const AccessRequirement read = communicationsReadRequirement;
}

/// Deliveries tab atom → permission mapping (inventory + matrix).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Deliveries tab | navigate | [tab] read ∩ `communications:read` |
/// | Search / Clear / Filters / Settings / pagination | read chrome | [listChrome] / [search] / [filters] / [pagination] |
/// | Empty / error / retry / loading | read chrome | [empty] / [retry] / [loading] |
/// | Row select → delivery detail | read | [rowSelect] / [detail] |
/// | Next action View / View error | read / navigate | [view] / [nextAction] |
/// | Next action Open linked (path present) | navigate | [nextAction] / [openLinked] |
/// | Detail metadata / error panel | read / progressive disclosure | [detail] |
/// | Detail Open linked record (body, path present) | navigate | [openLinked] |
/// | Tab-strip New message / New group | create | _(Messages only)_ [create] |
/// | Create / update / delete on this tab | — | _(none — read-only logs)_ |
/// | Nested cross-module read / write | — | _(n/a)_ |
/// | Route entry (deep link) | navigate | [routeEntry] read ∪ write |
///
/// Matrix nested cross-module rows are _(n/a)_. Deliveries prefer read; write /
/// delete requirements exist for Messages / Templates elsewhere and must not
/// mount mutation controls on this tab. Unauthorized detail entry no-ops (no
/// routine "no access" banner).
abstract final class CommunicationsDeliveriesAtomPermissions {
  static const AccessRequirement tab = communicationsWorkspaceReadRequirement;
  static const AccessRequirement listChrome =
      communicationsWorkspaceReadRequirement;
  static const AccessRequirement search =
      communicationsWorkspaceReadRequirement;
  static const AccessRequirement filters =
      communicationsWorkspaceReadRequirement;
  static const AccessRequirement pagination =
      communicationsWorkspaceReadRequirement;
  static const AccessRequirement empty = communicationsWorkspaceReadRequirement;
  static const AccessRequirement loading =
      communicationsWorkspaceReadRequirement;
  static const AccessRequirement retry = communicationsWorkspaceReadRequirement;
  static const AccessRequirement rowSelect =
      communicationsWorkspaceReadRequirement;
  static const AccessRequirement detail = communicationsWorkspaceReadRequirement;
  static const AccessRequirement view = communicationsWorkspaceReadRequirement;
  static const AccessRequirement nextAction =
      communicationsWorkspaceReadRequirement;
  static const AccessRequirement openLinked =
      communicationsWorkspaceReadRequirement;
  static const AccessRequirement create = communicationsWorkspaceWriteRequirement;
  static const AccessRequirement update = communicationsWorkspaceWriteRequirement;
  static const AccessRequirement delete =
      communicationsWorkspaceDeleteRequirement;
  static const AccessRequirement write = communicationsWorkspaceWriteRequirement;
  static const AccessRequirement nestedWrite =
      communicationsWorkspaceWriteRequirement;
  static const AccessRequirement nestedRead =
      communicationsWorkspaceReadRequirement;
  static const AccessRequirement entry = communicationsWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry =
      communicationsWorkspaceEntryRequirement;
  static const AccessRequirement read = communicationsReadRequirement;
}

/// Templates tab atom → permission mapping (inventory + matrix).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Templates tab | navigate | read ∩ `communications:read` |
/// | Search / Clear / Filters / Settings / pagination | read chrome | [listChrome] |
/// | Empty / error / retry / loading | read chrome | [listChrome] / page |
/// | Row select → template detail (preview) | read | [detail] |
/// | Detail metadata + preview panel | read | [detail] |
/// | Tab-strip New message / New group | create | _(Messages only)_ [create] |
/// | Create / update template (when exposed) | create / update | write ∩ |
/// | Delete template (when exposed) | delete | delete ∩ |
/// | Nested cross-module read / write | — | _(n/a)_ |
/// | Route entry (deep link) | navigate | [routeEntry] read ∪ write |
///
/// Source inventory (`screens/communications.md`) documents Templates as
/// read-focused: no next-action column; detail is preview-only. Matrix create /
/// update / delete apply when CRUD controls are exposed — they must not mount
/// for unauthorized users. Nested cross-module matrix rows are _(n/a)_.
abstract final class CommunicationsTemplatesAtomPermissions {
  static const AccessRequirement tab = communicationsWorkspaceReadRequirement;
  static const AccessRequirement listChrome =
      communicationsWorkspaceReadRequirement;
  static const AccessRequirement search =
      communicationsWorkspaceReadRequirement;
  static const AccessRequirement filters =
      communicationsWorkspaceReadRequirement;
  static const AccessRequirement pagination =
      communicationsWorkspaceReadRequirement;
  static const AccessRequirement empty = communicationsWorkspaceReadRequirement;
  static const AccessRequirement loading =
      communicationsWorkspaceReadRequirement;
  static const AccessRequirement retry = communicationsWorkspaceReadRequirement;
  static const AccessRequirement rowSelect =
      communicationsWorkspaceReadRequirement;
  static const AccessRequirement detail = communicationsWorkspaceReadRequirement;
  static const AccessRequirement preview = communicationsWorkspaceReadRequirement;
  static const AccessRequirement create = communicationsWorkspaceWriteRequirement;
  static const AccessRequirement update = communicationsWorkspaceWriteRequirement;
  static const AccessRequirement delete =
      communicationsWorkspaceDeleteRequirement;
  static const AccessRequirement write = communicationsWorkspaceWriteRequirement;
  static const AccessRequirement nestedWrite =
      communicationsWorkspaceWriteRequirement;
  static const AccessRequirement nestedRead =
      communicationsWorkspaceReadRequirement;
  static const AccessRequirement entry = communicationsWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry =
      communicationsWorkspaceEntryRequirement;
  static const AccessRequirement read = communicationsReadRequirement;
}
