import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final String managementSource = File(
    'lib/features/access_admin/presentation/widgets/access_admin_management_dialogs.dart',
  ).readAsStringSync();
  final String setupPageSource = File(
    'lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart',
  ).readAsStringSync();
  final String dialogsSource = File(
    'lib/features/access_admin/presentation/widgets/access_admin_dialogs.dart',
  ).readAsStringSync();
  final String scopeRepoSource = File(
    '../backend/src/modules/tenant-facility-workspace/repositories/tenant-facility-workspace.repository.js',
  ).readAsStringSync();

  String usersPanelSource() {
    final int usersPanelStart = managementSource.indexOf(
      'class _ManageUsersPanelState',
    );
    final int rolesPanelStart = managementSource.indexOf(
      'class _ManageRolesPermissionsPanelState',
    );
    return managementSource.substring(usersPanelStart, rolesPanelStart);
  }

  test('setup Users tab hosts ManageUsersPanel', () {
    expect(
      setupPageSource.contains(
        'TenantFacilitySetupDeskSection.users => ManageUsersPanel(',
      ),
      isTrue,
    );
  });

  test('users listQuery scopes by actor capability flags', () {
    final String source = usersPanelSource();
    expect(source.contains('canCreateTenant()'), isTrue);
    expect(source.contains('canCreateTenantWideRole()'), isTrue);
    expect(source.contains('allTenants: crossTenant'), isTrue);
    expect(
      source.contains('allFacilities: tenantWide || crossTenant'),
      isTrue,
    );
    expect(
      source.contains('facilityId: tenantWide ? null : facilityFilter'),
      isTrue,
    );
  });

  test('backend resolveWorkspaceScope keeps facility actors facility-bound', () {
    expect(
      scopeRepoSource.contains('requestedFacilityId || userFacilityId'),
      isTrue,
    );
    expect(
      scopeRepoSource.contains('canViewAllFacilitiesInTenant(user)'),
      isTrue,
    );
    expect(scopeRepoSource.contains('if (isSuperAdmin(user))'), isTrue);
  });

  test('user filters expose tenant/facility only when authorized', () {
    final String source = usersPanelSource();
    expect(source.contains('key: _tenantFilterKey'), isTrue);
    expect(source.contains('if (canPickTenant)'), isTrue);
    expect(source.contains('if (showFacilityFilter)'), isTrue);
    expect(
      source.contains(
        'canFilterFacilities && (!canPickTenant || tenantFilter != null)',
      ),
      isTrue,
    );
    expect(source.contains('key: _roleFilterKey'), isTrue);
    expect(source.contains('key: _statusFilterKey'), isTrue);
  });

  test('default user columns stay shared across scopes', () {
    final String source = usersPanelSource();
    expect(source.contains("id: 'name'"), isTrue);
    expect(source.contains("id: 'roles'"), isTrue);
    expect(source.contains("id: 'status'"), isTrue);
    expect(source.contains("id: 'actions'"), isTrue);
    expect(source.contains("id: 'facility'"), isTrue);
    expect(source.contains("id: 'id'"), isTrue);
    expect(source.contains("id: 'details'"), isTrue);
    expect(
      source.contains('columnChoices:'),
      isTrue,
      reason: 'Optional columns stay in the chooser, not per-role tables',
    );
  });

  test('create edit delete and row select open the correct user dialogs', () {
    final String source = usersPanelSource();
    expect(source.contains('openAccessAdminCreateUserDialog'), isTrue);
    expect(source.contains('openAccessAdminEditUserDialog'), isTrue);
    expect(source.contains('_confirmDeleteUser'), isTrue);
    expect(source.contains('_confirmRestoreUser'), isTrue);
    expect(source.contains('_openUserDetail'), isTrue);
    expect(
      source.contains('onRowSelected: (AccessAdminItem item) =>'),
      isTrue,
    );
    expect(source.contains('_AccessAdminUserDetailDialog'), isTrue);
    expect(dialogsSource.contains('showUserMutationDialog'), isTrue);
    expect(source.contains('tenantFacilitySoftDeleteUserTitle'), isTrue);
  });

  test('user row actions are spaced and hide unauthorized delete', () {
    final String source = usersPanelSource();
    expect(
      source.contains('spacing: actionGap'),
      isTrue,
      reason: 'Edit/Delete must not sit flush',
    );
    expect(
      source.contains('if (!user.isDemo && !user.isSystemCritical)'),
      isTrue,
      reason: 'Delete must be unrendered for demo/system-critical users',
    );
    expect(
      RegExp(
        r'if\s*\(canWrite\)\s*AppListTableColumn<AccessAdminItem>\(',
      ).hasMatch(source),
      isTrue,
      reason: 'Unauthorized write actions must not render',
    );
  });

  test('mutations silently sync the users list', () {
    final String source = usersPanelSource();
    // Create hands off to details immediately, so the list reload runs silently
    // in the background (mirrors the role create flow) rather than blocking.
    expect(
      source.contains('unawaited(reload(resetPage: true, silent: true))'),
      isTrue,
    );
    expect(
      source.contains('await reload(resetPage: false, silent: true)'),
      isTrue,
    );
    expect(
      source.contains('unawaited(reload(resetPage: false, silent: true))'),
      isTrue,
    );
  });

  test('user detail clarifies identity and collapses role permissions', () {
    expect(
      managementSource.contains('_resolveUserDetailIdentity'),
      isTrue,
      reason: 'Summary must resolve a non-duplicative primary identity',
    );
    expect(
      managementSource.contains('_UserDetailAccountFields'),
      isTrue,
      reason: 'Account fields stay grouped and complete',
    );
    expect(
      managementSource.contains('canMutate = widget.canWrite && !item.isDeleted'),
      isTrue,
      reason: 'Soft-deleted users must not expose write actions',
    );
    expect(
      File('lib/shared/components/app_user_access_panel.dart')
          .readAsStringSync()
          .contains('_expanded = false'),
      isTrue,
      reason: 'Role-inherited permissions start collapsed',
    );
  });
}
