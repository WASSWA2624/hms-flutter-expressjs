import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/emergency/data/dtos/emergency_dtos.dart';
import 'package:hosspi_hms/features/emergency/domain/entities/emergency_entities.dart';

void main() {
  group('EmergencyWorkspaceQuery.fromUri', () {
    test('parses id and panel deep-link parameters', () {
      final EmergencyWorkspaceQuery query = EmergencyWorkspaceQuery.fromUri(
        Uri.parse('/emergency?id=EME000001&panel=handoff'),
      );

      expect(query.caseId, 'EME000001');
      expect(query.panel, EmergencyDetailPanelFocus.handoff);
      expect(query.search, isEmpty);
      expect(query.hasRouteTargeting, isTrue);
    });

    test('maps dispatch and trip aliases to the ambulance panel', () {
      expect(
        EmergencyWorkspaceQuery.fromUri(
          Uri.parse('/emergency?panel=dispatch'),
        ).panel,
        EmergencyDetailPanelFocus.ambulance,
      );
      expect(
        EmergencyWorkspaceQuery.fromUri(
          Uri.parse('/emergency?focus=trip'),
        ).panel,
        EmergencyDetailPanelFocus.ambulance,
      );
    });

    test('accepts alternate aliases for case id and search', () {
      final EmergencyWorkspaceQuery query = EmergencyWorkspaceQuery.fromUri(
        Uri.parse('/emergency?case=EME000002&q=Jane'),
      );

      expect(query.caseId, 'EME000002');
      expect(query.search, 'Jane');
      expect(query.panel, EmergencyDetailPanelFocus.none);
    });

    test('treats blank values as absent and reports no targeting', () {
      final EmergencyWorkspaceQuery query = EmergencyWorkspaceQuery.fromUri(
        Uri.parse('/emergency?id=%20%20&panel=%20%20'),
      );

      expect(query.caseId, isEmpty);
      expect(query.panel, EmergencyDetailPanelFocus.none);
      expect(query.hasRouteTargeting, isFalse);
    });

    test('parses scope from the query string', () {
      final EmergencyWorkspaceQuery query = EmergencyWorkspaceQuery.fromUri(
        Uri.parse('/emergency?scope=critical'),
      );

      expect(query.scope, 'critical');
      expect(query.hasRouteTargeting, isTrue);
    });

    test('accepts board and tab aliases for scope', () {
      expect(
        EmergencyWorkspaceQuery.fromUri(
          Uri.parse('/emergency?board=ambulance'),
        ).scope,
        'ambulance',
      );
      expect(
        EmergencyWorkspaceQuery.fromUri(
          Uri.parse('/emergency?tab=handoff'),
        ).scope,
        'handoff',
      );
    });

    test('includes scope in the route signature', () {
      final EmergencyWorkspaceQuery withScope = EmergencyWorkspaceQuery.fromUri(
        Uri.parse('/emergency?scope=closed&search=Jane'),
      );
      final EmergencyWorkspaceQuery withoutScope =
          EmergencyWorkspaceQuery.fromUri(Uri.parse('/emergency?search=Jane'));

      expect(withScope.signature, contains('closed'));
      expect(withScope.signature, isNot(withoutScope.signature));
    });
  });

  group('EmergencyHandoffOutcome', () {
    test('builds a deep link for a receiving workflow', () {
      const EmergencyHandoffOutcome outcome = EmergencyHandoffOutcome(
        destination: 'IPD',
        route: 'ipd',
        receivingDisplayId: 'ADM000001',
      );

      expect(outcome.hasReceivingWork, isTrue);
      expect(outcome.receivingDeepLink, '/ipd?id=ADM000001');
    });

    test('terminal handoffs expose no receiving work or deep link', () {
      const EmergencyHandoffOutcome outcome = EmergencyHandoffOutcome(
        destination: 'REFERRAL',
        terminal: true,
      );

      expect(outcome.hasReceivingWork, isFalse);
      expect(outcome.receivingDeepLink, isNull);
    });
  });

  group('EmergencyCaseDto handoff mapping', () {
    test('parses a top-level handoff snapshot with billing deferred', () {
      final EmergencyCaseSummary summary = const EmergencyCaseDto(
        <String, Object?>{
          'id': '11111111-1111-1111-1111-111111111111',
          'display_id': 'EME000001',
          'severity': 'CRITICAL',
          'status': 'CLOSED',
          'handoff': <String, Object?>{
            'destination': 'IPD',
            'route': 'ipd',
            'receiving_display_id': 'ADM000001',
            'admission_display_id': 'ADM000001',
            'stage': 'WARD',
            'billing_deferred': true,
            'terminal': false,
            'handoff_at': '2026-06-25T08:00:00Z',
            'notes': 'Admitted to medical ward.',
          },
        },
      ).toEntity();

      final EmergencyHandoffOutcome? handoff = summary.handoff;
      expect(handoff, isNotNull);
      expect(handoff!.destination, 'IPD');
      expect(handoff.route, 'ipd');
      expect(handoff.receivingDisplayId, 'ADM000001');
      expect(handoff.billingDeferred, isTrue);
      expect(handoff.terminal, isFalse);
      expect(handoff.hasReceivingWork, isTrue);
      expect(handoff.receivingDeepLink, '/ipd?id=ADM000001');
      expect(handoff.handoffAt, isNotNull);
    });

    test('falls back to extension_json.handoff when not at top level', () {
      final EmergencyCaseSummary summary = const EmergencyCaseDto(
        <String, Object?>{
          'id': '22222222-2222-2222-2222-222222222222',
          'display_id': 'EME000002',
          'status': 'CLOSED',
          'extension_json': <String, Object?>{
            'handoff': <String, Object?>{
              'destination': 'OPD',
              'route': 'opd',
              'receiving_display_id': 'ENC000001',
              'stage': 'WAITING_VITALS',
              'billing_deferred': false,
            },
          },
        },
      ).toEntity();

      expect(summary.handoff, isNotNull);
      expect(summary.handoff!.destination, 'OPD');
      expect(summary.handoff!.receivingDeepLink, '/opd?id=ENC000001');
      expect(summary.handoff!.billingDeferred, isFalse);
    });

    test('returns no handoff when the case was never handed off', () {
      final EmergencyCaseSummary summary =
          const EmergencyCaseDto(<String, Object?>{
            'id': '33333333-3333-3333-3333-333333333333',
            'display_id': 'EME000003',
            'status': 'OPEN',
          }).toEntity();

      expect(summary.handoff, isNull);
    });
  });
}
