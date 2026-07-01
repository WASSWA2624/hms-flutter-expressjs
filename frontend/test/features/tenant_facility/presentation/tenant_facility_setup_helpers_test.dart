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
      );

      expect(tenantFacilityNextIncompleteWizardStep(snapshot), isNull);
      expect(snapshot.completedChecklistItems, 4);
      for (final TenantFacilitySetupWizardStep step
          in TenantFacilitySetupWizardStep.values) {
        expect(tenantFacilityWizardStepCompleted(snapshot, step), isTrue);
      }
    });

    test('returns care spaces as next step when organization is complete', () {
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
        units: <UnitProfile>[
          UnitProfile(
            id: 'UNI0001',
            tenantId: 'TEN0001',
            facilityId: 'FAC0001',
            name: 'Triage',
            departmentId: 'DEP0001',
          ),
        ],
      );

      expect(
        tenantFacilityNextIncompleteWizardStep(snapshot),
        TenantFacilitySetupWizardStep.careSpaces,
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
