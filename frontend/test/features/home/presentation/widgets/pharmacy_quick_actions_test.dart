import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_profiles.dart';
import 'package:hosspi_hms/features/home/presentation/widgets/home_dashboard_actions.dart';

void main() {
  AuthSession sessionWith({
    required Set<AppPermission> permissions,
    List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
      AppModuleEntitlement(
        code: 'pharmacy-dispensing',
        licenseStatus: 'ACTIVE',
      ),
    ],
  }) {
    return AuthSession(
      tokens: SessionTokens(accessToken: 'token'),
      user: const AuthUserProfile(
        roles: <String>['PHARMACIST'],
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: permissions,
      moduleEntitlements: modules,
      isAuthorizationHydrated: true,
      isModuleCatalogHydrated: true,
    );
  }

  test('pharmacist quick actions: New orders, Create order, Pharmacy stock', () {
    final AppAccessPolicy policy = AppAccessPolicy.fromSession(
      sessionWith(
        permissions: <AppPermission>{
          AppPermissions.pharmacyRead,
          AppPermissions.pharmacyWrite,
        },
      ),
    );

    final HomeActionDefinition newOrders =
        homeActionLibrary['dispense_medication']!;
    final HomeActionDefinition createOrder =
        homeActionLibrary['record_pharmacy_sale']!;
    final HomeActionDefinition stock =
        homeActionLibrary['receive_pharmacy_stock']!;

    expect(newOrders.label, 'New orders');
    expect(newOrders.route, AppRoutes.pharmacy);
    expect(newOrders.routeQuery, <String, String>{'section': 'orders'});
    expect(newOrders.isAllowed(policy), isTrue);

    expect(createOrder.label, 'Create order');
    expect(createOrder.isAllowed(policy), isTrue);

    expect(stock.label, 'Pharmacy stock');
    expect(stock.routeQuery, <String, String>{'section': 'inventory'});
    expect(stock.isAllowed(policy), isTrue);
  });

  test('pharmacy write/module gates hide pharmacist quick actions', () {
    final AppAccessPolicy noWrite = AppAccessPolicy.fromSession(
      sessionWith(permissions: <AppPermission>{AppPermissions.pharmacyRead}),
    );
    final AppAccessPolicy noModule = AppAccessPolicy.fromSession(
      sessionWith(
        permissions: <AppPermission>{
          AppPermissions.pharmacyRead,
          AppPermissions.pharmacyWrite,
        },
        modules: const <AppModuleEntitlement>[],
      ),
    );

    expect(
      homeActionLibrary['dispense_medication']!.isAllowed(noWrite),
      isFalse,
    );
    expect(
      homeActionLibrary['record_pharmacy_sale']!.isAllowed(noWrite),
      isFalse,
    );
    expect(
      homeActionLibrary['receive_pharmacy_stock']!.isAllowed(noWrite),
      isFalse,
    );

    expect(
      homeActionLibrary['dispense_medication']!.isAllowed(noModule),
      isFalse,
    );
    expect(
      homeActionLibrary['record_pharmacy_sale']!.isAllowed(noModule),
      isFalse,
    );
  });

  test('pharmacist profile exposes three unique stock/order quick actions', () {
    final HomeDashboardProfile profile = homeProfileForRole(AppRole.pharmacist);
    expect(profile.quickActionIds, <String>[
      'dispense_medication',
      'record_pharmacy_sale',
      'receive_pharmacy_stock',
    ]);
    expect(profile.quickActionIds.toSet().length, 3);
    expect(profile.quickActionIds, isNot(contains('adjust_pharmacy_stock')));
  });
}
