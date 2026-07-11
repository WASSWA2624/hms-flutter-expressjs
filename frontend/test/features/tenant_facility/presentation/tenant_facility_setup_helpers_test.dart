import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/features/tenant_facility/presentation/widgets/tenant_facility_setup_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_en.dart';

void main() {
  group('tenantFacilityFacilityTypeIcon', () {
    test('returns distinct icons for each facility type', () {
      final Set<IconData> icons = FacilitySetupType.values
          .map(tenantFacilityFacilityTypeIcon)
          .toSet();

      expect(icons.length, FacilitySetupType.values.length);
    });
  });

  group('tenant facility wizard completion', () {
    test('marks all steps complete for a fully configured snapshot', () {
      const FacilitySetupSnapshot snapshot = FacilitySetupSnapshot(
        tenant: TenantProfile(id: 'TEN0001', name: 'Acme'),
        facility: FacilityProfile(
          id: 'FAC0001',
          tenantId: 'TEN0001',
          name: 'Main Campus',
          type: FacilitySetupType.hospital,
          logoUrl: 'https://example.com/logo.png',
        ),
        contactAddress: FacilityContactAddress(phone: '+256700000000'),
        branches: <BranchProfile>[
          BranchProfile(
            id: 'BRN0001',
            tenantId: 'TEN0001',
            name: 'Main',
            facilityId: 'FAC0001',
          ),
        ],
        departments: <DepartmentProfile>[
          DepartmentProfile(
            id: 'DEP0001',
            tenantId: 'TEN0001',
            facilityId: 'FAC0001',
            name: 'Emergency',
            type: DepartmentSetupType.clinical,
          ),
        ],
        units: <UnitProfile>[
          UnitProfile(
            id: 'UNI0001',
            tenantId: 'TEN0001',
            facilityId: 'FAC0001',
            name: 'Triage',
            departmentId: 'DEP0001',
          ),
        ],
        wards: <WardProfile>[
          WardProfile(
            id: 'WRD0001',
            tenantId: 'TEN0001',
            facilityId: 'FAC0001',
            name: 'General',
            type: WardSetupType.general,
          ),
        ],
        rooms: <RoomProfile>[
          RoomProfile(
            id: 'ROM0001',
            tenantId: 'TEN0001',
            facilityId: 'FAC0001',
            name: 'Consult 1',
            wardId: 'WRD0001',
          ),
        ],
        beds: <BedProfile>[
          BedProfile(
            id: 'BED0001',
            tenantId: 'TEN0001',
            facilityId: 'FAC0001',
            wardId: 'WRD0001',
            label: 'Bed 1',
            status: BedSetupStatus.available,
          ),
        ],
      );

      expect(tenantFacilityNextIncompleteWizardStep(snapshot), isNull);
      expect(snapshot.completedChecklistItems, 8);
      for (final TenantFacilitySetupWizardStep step
          in TenantFacilitySetupWizardStep.values) {
        expect(tenantFacilityWizardStepCompleted(snapshot, step), isTrue);
      }
    });

    test(
      'returns rooms as next required step when departments exist but no care spaces',
      () {
        const FacilitySetupSnapshot snapshot = FacilitySetupSnapshot(
          tenant: TenantProfile(id: 'TEN0001', name: 'Acme'),
          facility: FacilityProfile(
            id: 'FAC0001',
            tenantId: 'TEN0001',
            name: 'Main Campus',
            type: FacilitySetupType.hospital,
          ),
          contactAddress: FacilityContactAddress(phone: '+256700000000'),
          departments: <DepartmentProfile>[
            DepartmentProfile(
              id: 'DEP0001',
              tenantId: 'TEN0001',
              facilityId: 'FAC0001',
              name: 'Emergency',
              type: DepartmentSetupType.clinical,
            ),
          ],
        );

        expect(
          tenantFacilityNextIncompleteWizardStep(snapshot),
          TenantFacilitySetupWizardStep.rooms,
        );
      },
    );

    test('treats units as optional and incomplete until created', () {
      const FacilitySetupSnapshot snapshot = FacilitySetupSnapshot(
        tenant: TenantProfile(id: 'TEN0001', name: 'Acme'),
        facility: FacilityProfile(
          id: 'FAC0001',
          tenantId: 'TEN0001',
          name: 'Main Campus',
          type: FacilitySetupType.hospital,
        ),
        contactAddress: FacilityContactAddress(phone: '+256700000000'),
        departments: <DepartmentProfile>[
          DepartmentProfile(
            id: 'DEP0001',
            tenantId: 'TEN0001',
            facilityId: 'FAC0001',
            name: 'Emergency',
            type: DepartmentSetupType.clinical,
          ),
        ],
      );

      expect(
        tenantFacilityWizardStepOptional(TenantFacilitySetupWizardStep.units),
        isTrue,
      );
      expect(
        tenantFacilityWizardStepCompleted(
          snapshot,
          TenantFacilitySetupWizardStep.units,
        ),
        isFalse,
      );
      expect(
        tenantFacilityWizardStepBlocksProgress(
          snapshot,
          TenantFacilitySetupWizardStep.units,
        ),
        isFalse,
      );
    });

    test('locks later steps until required prerequisites are complete', () {
      const FacilitySetupSnapshot snapshot = FacilitySetupSnapshot(
        tenant: TenantProfile(id: 'TEN0001', name: 'Acme'),
        facility: FacilityProfile(
          id: 'FAC0001',
          tenantId: 'TEN0001',
          name: 'Main Campus',
          type: FacilitySetupType.hospital,
        ),
        contactAddress: FacilityContactAddress(phone: '+256700000000'),
      );
      final List<TenantFacilitySetupWizardStep> steps =
          TenantFacilitySetupWizardStep.values;

      expect(
        tenantFacilityWizardStepReachable(
          snapshot,
          steps,
          TenantFacilitySetupWizardStep.facility,
        ),
        isTrue,
      );
      expect(
        tenantFacilityWizardStepReachable(
          snapshot,
          steps,
          TenantFacilitySetupWizardStep.departments,
        ),
        isTrue,
      );
      expect(
        tenantFacilityWizardStepReachable(
          snapshot,
          steps,
          TenantFacilitySetupWizardStep.rooms,
        ),
        isFalse,
      );
    });

    test('hides tenant steps for facility admins', () {
      final List<TenantFacilitySetupWizardStep> steps =
          tenantFacilityVisibleWizardSteps(
            canManageTenant: false,
            canManageFacility: true,
          );

      expect(steps.contains(TenantFacilitySetupWizardStep.tenant), isFalse);
      expect(steps.contains(TenantFacilitySetupWizardStep.branches), isFalse);
      expect(steps.first, TenantFacilitySetupWizardStep.facility);
    });
  });

  group('tenantFacilityFacilityTypeLabel', () {
    test('returns localized labels', () {
      final AppLocalizations l10n = AppLocalizationsEn();

      expect(
        tenantFacilityFacilityTypeLabel(l10n, FacilitySetupType.hospital),
        l10n.authFacilityTypeHospital,
      );
    });
  });
}
