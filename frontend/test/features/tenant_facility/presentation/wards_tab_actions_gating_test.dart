import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Wards tab prompt behaviors', () {
    late String setupPageSource;
    late String helpersSource;
    late String repositorySource;
    late String repositoryInterfaceSource;
    late String wardSimilaritySource;
    late String wardSimilarityDialogSource;

    setUpAll(() {
      setupPageSource = File(
        'lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart',
      ).readAsStringSync();
      helpersSource = File(
        'lib/features/tenant_facility/presentation/widgets/tenant_facility_setup_helpers.dart',
      ).readAsStringSync();
      repositorySource = File(
        'lib/features/tenant_facility/data/repositories/tenant_facility_repository_impl.dart',
      ).readAsStringSync();
      repositoryInterfaceSource = File(
        'lib/features/tenant_facility/domain/repositories/tenant_facility_repository.dart',
      ).readAsStringSync();
      wardSimilaritySource = File(
        'lib/features/tenant_facility/domain/entities/ward_similarity.dart',
      ).readAsStringSync();
      wardSimilarityDialogSource = File(
        'lib/features/tenant_facility/presentation/widgets/ward_similarity_dialog.dart',
      ).readAsStringSync();
    });

    String wardSectionSource() {
      final int sectionStart = setupPageSource.indexOf(
        'class _WardSetupSection extends ConsumerStatefulWidget',
      );
      final int nextSectionStart = setupPageSource.indexOf(
        'class _RoomSetupSection extends ConsumerStatefulWidget',
      );
      expect(sectionStart, greaterThanOrEqualTo(0));
      expect(nextSectionStart, greaterThan(sectionStart));
      return setupPageSource.substring(sectionStart, nextSectionStart);
    }

    String wardFormSource() {
      final int formStart = setupPageSource.indexOf(
        'class _WardFormDialog extends ConsumerStatefulWidget',
      );
      final int nextStart = setupPageSource.indexOf(
        'class _RoomFormDialog extends ConsumerStatefulWidget',
      );
      expect(formStart, greaterThanOrEqualTo(0));
      expect(nextStart, greaterThan(formStart));
      return setupPageSource.substring(formStart, nextStart);
    }

    test('ward section gates Add on accessible departments, not snapshot', () {
      final String sectionSource = wardSectionSource().replaceAll('\r\n', '\n');

      expect(sectionSource.contains('_accessibleDepartments.isNotEmpty'), isTrue);
      expect(sectionSource.contains('_departmentsReady'), isTrue);
      expect(
        sectionSource.contains('l10n.tenantFacilityGateNeedDepartmentForWards'),
        isTrue,
      );
      expect(
        sectionSource.contains('snapshot.departments.isNotEmpty'),
        isFalse,
      );
      expect(
        sectionSource.contains(
          'canManageRecords &&\n        prerequisitesMet &&\n        !isSubmitting &&\n        _busyWardId == null',
        ),
        isTrue,
      );
    });

    test('ward list loads through scoped listWards API', () {
      final String sectionSource = wardSectionSource();
      expect(sectionSource.contains('listWards('), isTrue);
      expect(sectionSource.contains('tenantFacilityWardsListScope'), isTrue);
      expect(
        repositoryInterfaceSource.contains(
          'Future<Result<AppPage<WardProfile>>> listWards({',
        ),
        isTrue,
      );
      expect(
        repositorySource.contains(
          'Future<Result<AppPage<WardProfile>>> listWards({',
        ),
        isTrue,
      );
      expect(repositorySource.contains("'department_id': departmentId"), isTrue);
      expect(repositorySource.contains("'ward_type': type?.apiValue"), isTrue);
    });

    test('ward mutations keep Add visible with loading while submitting', () {
      final String sectionSource = wardSectionSource();
      expect(sectionSource.contains('isSubmitting: isSubmitting'), isTrue);
      expect(
        sectionSource.contains(
          'canManageRecords = canSubmit && !submission.isSubmitting',
        ),
        isFalse,
      );
      expect(sectionSource.contains('canManageRecords = widget.canSubmit'), isTrue);
    });

    test('ward list uses branded loader and row-scoped mutation busy', () {
      final String sectionSource = wardSectionSource();
      expect(
        sectionSource.contains('AppLoadingIndicator.compact('),
        isTrue,
      );
      expect(sectionSource.contains('title: l10n.commonLoadingTitle'), isTrue);
      expect(sectionSource.contains('body: l10n.commonLoadingBody'), isTrue);
      expect(sectionSource.contains('AppWorkspaceStatePanel.error('), isTrue);
      expect(sectionSource.contains('commonRetryActionLabel'), isTrue);
      expect(sectionSource.contains('busyItemId: _busyWardId'), isTrue);
      expect(sectionSource.contains('itemIdBuilder:'), isTrue);
      expect(sectionSource.contains('_runBusyWardAction'), isTrue);
      expect(sectionSource.contains('onRestore:'), isTrue);
      expect(sectionSource.contains('onPermanentDelete:'), isFalse);
    });

    test('role-scoped columns and filters for wards', () {
      final String sectionSource = wardSectionSource();
      expect(
        sectionSource.contains('tenantFacilityWardsShowsTenantColumn'),
        isTrue,
      );
      expect(
        sectionSource.contains('tenantFacilityWardsShowsFacilityColumn'),
        isTrue,
      );
      expect(
        sectionSource.contains('TenantFacilityWardsFilterKeys.tenant'),
        isTrue,
      );
      expect(
        sectionSource.contains('TenantFacilityWardsFilterKeys.facility'),
        isTrue,
      );
      expect(
        sectionSource.contains('TenantFacilityWardsFilterKeys.department'),
        isTrue,
      );
      expect(
        sectionSource.contains('TenantFacilityWardsFilterKeys.type'),
        isTrue,
      );
      expect(
        sectionSource.contains('TenantFacilityWardsFilterKeys.active'),
        isTrue,
      );
      expect(
        helpersSource.contains('abstract final class TenantFacilityWardsFilterKeys'),
        isTrue,
      );
      expect(
        helpersSource.contains(
          'typedef TenantFacilityWardsListScope = TenantFacilityDepartmentsListScope',
        ),
        isTrue,
      );
    });

    test('wards nest department/facility/tenant under name with type default column', () {
      final String sectionSource = wardSectionSource().replaceAll('\r\n', '\n');
      expect(sectionSource.contains("id: 'type'"), isTrue);
      expect(sectionSource.contains('nameDetailBuilder:'), isTrue);
      expect(
        sectionSource.contains("id: 'department'"),
        isFalse,
      );
      expect(
        sectionSource.contains("id: 'facility'"),
        isFalse,
      );
      expect(
        sectionSource.contains("id: 'tenant'"),
        isFalse,
      );
      expect(sectionSource.contains("?? '—'"), isTrue);
      expect(sectionSource.contains('?? facilityId'), isFalse);
      expect(sectionSource.contains('?? tenantId'), isFalse);
      expect(sectionSource.contains('??\n        departmentId'), isFalse);
    });

    test('role-aware create pickers and optional department', () {
      final String formSource = wardFormSource().replaceAll('\r\n', '\n');
      expect(formSource.contains('showTenantPicker'), isTrue);
      expect(formSource.contains('showFacilityPicker'), isTrue);
      expect(formSource.contains('tenantFacilityWardsListScope'), isTrue);
      expect(
        formSource.contains('l10n.tenantFacilityWardDepartmentLabel'),
        isTrue,
      );
      expect(formSource.contains('isRequired: true'), isTrue);
      // Department is optional — field is not marked required.
      expect(
        formSource.contains(
          'labelText: l10n.tenantFacilityWardDepartmentLabel,\n      options:',
        ),
        isTrue,
      );
    });

    test('create and edit always open ward similarity dialog', () {
      final String formSource = wardFormSource();
      expect(formSource.contains('showWardSimilarityDialog'), isTrue);
      expect(formSource.contains('checkWardDuplicates'), isTrue);
      expect(formSource.contains('_checkingSimilarity'), isTrue);
      expect(formSource.contains('excludeWardId'), isTrue);
      expect(
        formSource.contains('normalizeWardName(name) == normalizeWardName(editing.name)'),
        isFalse,
      );
      expect(
        formSource.contains('reviewMatches.isEmpty)'),
        isFalse,
      );
      expect(wardSimilaritySource.contains('checkWardDuplicates'), isTrue);
      expect(
        wardSimilarityDialogSource.contains('showWardSimilarityDialog'),
        isTrue,
      );
      expect(
        wardSimilarityDialogSource.contains('WardSimilarityAction.proceed'),
        isTrue,
      );
      expect(
        wardSimilarityDialogSource.contains('WardSimilarityAction.cancel'),
        isTrue,
      );
    });

    test('ward form uses blocking loading overlay instead of inline spinner', () {
      final String formSource = wardFormSource();
      expect(formSource.contains('AbsorbPointer'), isTrue);
      expect(formSource.contains('Positioned.fill'), isTrue);
      expect(formSource.contains('showLoadingOverlay'), isTrue);
      expect(formSource.contains('AppLoadingIndicator('), isTrue);
      expect(formSource.contains('body: overlayBody'), isTrue);
      expect(
        formSource.contains(
          'const AppLoadingIndicator.compact(expand: false),\n                    SizedBox(width: theme.spacing.sm),',
        ),
        isFalse,
      );
    });

    test('successful create/edit opens ward details dialog', () {
      expect(setupPageSource.contains('showWardDetailsDialog'), isTrue);
      expect(setupPageSource.contains('_openWardDetails'), isTrue);
      expect(setupPageSource.contains('lastSavedWard'), isTrue);
      expect(
        File(
          'lib/features/tenant_facility/presentation/widgets/ward_details_dialog.dart',
        ).existsSync(),
        isTrue,
      );
      final String detailsSource = File(
        'lib/features/tenant_facility/presentation/widgets/ward_details_dialog.dart',
      ).readAsStringSync();
      expect(detailsSource.contains('showTenantFacilityWardFormDialog'), isTrue);
      expect(detailsSource.contains('deleteWard(_ward.id)'), isTrue);
      expect(detailsSource.contains('tenantFacilityEditWardDetailsAction'), isTrue);
      expect(
        detailsSource.contains('tenantFacilityDeleteWardDetailsAction'),
        isTrue,
      );
      expect(detailsSource.contains('return departmentId;'), isFalse);
      final String sectionSource = wardSectionSource();
      expect(sectionSource.contains('onRowSelected:'), isTrue);
      expect(setupPageSource.contains('departmentName: departmentName'), isTrue);
    });
  });
}
