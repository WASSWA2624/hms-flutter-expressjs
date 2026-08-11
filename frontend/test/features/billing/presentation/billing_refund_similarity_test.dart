import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_refund_similarity.dart';

void main() {
  const BillingWorkItem invoice = BillingWorkItem(
    id: 'inv-1',
    displayId: 'INV-1',
    kind: BillingWorkItemKind.invoice,
    billingStatus: 'ISSUED',
    amount: 200,
    financials: BillingFinancials(balanceDue: 100, netPaidTotal: 100),
    payments: <BillingPayment>[
      BillingPayment(
        id: 'pay-1',
        displayId: 'PAY-1',
        status: 'REFUNDED',
        method: 'CASH',
        amount: 50,
      ),
    ],
  );

  test('exact refunded payment match blocks silent duplicate', () {
    const BillingRefundDraft draft = BillingRefundDraft(
      paymentId: 'pay-1',
      amount: '50',
      reason: 'Duplicate charge',
    );

    final BillingRefundSimilarityResult result = checkBillingRefundSimilarity(
      invoice: invoice,
      draft: draft,
    );

    expect(result.hasMatches, isTrue);
    expect(result.hasExactConflict, isTrue);
    expect(result.matches.single.payment.id, 'pay-1');
  });

  test('no prior refund activity allows proceed without matches', () {
    const BillingWorkItem clean = BillingWorkItem(
      id: 'inv-2',
      displayId: 'INV-2',
      kind: BillingWorkItemKind.invoice,
      billingStatus: 'ISSUED',
      payments: <BillingPayment>[
        BillingPayment(
          id: 'pay-2',
          displayId: 'PAY-2',
          status: 'COMPLETED',
          method: 'CASH',
          amount: 80,
        ),
      ],
    );

    final BillingRefundSimilarityResult result = checkBillingRefundSimilarity(
      invoice: clean,
      draft: const BillingRefundDraft(
        paymentId: 'pay-2',
        amount: '80',
        reason: 'Customer request',
      ),
    );

    expect(result.hasMatches, isFalse);
  });
}
