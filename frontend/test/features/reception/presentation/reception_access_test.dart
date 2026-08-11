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

    test('parses modal action deep links', () {
      final ReceptionWorkspaceQuery query = ReceptionWorkspaceQuery.fromUri(
        Uri.parse('/reception?section=appointments&action=register'),
      );

      expect(query.section, 'appointments');
      expect(query.action, 'register');
      expect(query.hasRouteTargeting, isTrue);
      expect(
        ReceptionWorkspaceQuery.fromUri(
          Uri.parse('/reception?action=schedule'),
        ).action,
        'schedule',
      );
      expect(
        ReceptionWorkspaceQuery.fromUri(
          Uri.parse('/reception?section=queue&dialog=route'),
        ).action,
        'route',
      );
    });

    test('parses canonical section query aliases', () {
      expect(
        ReceptionWorkspaceQuery.fromUri(
          Uri.parse('/reception?section=desk-queue'),
        ).section,
        'desk-queue',
      );
      expect(
        ReceptionWorkspaceQuery.fromUri(
          Uri.parse('/reception?section=active'),
        ).section,
        'active',
      );
      expect(
        ReceptionWorkspaceQuery.fromUri(
          Uri.parse('/reception?section=payment-gate'),
        ).section,
        'payment-gate',
      );
      expect(
        ReceptionWorkspaceQuery.fromUri(
          Uri.parse('/reception?section=appointments'),
        ).section,
        'appointments',
      );
      expect(
        ReceptionWorkspaceQuery.fromUri(
          Uri.parse('/reception?section=follow-ups'),
        ).section,
        'follow-ups',
      );
    });
  });

  group('ReceptionDeskSection query mapping', () {
    test('writes canonical section query values', () {
      expect(
        receptionDeskSectionToQueryValue(ReceptionDeskSection.appointments),
        'appointments',
      );
      expect(
        receptionDeskSectionToQueryValue(ReceptionDeskSection.queue),
        'desk-queue',
      );
      expect(
        receptionDeskSectionToQueryValue(ReceptionDeskSection.highPriority),
        'high-priority',
      );
      expect(
        receptionDeskSectionToQueryValue(ReceptionDeskSection.activeVisits),
        'active',
      );
      expect(
        receptionDeskSectionToQueryValue(ReceptionDeskSection.followUps),
        'follow-ups',
      );
      expect(
        receptionDeskSectionToQueryValue(ReceptionDeskSection.paymentGate),
        'payment-gate',
      );
    });

    test('resolves canonical and alias section query values', () {
      expect(
        receptionDeskSectionFromQuery('appointments'),
        ReceptionDeskSection.appointments,
      );
      expect(
        receptionDeskSectionFromQuery('meetings'),
        ReceptionDeskSection.appointments,
      );
      expect(
        receptionDeskSectionFromQuery('desk-queue'),
        ReceptionDeskSection.queue,
      );
      expect(
        receptionDeskSectionFromQuery('desk_queue'),
        ReceptionDeskSection.queue,
      );
      expect(
        receptionDeskSectionFromQuery('queue'),
        ReceptionDeskSection.queue,
      );
      expect(
        receptionDeskSectionFromQuery('high-priority'),
        ReceptionDeskSection.highPriority,
      );
      expect(
        receptionDeskSectionFromQuery('high_priority'),
        ReceptionDeskSection.highPriority,
      );
      expect(
        receptionDeskSectionFromQuery('priority'),
        ReceptionDeskSection.highPriority,
      );
      expect(
        receptionDeskSectionFromQuery('active'),
        ReceptionDeskSection.activeVisits,
      );
      expect(
        receptionDeskSectionFromQuery('active-visits'),
        ReceptionDeskSection.activeVisits,
      );
      expect(
        receptionDeskSectionFromQuery('active_visits'),
        ReceptionDeskSection.activeVisits,
      );
      expect(
        receptionDeskSectionFromQuery('in-progress'),
        ReceptionDeskSection.activeVisits,
      );
      expect(
        receptionDeskSectionFromQuery('payment-gate'),
        ReceptionDeskSection.paymentGate,
      );
      expect(
        receptionDeskSectionFromQuery('follow-ups'),
        ReceptionDeskSection.followUps,
      );
      expect(
        receptionDeskSectionFromQuery('follow_ups'),
        ReceptionDeskSection.followUps,
      );
      expect(
        receptionDeskSectionFromQuery('followups'),
        ReceptionDeskSection.followUps,
      );
      expect(
        receptionDeskSectionFromQuery('follow-up'),
        ReceptionDeskSection.followUps,
      );
      expect(
        receptionDeskSectionFromQuery('no_show_pressure'),
        ReceptionDeskSection.followUps,
      );
      expect(
        receptionDeskSectionFromQuery('turnaround_pressure'),
        ReceptionDeskSection.activeVisits,
      );
      expect(
        receptionDeskSectionFromQuery('pending_balance_amount'),
        ReceptionDeskSection.paymentGate,
      );
      expect(receptionDeskSectionFromQuery('unknown'), isNull);
    });
  });

  group('Reception authorization split', () {
    test('receptionist can open reception shell route', () {
      final AppAccessPolicy policy = _policyFor(
        roles: <String>['RECEPTIONIST'],
      );

      expect(canAccessShellRoute(AppRoutes.reception, policy), isTrue);
      expect(canAccessShellRoute(AppRoutes.billing, policy), isFalse);
      expect(receptionWorkspaceRequirement.isAllowed(policy), isTrue);
    });

    test('active visits require backend-readable OPD permissions', () {
      final AppAccessPolicy lastOfficeOnly = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'token'),
          user: const AuthUserProfile(roles: <String>['RECEPTIONIST']),
          permissions: <AppPermission>{AppPermissions.lastOfficeRead},
          moduleEntitlements: _activeShellModules,
        ),
      );
      final AppAccessPolicy patientReader = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'token'),
          user: const AuthUserProfile(roles: <String>['RECEPTIONIST']),
          permissions: <AppPermission>{AppPermissions.patientRead},
          moduleEntitlements: _activeShellModules,
        ),
      );
      final AppAccessPolicy clinicalWriter = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'token'),
          user: const AuthUserProfile(roles: <String>['DOCTOR']),
          permissions: <AppPermission>{AppPermissions.clinicalWrite},
          moduleEntitlements: <AppModuleEntitlement>[
            ..._activeShellModules,
            const AppModuleEntitlement(
              code: 'encounters-vitals',
              licenseStatus: 'ACTIVE',
            ),
          ],
          isAuthorizationHydrated: true,
        ),
      );

      expect(
        receptionActiveVisitsRequirement.isAllowed(lastOfficeOnly),
        isFalse,
      );
      expect(receptionActiveVisitsRequirement.isAllowed(patientReader), isTrue);
      expect(canViewReceptionActiveVisits(patientReader), isTrue);
      expect(
        identical(
          receptionDeskSectionRequirement(ReceptionDeskSection.activeVisits),
          ReceptionActiveVisitsAtomPermissions.tab,
        ),
        isTrue,
      );
      // Nested matrix ∪ clinical:write | patient:write.
      expect(
        ReceptionActiveVisitsAtomPermissions.nestedWrite.isAllowed(
          clinicalWriter,
        ),
        isTrue,
      );
      expect(
        ReceptionActiveVisitsAtomPermissions.nestedWrite.isAllowed(
          patientReader,
        ),
        isFalse,
      );
    });

    test('consultation billing actions stay unavailable to receptionists', () {
      final AppAccessPolicy receptionist = _policyFor(
        roles: <String>['RECEPTIONIST'],
      );
      final AppAccessPolicy cashier = _policyFor(roles: <String>['BILLING']);

      expect(opdBillingActionRequirement.isAllowed(receptionist), isFalse);
      // Shared OPD billing actions remain available outside Reception.
      expect(opdBillingActionRequirement.isAllowed(cashier), isTrue);
    });

    test('payment gate requires billing read; collect never mounts on desk', () {
      final AppAccessPolicy patientReader = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'token'),
          user: const AuthUserProfile(roles: <String>['RECEPTIONIST']),
          permissions: <AppPermission>{AppPermissions.patientRead},
          moduleEntitlements: _activeShellModules,
        ),
      );
      final AppAccessPolicy billingReader = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'token'),
          user: const AuthUserProfile(roles: <String>['RECEPTIONIST']),
          permissions: <AppPermission>{AppPermissions.billingRead},
          moduleEntitlements: _activeShellModules,
        ),
      );
      final AppAccessPolicy billingWriter = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'token'),
          user: const AuthUserProfile(roles: <String>['BILLING']),
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
          },
          moduleEntitlements: _activeShellModules,
        ),
      );

      expect(receptionPaymentGateRequirement.isAllowed(patientReader), isFalse);
      expect(receptionPaymentGateRequirement.isAllowed(billingReader), isTrue);
      expect(canViewReceptionPaymentGate(billingReader), isTrue);
      expect(
        ReceptionPaymentGateAtomPermissions.collect.isAllowed(billingReader),
        isFalse,
      );
      expect(
        ReceptionPaymentGateAtomPermissions.collect.isAllowed(billingWriter),
        isTrue,
      );
      expect(
        identical(
          receptionDeskSectionRequirement(ReceptionDeskSection.paymentGate),
          ReceptionPaymentGateAtomPermissions.tab,
        ),
        isTrue,
      );
    });

    test('appointments tab uses ∩ patient:read; schedule uses ∩ patient:write', () {
      final AppAccessPolicy patientReader = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'token'),
          user: const AuthUserProfile(roles: <String>['CUSTOM_READER']),
          permissions: <AppPermission>{AppPermissions.patientRead},
          moduleEntitlements: _activeShellModules,
          isAuthorizationHydrated: true,
        ),
      );
      final AppAccessPolicy patientWriter = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'token'),
          user: const AuthUserProfile(roles: <String>['CUSTOM_WRITER']),
          permissions: <AppPermission>{
            AppPermissions.patientRead,
            AppPermissions.patientWrite,
          },
          moduleEntitlements: _activeShellModules,
          isAuthorizationHydrated: true,
        ),
      );

      expect(
        receptionSchedulingReadRequirement.allPermissions,
        <AppPermission>[AppPermissions.patientRead],
      );
      expect(canViewReceptionAppointments(patientReader), isTrue);
      expect(
        ReceptionAppointmentsAtomPermissions.schedule.isAllowed(patientReader),
        isFalse,
      );
      expect(
        ReceptionAppointmentsAtomPermissions.schedule.isAllowed(patientWriter),
        isTrue,
      );
      expect(
        ReceptionAppointmentsAtomPermissions.delete.allPermissions,
        <AppPermission>[AppPermissions.patientDelete],
      );
      expect(
        ReceptionAppointmentsAtomPermissions.cancelAppointment,
        same(receptionFrontDeskWriteRequirement),
      );
    });

    test('follow-ups require patient or clinical read (source ∪)', () {
      final AppAccessPolicy lastOfficeOnly = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'token'),
          user: const AuthUserProfile(roles: <String>['RECEPTIONIST']),
          permissions: <AppPermission>{AppPermissions.lastOfficeRead},
          moduleEntitlements: _activeShellModules,
          isAuthorizationHydrated: true,
        ),
      );
      final AppAccessPolicy patientReader = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'token'),
          user: const AuthUserProfile(roles: <String>['RECEPTIONIST']),
          permissions: <AppPermission>{AppPermissions.patientRead},
          moduleEntitlements: _activeShellModules,
          isAuthorizationHydrated: true,
        ),
      );
      final AppAccessPolicy clinicalReader = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'token'),
          user: const AuthUserProfile(roles: <String>['RECEPTIONIST']),
          permissions: <AppPermission>{AppPermissions.clinicalRead},
          moduleEntitlements: <AppModuleEntitlement>[
            ..._activeShellModules,
            AppModuleEntitlement(
              code: 'encounters-vitals',
              licenseStatus: 'ACTIVE',
            ),
          ],
          isAuthorizationHydrated: true,
        ),
      );

      // Matrix ∪ last_office:read maps to source ∪ patient|clinical (backend).
      expect(receptionFollowUpsRequirement.isAllowed(lastOfficeOnly), isFalse);
      expect(canViewReceptionFollowUps(lastOfficeOnly), isFalse);
      expect(receptionFollowUpsRequirement.isAllowed(patientReader), isTrue);
      expect(receptionFollowUpsRequirement.isAllowed(clinicalReader), isTrue);
      expect(canViewReceptionFollowUps(patientReader), isTrue);
      expect(
        receptionDeskSectionRequirement(
          ReceptionDeskSection.followUps,
        ),
        same(ReceptionFollowUpsAtomPermissions.tab),
      );
      expect(
        ReceptionFollowUpsAtomPermissions.write,
        same(receptionPatientWriteRequirement),
      );
      expect(
        canWriteReceptionFollowUps(patientReader),
        isFalse,
      );
    });

    test('receptionist can capture insurance without billing:write', () {
      final AppAccessPolicy policy = _policyFor(
        roles: <String>['RECEPTIONIST'],
      );

      expect(policy.grants(AppPermissions.patientWrite), isTrue);
      expect(receptionInsuranceCaptureRequirement.isAllowed(policy), isTrue);
      expect(policy.grants(AppPermissions.billingWrite), isFalse);
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

  group('Reception desk export / print gate', () {
    test('allows export when evidence:export is granted', () {
      expect(
        canExportReceptionDesk(
          _policyFor(roles: <String>['RECEPTIONIST']),
        ),
        isTrue,
      );
      expect(
        canPrintReceptionDesk(
          _policyFor(roles: <String>['RECEPTIONIST']),
        ),
        isTrue,
      );
    });

    test('denies export without evidence:export', () {
      final AppAccessPolicy policy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'token'),
          user: const AuthUserProfile(
            tenantId: 'tenant-1',
            facilityId: 'facility-1',
            roles: <String>['CUSTOM'],
          ),
          permissions: <AppPermission>{
            AppPermissions.patientRead,
            AppPermissions.patientWrite,
            AppPermissions.reportsRead,
          },
          moduleEntitlements: _activeShellModules,
        ),
      );
      expect(canExportReceptionDesk(policy), isFalse);
      expect(canPrintReceptionDesk(policy), isFalse);
    });
  });
}
