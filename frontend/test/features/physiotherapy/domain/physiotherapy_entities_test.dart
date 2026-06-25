import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/physiotherapy/domain/entities/physiotherapy_entities.dart';

void main() {
  group('PhysiotherapyWorklistQuery', () {
    test('fromUri pre-fills encounter search', () {
      final PhysiotherapyWorklistQuery query = PhysiotherapyWorklistQuery.fromUri(
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
