import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final String dialogsSource = File(
    'lib/features/access_admin/presentation/widgets/access_admin_dialogs.dart',
  ).readAsStringSync();
  final String similarityDialogSource = File(
    'lib/features/access_admin/presentation/widgets/role_similarity_dialog.dart',
  ).readAsStringSync();
  final String managementSource = File(
    'lib/features/access_admin/presentation/widgets/access_admin_management_dialogs.dart',
  ).readAsStringSync();
  final String mutationDialogSource = File(
    'lib/shared/layout/app_workspace_mutation_dialog.dart',
  ).readAsStringSync();

  test('create role always opens similarity review before create API', () {
    expect(dialogsSource.contains('_reviewRoleSimilarity'), isTrue);
    expect(
      dialogsSource.contains('Create always opens review (including zero matches)'),
      isTrue,
    );
    expect(
      dialogsSource.contains('return const AppFailure.cancelled();'),
      isTrue,
      reason: 'Cancel must not surface as validation/conflict failure',
    );
  });

  test('backend uniqueness conflict reopens similarity review with hydration', () {
    expect(
      dialogsSource.contains('forceReviewMatches: true'),
      isTrue,
    );
    expect(
      dialogsSource.contains(
        'failure.category == AppFailureCategory.conflict',
      ),
      isTrue,
    );
    expect(
      dialogsSource.contains('roleSimilarityMatchesFromConflictEntries'),
      isTrue,
      reason: '409 match payloads must hydrate empty peer reviews',
    );
    expect(
      dialogsSource.contains(
        'Force-review after backend conflict must not reopen a false empty',
      ),
      isTrue,
    );
  });

  test('similarity dialog surfaces overall and field-level scores', () {
    expect(
      similarityDialogSource.contains('accessAdminSimilarRoleOverallSimilarityLabel'),
      isTrue,
    );
    expect(
      similarityDialogSource.contains('match.fieldComparisons'),
      isTrue,
    );
    expect(
      similarityDialogSource.contains('_StatusChip'),
      isTrue,
    );
    expect(
      similarityDialogSource.contains('allowProceed && !hasExactNameConflict'),
      isTrue,
    );
  });

  final String peerLoaderSource = dialogsSource.substring(
    dialogsSource.indexOf('Future<_RoleSimilarityPeers> _loadRoleSimilarityPeers('),
    dialogsSource.indexOf('Future<bool?> openAccessAdminEditRoleDialog('),
  );

  test('similarity peer load is not facility-narrowed', () {
    expect(peerLoaderSource.contains('allFacilities: true'), isTrue);
    expect(
      peerLoaderSource.contains('facilityId:'),
      isFalse,
      reason: 'Peer query must not narrow to the draft facility',
    );
  });

  test('peer pages stay within the backend limit ceiling', () {
    expect(
      peerLoaderSource.contains(
        'AppPageRequest(pageSize: AppPageRequest.maxPageSize)',
      ),
      isTrue,
      reason: 'A larger limit is rejected by workspace query validation',
    );
    expect(
      RegExp(r'pageSize:\s*[0-9]+').hasMatch(peerLoaderSource),
      isFalse,
      reason: 'Peer paging must derive its page size from the shared ceiling',
    );
    expect(peerLoaderSource.contains('request = request.next()'), isTrue);
    expect(
      dialogsSource.contains('_roleSimilarityPeerLimit = 500'),
      isTrue,
      reason: 'Client peer budget must match ROLE_SIMILARITY_LOOKUP_LIMIT',
    );
  });

  test('peer load is search-biased for proposed identity', () {
    expect(peerLoaderSource.contains('search: search'), isTrue);
    expect(peerLoaderSource.contains('searchTerms'), isTrue);
    expect(peerLoaderSource.contains('alphabeticalPeers'), isTrue);
    expect(peerLoaderSource.contains('searchedPeers'), isTrue);
    expect(
      peerLoaderSource.indexOf('...searchedPeers') <
          peerLoaderSource.indexOf('...alphabeticalPeers'),
      isTrue,
      reason: 'Identity search hits must win the fixed 500-peer budget',
    );
    expect(
      peerLoaderSource.contains('requestAllTenants: true'),
      isTrue,
      reason: 'Tenant proposals must also search platform peers',
    );
  });

  test('role details sync permissions through a single role update', () {
    final String repositorySource = File(
      'lib/features/access_admin/data/repositories/access_admin_repository_impl.dart',
    ).readAsStringSync();
    expect(repositorySource.contains("'permission_ids': permissionIds"), isTrue);
    expect(
      repositorySource.contains('ApiEndpoints.byId(HmsApiResource.roles, roleId)'),
      isTrue,
    );
  });

  test('role details avoid force-refreshing the permission catalog', () {
    final String addPermissionsSource = managementSource.substring(
      managementSource.indexOf('Future<void> _addPermissions() async {'),
      managementSource.indexOf('Widget build(BuildContext context) {',
          managementSource.indexOf('Future<void> _addPermissions() async {')),
    );
    expect(
      addPermissionsSource.contains("include: const <String>['permissions']"),
      isTrue,
    );
    expect(
      addPermissionsSource.contains('forceRefresh: true'),
      isFalse,
      reason: 'Add permissions must not re-sync the catalog on every open',
    );
    expect(managementSource.contains('catalogTenantId'), isTrue);
  });

  test('similarity acceptance is scoped to each submitted draft', () {
    expect(
      dialogsSource.contains('var similarityAccepted = draft.confirmSimilar;'),
      isTrue,
    );
  });

  test('failed peer lookup surfaces an error instead of no-similar', () {
    expect(
      dialogsSource.contains(
        'A failed peer lookup must never be reported as "no similar role found".',
      ),
      isTrue,
    );
    expect(dialogsSource.contains('return peerLookup.failure;'), isTrue);
    expect(
      dialogsSource.contains("data.state == 'tenant_context_required'"),
      isTrue,
      reason: 'Scope-required responses return zero items on success',
    );
  });

  test('create-to-detail transition covers the roles list immediately', () {
    expect(
      managementSource.contains('coverListImmediately: true'),
      isTrue,
    );
    expect(
      managementSource.contains('unawaited(reload(resetPage: true, silent: true))'),
      isTrue,
    );
  });

  test('create action remains gated by workspace write access', () {
    expect(
      RegExp(
        r'trailingActions:\s*!isPermissions\s*&&\s*canWrite\s*&&\s*'
        r'widget\.showCreateAction',
      ).hasMatch(managementSource),
      isTrue,
    );
  });

  test('mutation dialog ignores cancelled failures as soft dismiss', () {
    expect(
      mutationDialogSource.contains(
        'failure.category == AppFailureCategory.cancelled',
      ),
      isTrue,
    );
  });

  test('exact duplicate conflict does not retry create after empty confirm', () {
    expect(dialogsSource.contains('_isRoleDuplicateNameConflict'), isTrue);
    expect(
      dialogsSource.contains('!similarityAccepted || isExactNameConflict'),
      isTrue,
    );
  });

  test('edit reuses create similarity with self exclusion', () {
    final String editSource = dialogsSource.substring(
      dialogsSource.indexOf('Future<bool?> openAccessAdminEditRoleDialog('),
    );
    expect(editSource.contains('excludeRoleId: excludeRoleId'), isTrue);
    expect(editSource.contains('_reviewRoleSimilarity'), isTrue);
    expect(editSource.contains('identityChanged'), isTrue);
    expect(
      dialogsSource.contains('excludeRoleId: excludeRoleId,'),
      isTrue,
    );
    expect(
      dialogsSource.contains('excludeRoleId: excludeRoleId'),
      isTrue,
      reason: 'Edit peer scoring must exclude the role being edited',
    );
  });

  test('similarity dialog and engine surface role scope', () {
    final String similaritySource = File(
      'lib/features/access_admin/domain/entities/role_similarity.dart',
    ).readAsStringSync();
    final String dialogSource = File(
      'lib/features/access_admin/presentation/widgets/role_similarity_dialog.dart',
    ).readAsStringSync();
    expect(similaritySource.contains('formatRoleScopeLabel'), isTrue);
    expect(similaritySource.contains('roleScopeWeight'), isTrue);
    expect(similaritySource.contains("field: 'scope'"), isTrue);
    expect(
      dialogSource.contains("'scope' => l10n.accessAdminRoleScopeLabel"),
      isTrue,
    );
    expect(dialogSource.contains('_proposedScopeLabel'), isTrue);
  });

  test('roles soft-delete lifecycle exposes restore and permanent delete', () {
    expect(managementSource.contains('includeDeleted:'), isTrue);
    expect(managementSource.contains('_confirmRestoreRole'), isTrue);
    expect(managementSource.contains('_confirmPermanentDeleteRole'), isTrue);
    expect(
      managementSource.contains('tenantFacilityPermanentDeleteAction'),
      isTrue,
    );
    expect(
      managementSource.contains('accessAdminPermanentDeleteRoleWarningBody'),
      isTrue,
    );
    expect(
      managementSource.contains('_rolePermanentDeleteNameMatches'),
      isTrue,
      reason: 'Type-to-confirm must accept title and Deleted label variants',
    );
    expect(
      managementSource.contains('_isSameAccessAdminRole'),
      isTrue,
      reason: 'Permanent delete must remove by UUID, not display id',
    );
    expect(
      managementSource.contains('_mergeRoleLifecycleItems'),
      isTrue,
      reason: 'Soft-delete must survive stale silent reloads',
    );
    expect(
      managementSource.contains('_markRoleSoftDeletedLocally'),
      isTrue,
    );
    expect(
      managementSource.contains('_syncRoleListAfterLifecycle'),
      isTrue,
      reason: 'Lifecycle actions sync the list without session rehydrate storms',
    );
    expect(
      managementSource.contains('rehydrateSession'),
      isFalse,
      reason: 'Soft-delete must not remount setup via session rehydrate',
    );
    expect(
      managementSource.contains('_runRoleLifecycleMutation'),
      isTrue,
    );
    expect(
      managementSource.contains('LinearProgressIndicator'),
      isTrue,
      reason: 'Role lifecycle mutations must show a list progress indicator',
    );
    expect(
      managementSource.contains('isLoading: rowBusy'),
      isTrue,
      reason: 'Row actions must surface loading while the mutation runs',
    );
    expect(
      managementSource.contains('spacing: actionGap'),
      isTrue,
      reason: 'Edit/Delete and Restore/permanent actions must not sit flush',
    );
    final String repositorySource = File(
      'lib/features/access_admin/data/repositories/access_admin_repository_impl.dart',
    ).readAsStringSync();
    expect(repositorySource.contains('restoreRole'), isTrue);
    expect(repositorySource.contains('permanentDeleteRole'), isTrue);
  });

  test('unauthorized role row actions stay gated by canWrite', () {
    expect(
      RegExp(
        r'if\s*\(canWrite\)\s*AppListTableColumn<AccessAdminItem>\(',
      ).hasMatch(managementSource),
      isTrue,
    );
  });
}
