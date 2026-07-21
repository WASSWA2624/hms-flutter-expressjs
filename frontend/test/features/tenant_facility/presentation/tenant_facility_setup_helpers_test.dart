import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
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

    test('lists facility phone as missing when identity is incomplete', () {
      final AppLocalizations l10n = AppLocalizationsEn();
      const FacilitySetupSnapshot snapshot = FacilitySetupSnapshot(
        tenant: TenantProfile(id: 'TEN0001', name: 'Acme'),
        facility: FacilityProfile(
          id: 'FAC0001',
          tenantId: 'TEN0001',
          name: 'Democare Hospital',
          type: FacilitySetupType.hospital,
        ),
      );

      expect(
        tenantFacilityWizardStepMissingRequirements(
          l10n,
          snapshot,
          TenantFacilitySetupWizardStep.facility,
        ),
        <String>[l10n.tenantFacilityWizardMissingFacilityPhone],
      );

      final String? banner = tenantFacilityWizardStepPendingBannerMessage(
        l10n,
        snapshot: snapshot,
        step: TenantFacilitySetupWizardStep.facility,
        nextActionLabel: 'Next: Departments',
      );

      expect(banner, isNotNull);
      expect(banner, contains(l10n.tenantFacilityWizardMissingFacilityPhone));
      expect(banner, contains('Next: Departments'));
    });

    test('exposes a pending checklist for every incomplete wizard step', () {
      final AppLocalizations l10n = AppLocalizationsEn();
      const FacilitySetupSnapshot empty = FacilitySetupSnapshot();

      for (final TenantFacilitySetupWizardStep step
          in TenantFacilitySetupWizardStep.values) {
        final List<TenantFacilityWizardStepRequirement> requirements =
            tenantFacilityWizardStepRequirements(l10n, empty, step);

        expect(requirements, isNotEmpty, reason: step.name);
        expect(
          requirements.any(
            (TenantFacilityWizardStepRequirement item) => !item.satisfied,
          ),
          isTrue,
          reason: step.name,
        );
        expect(
          tenantFacilityWizardStepPendingIntro(
            l10n,
            snapshot: empty,
            step: step,
            nextActionLabel: 'Next: Test',
          ),
          isNotNull,
          reason: step.name,
        );
      }
    });

    test('aggregates prerequisite blockers for later wizard steps', () {
      final AppLocalizations l10n = AppLocalizationsEn();
      const FacilitySetupSnapshot snapshot = FacilitySetupSnapshot(
        tenant: TenantProfile(id: 'TEN0001', name: 'Acme'),
        facility: FacilityProfile(
          id: 'FAC0001',
          tenantId: 'TEN0001',
          name: 'Democare Hospital',
          type: FacilitySetupType.hospital,
        ),
      );

      final List<TenantFacilityWizardStepRequirement> blockers =
          tenantFacilityWizardOutstandingBlockers(
            l10n,
            snapshot,
            TenantFacilitySetupWizardStep.departments,
          );

      expect(
        blockers.map((TenantFacilityWizardStepRequirement item) => item.label),
        containsAll(<String>[
          l10n.tenantFacilityWizardMissingFacilityPhone,
          l10n.tenantFacilityWizardMissingDepartments,
        ]),
      );
      expect(
        tenantFacilityWizardFirstBlockingStep(
          l10n,
          snapshot,
          TenantFacilitySetupWizardStep.departments,
        ),
        TenantFacilitySetupWizardStep.facility,
      );
    });

    test('includes department gate blockers for units rooms and beds', () {
      final AppLocalizations l10n = AppLocalizationsEn();
      const FacilitySetupSnapshot snapshot = FacilitySetupSnapshot(
        tenant: TenantProfile(id: 'TEN0001', name: 'Acme'),
        facility: FacilityProfile(
          id: 'FAC0001',
          tenantId: 'TEN0001',
          name: 'Main',
          type: FacilitySetupType.hospital,
        ),
        contactAddress: FacilityContactAddress(phone: '+256700000000'),
      );

      expect(
        tenantFacilityWizardOutstandingBlockers(
          l10n,
          snapshot,
          TenantFacilitySetupWizardStep.units,
        ).map((TenantFacilityWizardStepRequirement item) => item.label),
        contains(l10n.tenantFacilityWizardMissingDepartments),
      );
      expect(
        tenantFacilityWizardOutstandingBlockers(
          l10n,
          snapshot,
          TenantFacilitySetupWizardStep.beds,
        ).map((TenantFacilityWizardStepRequirement item) => item.label),
        containsAll(<String>[
          l10n.tenantFacilityWizardMissingDepartments,
          l10n.tenantFacilityWizardMissingWards,
          l10n.tenantFacilityWizardMissingBeds,
        ]),
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

  group('tenant facility setup desk sections', () {
    test('omits tenants for facility admins and keeps facility tabs', () {
      final List<TenantFacilitySetupDeskSection> sections =
          tenantFacilityVisibleSetupDeskSections(
            canManageTenant: false,
            canManageFacility: true,
            canManageAccess: true,
          );

      expect(
        sections.contains(TenantFacilitySetupDeskSection.tenants),
        isFalse,
      );
      expect(
        sections.contains(TenantFacilitySetupDeskSection.branches),
        isFalse,
      );
      expect(
        sections.contains(TenantFacilitySetupDeskSection.facility),
        isTrue,
      );
      expect(sections.contains(TenantFacilitySetupDeskSection.users), isTrue);
    });

    test('includes tenants for tenant admins', () {
      final List<TenantFacilitySetupDeskSection> sections =
          tenantFacilityVisibleSetupDeskSections(
            canManageTenant: true,
            canManageFacility: true,
            canManageAccess: true,
          );

      expect(sections.contains(TenantFacilitySetupDeskSection.tenants), isTrue);
      expect(
        sections.contains(TenantFacilitySetupDeskSection.permissions),
        isTrue,
      );
    });

    test('omits access tabs when unauthorized', () {
      final List<TenantFacilitySetupDeskSection> sections =
          tenantFacilityVisibleSetupDeskSections(
            canManageTenant: true,
            canManageFacility: true,
            canManageAccess: false,
          );

      expect(sections.contains(TenantFacilitySetupDeskSection.roles), isFalse);
      expect(
        sections.contains(TenantFacilitySetupDeskSection.permissions),
        isFalse,
      );
      expect(sections.contains(TenantFacilitySetupDeskSection.users), isFalse);
    });
  });

  group('tenantFacilitySetupNavigationLabel', () {
    test('returns platform, tenant, and facility labels by scope', () {
      final AppLocalizations l10n = AppLocalizationsEn();
      final AppAccessPolicy platform = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 't'),
          user: const AuthUserProfile(roles: <String>['SUPER_ADMIN']),
        ),
      );
      final AppAccessPolicy tenant = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 't'),
          user: const AuthUserProfile(
            roles: <String>['TENANT_ADMIN'],
            tenantId: 'TEN0001',
          ),
        ),
      );
      final AppAccessPolicy facility = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 't'),
          user: const AuthUserProfile(
            roles: <String>['FACILITY_ADMIN'],
            tenantId: 'TEN0001',
            facilityId: 'FAC0001',
          ),
        ),
      );

      expect(platform.isPlatformElevated, isTrue);
      expect(
        tenantFacilitySetupNavigationLabel(platform, l10n),
        l10n.navigationPlatformSetupLabel,
      );
      expect(
        tenantFacilitySetupNavigationLabel(tenant, l10n),
        l10n.navigationSetupLabel,
      );
      expect(
        tenantFacilitySetupNavigationLabel(facility, l10n),
        l10n.navigationFacilitySetupLabel,
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

  group('tenantFacilitySetupDeskCreateLabel', () {
    test('returns add labels for creatable tabs and null for permissions', () {
      final AppLocalizations l10n = AppLocalizationsEn();

      expect(
        tenantFacilitySetupDeskCreateLabel(
          l10n,
          TenantFacilitySetupDeskSection.tenants,
        ),
        l10n.tenantFacilityAddTenantAction,
      );
      expect(
        tenantFacilitySetupDeskCreateLabel(
          l10n,
          TenantFacilitySetupDeskSection.roles,
        ),
        l10n.accessAdminCreateRoleAction,
      );
      expect(
        tenantFacilitySetupDeskCreateLabel(
          l10n,
          TenantFacilitySetupDeskSection.permissions,
        ),
        isNull,
      );
    });
  });

  group('tenantFacilitySetupDeskCreateIcon', () {
    test('returns icons for creatable tabs and null for permissions', () {
      expect(
        tenantFacilitySetupDeskCreateIcon(
          TenantFacilitySetupDeskSection.users,
        ),
        Icons.person_add_alt_1_outlined,
      );
      expect(
        tenantFacilitySetupDeskCreateIcon(
          TenantFacilitySetupDeskSection.permissions,
        ),
        isNull,
      );
    });
  });
}
