import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Departments tab prompt behaviors', () {
    late String setupPageSource;
    late String helpersSource;
    late String controllerSource;
    late String repositorySource;
    late String repositoryInterfaceSource;

    setUpAll(() {
      setupPageSource = File(
        'lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart',
      ).readAsStringSync();
      helpersSource = File(
        'lib/features/tenant_facility/presentation/widgets/tenant_facility_setup_helpers.dart',
      ).readAsStringSync();
      controllerSource = File(
        'lib/features/tenant_facility/presentation/controllers/tenant_facility_setup_controller.dart',
      ).readAsStringSync();
      repositorySource = File(
        'lib/features/tenant_facility/data/repositories/tenant_facility_repository_impl.dart',
      ).readAsStringSync();
      repositoryInterfaceSource = File(
        'lib/features/tenant_facility/domain/repositories/tenant_facility_repository.dart',
      ).readAsStringSync();
    });

    String departmentSectionSource() {
      final int sectionStart = setupPageSource.indexOf(
        'class _DepartmentSetupSection extends ConsumerStatefulWidget',
      );
      final int nextSectionStart = setupPageSource.indexOf(
        'class _UnitSetupSection extends ConsumerWidget',
      );
      expect(sectionStart, greaterThanOrEqualTo(0));
      expect(nextSectionStart, greaterThan(sectionStart));
      return setupPageSource.substring(sectionStart, nextSectionStart);
    }

    test('department section gates Add for facility admins only', () {
      final String sectionSource = departmentSectionSource();

      expect(
        sectionSource.contains(
          'createScope == TenantFacilityDepartmentsListScope.facility',
        ),
        isTrue,
      );
      expect(
        sectionSource.contains(
          'canAdd = canManageRecords && prerequisitesMet && !isSubmitting',
        ),
        isTrue,
      );
      expect(
        sectionSource.contains('l10n.tenantFacilityGateNeedFacility'),
        isTrue,
      );
      expect(sectionSource.contains('onPermanentDelete:'), isTrue);
      expect(sectionSource.contains('onRowSelected:'), isTrue);
    });

    test('soft-deleted rows expose restore and permanent delete', () {
      expect(setupPageSource.contains('onPermanentDelete'), isTrue);
      expect(setupPageSource.contains('_permanentDeleteEntity'), isTrue);
      expect(
        setupPageSource.contains('tenantFacilityPermanentDeleteAction'),
        isTrue,
      );
      expect(
        setupPageSource.contains(
          'Icons.delete_forever_outlined',
        ),
        isTrue,
      );
    });

    test('permanent delete is wired through controller and repository', () {
      expect(
        controllerSource.contains('Future<bool> permanentDeleteDepartment'),
        isTrue,
      );
      expect(
        repositorySource.contains('permanentDeleteDepartment'),
        isTrue,
      );
      expect(
        repositorySource.contains("'permanent'"),
        isTrue,
      );
    });

    test('department mutations keep Add visible with loading while submitting', () {
      final String sectionSource = departmentSectionSource();
      expect(sectionSource.contains('isSubmitting: isSubmitting'), isTrue);
      expect(
        sectionSource.contains(
          'canManageRecords = canSubmit && !submission.isSubmitting',
        ),
        isFalse,
      );
    });

    test('department list loads through scoped listDepartments API', () {
      final String sectionSource = departmentSectionSource();
      expect(sectionSource.contains('repository.listDepartments('), isTrue);
      expect(
        sectionSource.contains('tenantFacilityDepartmentsListScope(policy)'),
        isTrue,
      );
      expect(
        repositoryInterfaceSource.contains(
          'Future<Result<AppPage<DepartmentProfile>>> listDepartments({',
        ),
        isTrue,
      );
      expect(
        repositorySource.contains(
          'Future<Result<AppPage<DepartmentProfile>>> listDepartments({',
        ),
        isTrue,
      );
    });

    test('department columns are role-scoped', () {
      final String sectionSource = departmentSectionSource();
      expect(sectionSource.contains("id: 'facility'"), isTrue);
      expect(sectionSource.contains("id: 'tenant'"), isTrue);
      expect(sectionSource.contains("id: 'type'"), isTrue);
      expect(sectionSource.contains('statusLabelBuilder:'), isTrue);
      expect(
        sectionSource.contains('tenantFacilityDepartmentsShowsTenantColumn'),
        isTrue,
      );
      expect(
        sectionSource.contains('tenantFacilityDepartmentsShowsFacilityColumn'),
        isTrue,
      );
      expect(
        sectionSource.contains('tenantFacilityDepartmentsShowsDetailColumns'),
        isTrue,
      );
      expect(
        sectionSource.contains('setup_structure_departments_'),
        isTrue,
      );
      expect(sectionSource.contains('scope.name'), isTrue);
      expect(helpersSource.contains('enum TenantFacilityDepartmentsListScope'), isTrue);
    });

    test('department filters are comprehensive and admin-scoped', () {
      final String sectionSource = departmentSectionSource();
      expect(sectionSource.contains('_buildFilterGroups'), isTrue);
      expect(sectionSource.contains('extraFilterGroups:'), isTrue);
      expect(sectionSource.contains('onFiltersChanged:'), isTrue);
      expect(sectionSource.contains('type: _typeFilter'), isTrue);
      expect(sectionSource.contains('isActive: _isActiveFilter'), isTrue);
      expect(
        sectionSource.contains('tenantFacilityDepartmentsShowsTenantFilter'),
        isTrue,
      );
      expect(
        sectionSource.contains('tenantFacilityDepartmentsShowsFacilityFilter'),
        isTrue,
      );
      expect(
        sectionSource.contains('TenantFacilityDepartmentsFilterKeys.tenant'),
        isTrue,
      );
      expect(
        sectionSource.contains('TenantFacilityDepartmentsFilterKeys.facility'),
        isTrue,
      );
      expect(
        sectionSource.contains('TenantFacilityDepartmentsFilterKeys.type'),
        isTrue,
      );
      expect(
        sectionSource.contains('TenantFacilityDepartmentsFilterKeys.active'),
        isTrue,
      );
      expect(
        helpersSource.contains('class TenantFacilityDepartmentsFilterKeys'),
        isTrue,
      );
      expect(
        repositorySource.contains("'department_type': type?.apiValue"),
        isTrue,
      );
    });

    test('edit department keeps the department facility and tenant', () {
      expect(
        setupPageSource.contains('editing.tenantId.trim().isNotEmpty'),
        isTrue,
      );
      expect(
        setupPageSource.contains('editing.facilityId?.trim().isNotEmpty == true'),
        isTrue,
      );
    });

    test('structure submit gating uses permission only', () {
      expect(
        setupPageSource.contains(
          'final bool canSubmitStructure = widget.canEditStructure;',
        ),
        isTrue,
      );
      expect(
        setupPageSource.contains(
          'widget.canEditStructure && snapshot.facility != null',
        ),
        isFalse,
      );
    });
  });
}
