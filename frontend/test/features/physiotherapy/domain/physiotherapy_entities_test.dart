import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/physiotherapy/domain/entities/physiotherapy_entities.dart';

void main() {
  group('PhysiotherapyWorkspaceQuery', () {
    test('fromUri parses section for tab deep linking', () {
      final PhysiotherapyWorkspaceQuery query =
          PhysiotherapyWorkspaceQuery.fromUri(
            Uri.parse('/physiotherapy?section=today&search=Ada'),
          );

      expect(query.section, 'today');
      expect(query.search, 'Ada');
      expect(query.hasRouteTargeting, isTrue);
      expect(query.signature, contains('today'));
    });

    test('fromUri parses active-plans and follow-up section values', () {
      expect(
        PhysiotherapyWorkspaceQuery.fromUri(
          Uri.parse('/physiotherapy?section=active-plans'),
        ).section,
        'active-plans',
      );
      expect(
        PhysiotherapyWorkspaceQuery.fromUri(
          Uri.parse('/physiotherapy?section=follow-up'),
        ).section,
        'follow-up',
      );
    });

    test('fromUri defaults section to empty when omitted', () {
      final PhysiotherapyWorkspaceQuery query =
          PhysiotherapyWorkspaceQuery.fromUri(Uri.parse('/physiotherapy'));

      expect(query.section, isEmpty);
      expect(query.hasRouteTargeting, isFalse);
    });

    test('fromUri pre-fills encounter and session targeting', () {
      final PhysiotherapyWorkspaceQuery encounterQuery =
          PhysiotherapyWorkspaceQuery.fromUri(
            Uri.parse('/physiotherapy?encounterId=ENC-001'),
          );
      expect(encounterQuery.encounterId, 'ENC-001');
      expect(encounterQuery.hasRouteTargeting, isTrue);

      final PhysiotherapyWorkspaceQuery sessionQuery =
          PhysiotherapyWorkspaceQuery.fromUri(
            Uri.parse('/physiotherapy?sessionId=SES-009'),
          );
      expect(sessionQuery.sessionId, 'SES-009');
    });
  });

  group('PhysiotherapyWorklistQuery', () {
    test('fromUri pre-fills encounter search', () {
      final PhysiotherapyWorklistQuery query =
          PhysiotherapyWorklistQuery.fromUri(
            Uri.parse('/physiotherapy?encounterId=ENC-001'),
          );

      expect(query.search, 'ENC-001');
      expect(query.scope, PhysiotherapyQueueScope.all);
    });
  });

  group('serverQueueScopeForPhysiotherapy', () {
    test('maps frontend scopes to backend queue scopes', () {
      expect(
        serverQueueScopeForPhysiotherapy(PhysiotherapyQueueScope.referrals),
        'REFERRAL',
      );
      expect(
        serverQueueScopeForPhysiotherapy(PhysiotherapyQueueScope.today),
        'TODAY',
      );
      expect(
        serverQueueScopeForPhysiotherapy(PhysiotherapyQueueScope.activePlans),
        'ACTIVE_PLAN',
      );
      expect(
        serverQueueScopeForPhysiotherapy(PhysiotherapyQueueScope.followUpDue),
        'FOLLOW_UP_DUE',
      );
      expect(
        serverQueueScopeForPhysiotherapy(PhysiotherapyQueueScope.missed),
        'MISSED',
      );
      expect(
        serverQueueScopeForPhysiotherapy(PhysiotherapyQueueScope.completed),
        'COMPLETED',
      );
    });
  });

  group('physiotherapyItemMatchesScope', () {
    const TherapyWorkItem referralItem = TherapyWorkItem(
      id: 'TH-001',
      encounterId: 'ENC-001',
    );

    const TherapyWorkItem activePlanItem = TherapyWorkItem(
      id: 'TH-002',
      encounterId: 'ENC-002',
      status: 'ACTIVE_PLAN',
    );

    test('referrals scope includes early journey statuses', () {
      expect(
        physiotherapyItemMatchesScope(
          referralItem,
          PhysiotherapyQueueScope.referrals,
        ),
        isTrue,
      );
      expect(
        physiotherapyItemMatchesScope(
          activePlanItem,
          PhysiotherapyQueueScope.referrals,
        ),
        isFalse,
      );
    });

    test('active plans scope matches active plan status', () {
      expect(
        physiotherapyItemMatchesScope(
          activePlanItem,
          PhysiotherapyQueueScope.activePlans,
        ),
        isTrue,
      );
    });
  });
}
