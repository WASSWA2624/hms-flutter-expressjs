import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/router/shell_route_access.dart';
import 'package:hosspi_hms/core/network/idempotency.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/workspace/realtime_delta.dart';
import 'package:hosspi_hms/core/workspace/realtime_sync_action.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_realtime_delta_applier.dart';
import 'package:hosspi_hms/features/reception/domain/entities/reception_entities.dart';
import 'package:hosspi_hms/features/reception/presentation/reception_access.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_flow_actions_dialog.dart';

const List<AppModuleEntitlement> _activeShellModules = <AppModuleEntitlement>[
  AppModuleEntitlement(code: 'patient-registry', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'scheduling-queue', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'insurance-claims', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(
    code: 'notifications-communications',
    licenseStatus: 'ACTIVE',
  ),
];

AppAccessPolicy _policyFor({required List<String> roles}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'token'),
      user: AuthUserProfile(
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
        roles: roles,
      ),
      moduleEntitlements: _activeShellModules,
    ),
  );
}

void main() {
  group('ReceptionWorkspaceQuery', () {
    test('parses desk section deep links', () {
      final ReceptionWorkspaceQuery query = ReceptionWorkspaceQuery.fromUri(
        Uri.parse('/reception?section=queue&search=Ada'),
      );

      expect(query.section, 'queue');
      expect(query.search, 'Ada');
      expect(query.hasRouteTargeting, isTrue);
    });
  });

  group('Reception authorization split', () {
    test('receptionist can open reception shell route', () {
      final AppAccessPolicy policy = _policyFor(roles: <String>['RECEPTIONIST']);

      expect(canAccessShellRoute(AppRoutes.reception, policy), isTrue);
      expect(canAccessShellRoute(AppRoutes.billing, policy), isFalse);
      expect(receptionWorkspaceRequirement.isAllowed(policy), isTrue);
    });

    test('billing pay-consultation is hidden without billing:write', () {
      final AppAccessPolicy receptionist = _policyFor(
        roles: <String>['RECEPTIONIST'],
      );
      final AppAccessPolicy cashier = _policyFor(roles: <String>['BILLING']);

      expect(opdBillingActionRequirement.isAllowed(receptionist), isFalse);
      expect(
        receptionBillingCashierRequirement.isAllowed(receptionist),
        isFalse,
      );
      expect(
        receptionBillingGuidanceRequirement.isAllowed(receptionist),
        isTrue,
      );

      expect(opdBillingActionRequirement.isAllowed(cashier), isTrue);
      expect(receptionBillingCashierRequirement.isAllowed(cashier), isTrue);
    });

    test('billing guidance remains available with patient:read', () {
      final AppAccessPolicy policy = _policyFor(roles: <String>['RECEPTIONIST']);

      expect(policy.grants(AppPermissions.patientRead), isTrue);
      expect(receptionBillingGuidanceRequirement.isAllowed(policy), isTrue);
      expect(policy.grants(AppPermissions.billingWrite), isFalse);
    });

    test('receptionist can capture insurance without billing:write', () {
      final AppAccessPolicy policy = _policyFor(roles: <String>['RECEPTIONIST']);

      expect(policy.grants(AppPermissions.patientWrite), isTrue);
      expect(receptionInsuranceCaptureRequirement.isAllowed(policy), isTrue);
      expect(receptionBillingCashierRequirement.isAllowed(policy), isFalse);
    });
  });

  group('OPD front-desk idempotency helpers', () {
    test('createIdempotencyKey returns opaque UUID-shaped values', () {
      final String first = createIdempotencyKey();
      final String second = createIdempotencyKey();

      expect(first, isNot(equals(second)));
      expect(first.split('-'), hasLength(5));
      expect(idempotentRequestOptions(idempotencyKey: first).headers, {
        idempotencyHeaderName: first,
      });
    });

    test('same logical retry reuses one idempotency key envelope', () {
      final String key = createIdempotencyKey();
      final first = idempotentRequestOptions(idempotencyKey: key);
      final second = idempotentRequestOptions(idempotencyKey: key);

      expect(first.headers?[idempotencyHeaderName], key);
      expect(second.headers?[idempotencyHeaderName], key);
    });
  });

  group('Reception multi-client queue reconciliation', () {
    test('applies visit_queue upsert from scoped realtime delta', () {
      final OpdWorkspaceState initial = OpdWorkspaceState.empty();
      final OpdWorkspaceState? next = OpdRealtimeDeltaApplier.apply(
        initial,
        const RealtimeDelta(
          action: RealtimeSyncAction.upsert,
          resourceType: 'visit_queue',
          entity: <String, Object?>{
            'id': 'queue-1',
            'display_id': 'VQ000001',
            'patient_id': 'PAT000001',
            'patient_display_name': 'Ada Lovelace',
            'status': 'WAITING',
            'queued_at': '2026-07-15T08:00:00.000Z',
          },
        ),
      );

      expect(next, isNotNull);
      expect(next!.queueEntries.items, hasLength(1));
      expect(next.queueEntries.items.first.patientDisplayName, 'Ada Lovelace');
    });

    test('removes visit_queue entry for peer clients', () {
      final OpdWorkspaceState seeded = OpdWorkspaceState.empty().copyWith(
        queueEntries: const AppPage<OpdQueueEntry>(
          items: <OpdQueueEntry>[
            OpdQueueEntry(
              id: 'queue-1',
              publicId: 'VQ000001',
              patientDisplayName: 'Ada Lovelace',
              status: 'WAITING',
            ),
          ],
          request: AppPageRequest(pageSize: 12),
        ),
      );

      final OpdWorkspaceState? next = OpdRealtimeDeltaApplier.apply(
        seeded,
        const RealtimeDelta(
          action: RealtimeSyncAction.remove,
          resourceType: 'visit_queue',
          resourceId: 'queue-1',
        ),
      );

      expect(next, isNotNull);
      expect(next!.queueEntries.items, isEmpty);
    });
  });
}
