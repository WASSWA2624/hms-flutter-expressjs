import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_adjustment_similarity.dart';

void main() {
  const BillingWorkItem invoice = BillingWorkItem(
    id: 'inv-1',
    displayId: 'INV-1',
    kind: BillingWorkItemKind.invoice,
    billingStatus: 'DRAFT',
    amount: 200,
    adjustments: <BillingAdjustment>[
      BillingAdjustment(
        id: 'adj-1',
        displayId: 'ADJ-1',
        status: 'PENDING',
        amount: 25,
        reason: 'Discount',
      ),
    ],
  );

  test('exact pending adjust match blocks silent duplicate', () {
    const BillingAdjustmentDraft draft = BillingAdjustmentDraft(
      amount: '25',
      reason: 'Discount',
      status: 'PENDING',
    );

    final BillingAdjustmentSimilarityResult result =
        checkBillingAdjustmentSimilarity(invoice: invoice, draft: draft);

    expect(result.hasMatches, isTrue);
    expect(result.hasExactConflict, isTrue);
    expect(result.matches.single.adjustment.id, 'adj-1');
  });

  test('near amount window match is surfaced', () {
    const BillingAdjustmentDraft draft = BillingAdjustmentDraft(
      amount: '27',
      reason: 'Discount applied',
      status: 'PENDING',
    );

    final BillingAdjustmentSimilarityResult result =
        checkBillingAdjustmentSimilarity(invoice: invoice, draft: draft);

    expect(result.hasMatches, isTrue);
    expect(result.hasExactConflict, isFalse);
    expect(result.closestScore >= 70, isTrue);
  });

  test('completed adjustments are ignored', () {
    const BillingWorkItem settled = BillingWorkItem(
      id: 'inv-2',
      displayId: 'INV-2',
      kind: BillingWorkItemKind.invoice,
      billingStatus: 'DRAFT',
      adjustments: <BillingAdjustment>[
        BillingAdjustment(
          id: 'adj-2',
          displayId: 'ADJ-2',
          status: 'APPROVED',
          amount: 25,
          reason: 'Discount',
        ),
      ],
    );

    final BillingAdjustmentSimilarityResult result =
        checkBillingAdjustmentSimilarity(
          invoice: settled,
          draft: const BillingAdjustmentDraft(
            amount: '25',
            reason: 'Discount',
            status: 'PENDING',
          ),
        );

    expect(result.hasMatches, isFalse);
  });
}
