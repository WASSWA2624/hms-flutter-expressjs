import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pharmacy_access.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/widgets/pharmacy_scope_navigation.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';

/// Cross-cutting locks for `prompts/12-pharmacy/99-convention-gaps.md`.
/// Per-tab UI matrices live in the `*_permissions_test.dart` suite.
void main() {
  group('Pharmacy convention gaps — access / count / tone locks', () {
    test('Export and Print share ∩ evidence:export (omit when unauthorized)', () {
      expect(
        identical(
          pharmacyWorkspaceExportRequirement,
          pharmacyWorkspacePrintRequirement,
        ),
        isTrue,
      );

      final AppAccessPolicy reader = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'token'),
          user: const AuthUserProfile(
            roles: <String>['PHARMACIST'],
            tenantId: 'tenant-1',
            facilityId: 'facility-1',
          ),
          permissions: <AppPermission>{AppPermissions.pharmacyRead},
          moduleEntitlements: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: pharmacyDispensingModule,
              licenseStatus: 'ACTIVE',
            ),
          ],
          isAuthorizationHydrated: true,
        ),
      );
      final AppAccessPolicy exporter = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'token'),
          user: const AuthUserProfile(
            roles: <String>['PHARMACIST'],
            tenantId: 'tenant-1',
            facilityId: 'facility-1',
          ),
          permissions: <AppPermission>{
            AppPermissions.pharmacyRead,
            AppPermissions.evidenceExport,
          },
          moduleEntitlements: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: pharmacyDispensingModule,
              licenseStatus: 'ACTIVE',
            ),
          ],
          isAuthorizationHydrated: true,
        ),
      );

      expect(canExportPharmacyWorkspace(reader), isFalse);
      expect(canPrintPharmacyWorkspace(reader), isFalse);
      expect(canExportPharmacyWorkspace(exporter), isTrue);
      expect(canPrintPharmacyWorkspace(exporter), isTrue);
    });

    test('sibling counts use summary/stock totals; active uses filtered page totals', () {
      final PharmacyWorkspaceState state = PharmacyWorkspaceState(
        query: const PharmacyWorkbenchQuery(),
        workbench: const PharmacyWorkbench(
          summary: PharmacyWorkbenchSummary(
            orderedQueue: 9,
            totalOrders: 20,
          ),
          orders: AppPage<PharmacyOrder>(
            items: <PharmacyOrder>[],
            request: AppPageRequest(),
            totalItemCount: 2,
          ),
        ),
        drugQuery: const PharmacyDrugQuery(),
        drugs: const AppPage<PharmacyDrug>(
          items: <PharmacyDrug>[],
          request: AppPageRequest(),
        ),
        formularyQuery: const PharmacyFormularyQuery(),
        formularyItems: const AppPage<PharmacyFormularyItem>(
          items: <PharmacyFormularyItem>[],
          request: AppPageRequest(),
        ),
        inventoryQuery: const PharmacyInventoryStockQuery(),
        inventoryWorkbench: const PharmacyInventoryWorkbench(
          summary: PharmacyInventoryStockSummary(),
          stocks: AppPage<PharmacyInventoryStock>(
            items: <PharmacyInventoryStock>[],
            request: AppPageRequest(),
            totalItemCount: 3,
          ),
        ),
        stockAlertSummary: const PharmacyInventoryStockSummary(
          expiringSoonRows: 11,
          outOfStockRows: 5,
        ),
      );

      expect(pharmacySectionTabCount(state, PharmacyDeskSection.queue), 9);
      expect(
        pharmacySectionTabCount(
          state,
          PharmacyDeskSection.queue,
          activeSection: PharmacyDeskSection.queue,
        ),
        2,
      );
      expect(pharmacySectionTabCount(state, PharmacyDeskSection.nearExpiry), 11);
      expect(
        pharmacySectionTabCount(
          state,
          PharmacyDeskSection.nearExpiry,
          activeSection: PharmacyDeskSection.nearExpiry,
        ),
        3,
      );
      expect(pharmacySectionTabCount(state, PharmacyDeskSection.outOfStock), 5);
    });

    test('count tones keep warning/danger only for attention queues', () {
      expect(
        pharmacySectionCountTone(PharmacyDeskSection.queue),
        AppTabCountTone.warning,
      );
      expect(
        pharmacySectionCountTone(PharmacyDeskSection.nearExpiry),
        AppTabCountTone.warning,
      );
      expect(
        pharmacySectionCountTone(PharmacyDeskSection.lowStock),
        AppTabCountTone.warning,
      );
      expect(
        pharmacySectionCountTone(PharmacyDeskSection.cancelled),
        AppTabCountTone.danger,
      );
      expect(
        pharmacySectionCountTone(PharmacyDeskSection.expired),
        AppTabCountTone.danger,
      );
      expect(
        pharmacySectionCountTone(PharmacyDeskSection.outOfStock),
        AppTabCountTone.danger,
      );
      expect(
        pharmacySectionCountTone(PharmacyDeskSection.completed),
        AppTabCountTone.info,
      );
      expect(
        pharmacySectionCountTone(PharmacyDeskSection.allOrders),
        AppTabCountTone.info,
      );
      expect(
        pharmacySectionCountTone(PharmacyDeskSection.suppliers),
        AppTabCountTone.info,
      );
    });

    test('stock-alert and order section query helpers stay aligned', () {
      expect(
        PharmacyDeskSection.nearExpiry.stockQuery?.expiringWithinDays,
        30,
      );
      expect(PharmacyDeskSection.expired.stockQuery?.expiredOnly, isTrue);
      expect(
        PharmacyDeskSection.lowStock.stockQuery?.stockStatus,
        'LOW_STOCK',
      );
      expect(
        PharmacyDeskSection.outOfStock.stockQuery?.stockStatus,
        'OUT_OF_STOCK',
      );
      expect(pharmacySectionToQueryValue(PharmacyDeskSection.queue), 'queue');
      expect(
        pharmacySectionFromQuery('out-of-stock'),
        PharmacyDeskSection.outOfStock,
      );
    });
  });
}
