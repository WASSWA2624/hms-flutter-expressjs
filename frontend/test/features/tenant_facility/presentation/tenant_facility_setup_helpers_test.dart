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
      'returns wards as next step when departments exist but no care spaces',
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
          TenantFacilitySetupWizardStep.wards,
        );
      },
    );

    test('allows optional units when departments exist', () {
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
        tenantFacilityWizardStepCompleted(
          snapshot,
          TenantFacilitySetupWizardStep.units,
        ),
        isTrue,
      );
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
