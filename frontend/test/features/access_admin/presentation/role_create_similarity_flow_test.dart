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
    expect(
      peerLoaderSource.contains('requestAllTenants: true'),
      isTrue,
      reason: 'Tenant proposals must also search platform peers',
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
}
