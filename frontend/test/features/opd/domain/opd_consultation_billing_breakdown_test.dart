import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_consultation_billing_breakdown.dart';

void main() {
  group('opdConsultationBillingBreakdown', () {
    test('returns a zero remaining balance when fully paid', () {
      const OpdFlowSummary flow = OpdFlowSummary(
        id: 'flow-1',
        consultationFee: 35000,
        consultationPaidAmount: 35000,
        consultationCurrency: 'UGX',
        consultationPaid: true,
      );

      final OpdConsultationBillingBreakdown breakdown =
          opdConsultationBillingBreakdown(flow);

      expect(breakdown.requiredAmount, 35000);
      expect(breakdown.paidAmount, 35000);
      // Fully paid must resolve to a concrete 0 balance, never null/"Not
      // available".
      expect(breakdown.remainingBalance, 0);
      expect(breakdown.currency, 'UGX');
    });

    test('computes the outstanding balance for a partial payment', () {
      const OpdFlowSummary flow = OpdFlowSummary(
        id: 'flow-2',
        consultationFee: 50000,
        consultationPaidAmount: 20000,
        consultationCurrency: 'UGX',
      );

      final OpdConsultationBillingBreakdown breakdown =
          opdConsultationBillingBreakdown(flow);

      expect(breakdown.remainingBalance, 30000);
      expect(breakdown.paidAmount, 20000);
    });

    test('leaves remaining balance unknown when no fee is configured', () {
      const OpdFlowSummary flow = OpdFlowSummary(id: 'flow-3');

      final OpdConsultationBillingBreakdown breakdown =
          opdConsultationBillingBreakdown(flow);

      expect(breakdown.requiredAmount, isNull);
      expect(breakdown.remainingBalance, isNull);
      expect(breakdown.paidAmount, isNull);
    });

    test('never reports a negative balance when overpaid', () {
      const OpdFlowSummary flow = OpdFlowSummary(
        id: 'flow-4',
        consultationFee: 10000,
        consultationPaidAmount: 15000,
        consultationCurrency: 'UGX',
        consultationPaid: true,
      );

      final OpdConsultationBillingBreakdown breakdown =
          opdConsultationBillingBreakdown(flow);

      expect(breakdown.remainingBalance, 0);
    });
  });
}
