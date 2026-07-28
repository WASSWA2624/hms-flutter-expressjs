import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Units tab prompt behaviors', () {
    late String setupPageSource;
    late String helpersSource;
    late String repositorySource;
    late String repositoryInterfaceSource;
    late String unitSimilaritySource;
    late String unitSimilarityDialogSource;

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
      unitSimilaritySource = File(
        'lib/features/tenant_facility/domain/entities/unit_similarity.dart',
      ).readAsStringSync();
      unitSimilarityDialogSource = File(
        'lib/features/tenant_facility/presentation/widgets/unit_similarity_dialog.dart',
      ).readAsStringSync();
    });

    String unitSectionSource() {
      final int sectionStart = setupPageSource.indexOf(
        'class _UnitSetupSection extends ConsumerStatefulWidget',
      );
      final int nextSectionStart = setupPageSource.indexOf(
        'class _WardSetupSection extends ConsumerStatefulWidget',
      );
      expect(sectionStart, greaterThanOrEqualTo(0));
      expect(nextSectionStart, greaterThan(sectionStart));
      return setupPageSource.substring(sectionStart, nextSectionStart);
    }

    String unitFormSource() {
      final int formStart = setupPageSource.indexOf(
        'class _UnitFormDialog extends ConsumerStatefulWidget',
      );
      final int nextStart = setupPageSource.indexOf(
        'class _WardFormDialog extends ConsumerStatefulWidget',
      );
      expect(formStart, greaterThanOrEqualTo(0));
      expect(nextStart, greaterThan(formStart));
      return setupPageSource.substring(formStart, nextStart);
    }

    test('unit section gates Add on accessible departments, not snapshot', () {
      final String sectionSource = unitSectionSource().replaceAll('\r\n', '\n');

      expect(sectionSource.contains('_accessibleDepartments.isNotEmpty'), isTrue);
      expect(
        sectionSource.contains('l10n.tenantFacilityGateNeedDepartmentForUnits'),
        isTrue,
      );
      expect(
        sectionSource.contains('snapshot.departments.isNotEmpty'),
        isFalse,
      );
      expect(
        sectionSource.contains(
          'canManageRecords &&\n        prerequisitesMet &&\n        !isSubmitting &&\n        _busyUnitId == null',
        ),
        isTrue,
      );
    });

    test('unit list loads through scoped listUnits API', () {
      final String sectionSource = unitSectionSource();
      expect(sectionSource.contains('listUnits('), isTrue);
      expect(sectionSource.contains('tenantFacilityUnitsListScope'), isTrue);
      expect(
        repositoryInterfaceSource.contains(
          'Future<Result<AppPage<UnitProfile>>> listUnits({',
        ),
        isTrue,
      );
      expect(
        repositorySource.contains(
          'Future<Result<AppPage<UnitProfile>>> listUnits({',
        ),
        isTrue,
      );
      expect(repositorySource.contains("'department_id': departmentId"), isTrue);
    });

    test('unit mutations keep Add visible with loading while submitting', () {
      final String sectionSource = unitSectionSource();
      expect(sectionSource.contains('isSubmitting: isSubmitting'), isTrue);
      expect(
        sectionSource.contains(
          'canManageRecords = canSubmit && !submission.isSubmitting',
        ),
        isFalse,
      );
      expect(sectionSource.contains('canManageRecords = widget.canSubmit'), isTrue);
    });

    test('unit list uses branded loader and row-scoped mutation busy', () {
      final String sectionSource = unitSectionSource();
      expect(
        sectionSource.contains('AppLoadingIndicator.compact()'),
        isTrue,
      );
      expect(sectionSource.contains('busyItemId: _busyUnitId'), isTrue);
      expect(sectionSource.contains('itemIdBuilder:'), isTrue);
      expect(sectionSource.contains('_runBusyUnitAction'), isTrue);
      expect(sectionSource.contains('onRestore:'), isTrue);
      expect(sectionSource.contains('onPermanentDelete:'), isFalse);
    });

    test('role-scoped columns and filters for units', () {
      final String sectionSource = unitSectionSource();
      expect(
        sectionSource.contains('tenantFacilityUnitsShowsTenantColumn'),
        isTrue,
      );
      expect(
        sectionSource.contains('tenantFacilityUnitsShowsFacilityColumn'),
        isTrue,
      );
      expect(
        sectionSource.contains('TenantFacilityUnitsFilterKeys.tenant'),
        isTrue,
      );
      expect(
        sectionSource.contains('TenantFacilityUnitsFilterKeys.facility'),
        isTrue,
      );
      expect(
        sectionSource.contains('TenantFacilityUnitsFilterKeys.department'),
        isTrue,
      );
      expect(
        sectionSource.contains('TenantFacilityUnitsFilterKeys.active'),
        isTrue,
      );
      expect(
        helpersSource.contains('abstract final class TenantFacilityUnitsFilterKeys'),
        isTrue,
      );
      expect(
        helpersSource.contains(
          'typedef TenantFacilityUnitsListScope = TenantFacilityDepartmentsListScope',
        ),
        isTrue,
      );
    });

    test('role-aware create pickers and required department', () {
      final String formSource = unitFormSource();
      expect(formSource.contains('showTenantPicker'), isTrue);
      expect(formSource.contains('showFacilityPicker'), isTrue);
      expect(formSource.contains('tenantFacilityUnitsListScope'), isTrue);
      expect(formSource.contains('isRequired: true'), isTrue);
      expect(
        formSource.contains('l10n.tenantFacilityUnitDepartmentLabel'),
        isTrue,
      );
    });

    test('create and edit always open unit similarity dialog', () {
      final String formSource = unitFormSource();
      expect(formSource.contains('showUnitSimilarityDialog'), isTrue);
      expect(formSource.contains('checkUnitDuplicates'), isTrue);
      expect(formSource.contains('_checkingSimilarity'), isTrue);
      expect(formSource.contains('excludeUnitId'), isTrue);
      expect(unitSimilaritySource.contains('checkUnitDuplicates'), isTrue);
      expect(
        unitSimilarityDialogSource.contains('showUnitSimilarityDialog'),
        isTrue,
      );
      expect(
        unitSimilarityDialogSource.contains('UnitSimilarityAction.proceed'),
        isTrue,
      );
      expect(
        unitSimilarityDialogSource.contains('UnitSimilarityAction.cancel'),
        isTrue,
      );
    });
  });
}
