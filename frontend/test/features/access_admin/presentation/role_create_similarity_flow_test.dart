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

  test('backend uniqueness conflict reopens similarity review', () {
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

  test('similarity peer load is not facility-narrowed', () {
    expect(dialogsSource.contains('allFacilities: true'), isTrue);
    expect(
      dialogsSource.contains(
        'Load tenant-wide (all facilities) or all tenants for platform proposals',
      ),
      isTrue,
    );
    expect(
      RegExp(
        r'_loadRoleSimilarityPeers\([\s\S]*?facilityId:\s*null',
        multiLine: true,
      ).hasMatch(dialogsSource),
      isTrue,
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
}
