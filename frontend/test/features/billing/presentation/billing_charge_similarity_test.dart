import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_charge_similarity.dart';

void main() {
  const BillingChargeDraft draft = BillingChargeDraft(
    patientId: 'patient-1',
    itemDescription: 'Consultation',
    quantity: 1,
    unitPrice: '100.00',
    paymentMode: 'SELF_PAY',
    patientDisplayName: 'Ada Lovelace',
    patientDisplayId: 'PT-001',
  );

  test('exact open draft match blocks silent duplicate', () {
    const BillingWorkItem existing = BillingWorkItem(
      id: 'inv-1',
      displayId: 'INV-1',
      kind: BillingWorkItemKind.invoice,
      patientId: 'patient-1',
      patientDisplayName: 'Ada Lovelace',
      patientDisplayId: 'PT-001',
      billingStatus: 'DRAFT',
      amount: 100,
      financials: BillingFinancials(effectiveTotal: 100, balanceDue: 100),
      items: <BillingInvoiceItem>[
        BillingInvoiceItem(
          id: 'line-1',
          description: 'Consultation',
          quantity: 1,
          unitPrice: 100,
          totalPrice: 100,
        ),
      ],
    );

    final BillingChargeSimilarityResult result = checkBillingChargeSimilarity(
      draft: draft,
      candidates: <BillingWorkItem>[existing],
    );

    expect(result.hasMatches, isTrue);
    expect(result.hasExactConflict, isTrue);
    expect(result.matches.single.item.id, 'inv-1');
  });

  test('near match on similar item and amount window is surfaced', () {
    const BillingWorkItem existing = BillingWorkItem(
      id: 'inv-2',
      displayId: 'INV-2',
      kind: BillingWorkItemKind.invoice,
      patientId: 'patient-1',
      patientDisplayName: 'Ada Lovelace',
      billingStatus: 'DRAFT',
      amount: 95,
      financials: BillingFinancials(effectiveTotal: 95, balanceDue: 95),
      items: <BillingInvoiceItem>[
        BillingInvoiceItem(
          id: 'line-2',
          description: 'Consult visit',
          quantity: 1,
          unitPrice: 95,
          totalPrice: 95,
        ),
      ],
    );

    final BillingChargeSimilarityResult result = checkBillingChargeSimilarity(
      draft: draft,
      candidates: <BillingWorkItem>[existing],
    );

    expect(result.hasMatches, isTrue);
    expect(result.hasExactConflict, isFalse);
    expect(result.closestScore >= 70, isTrue);
  });

  test('different patient is ignored', () {
    const BillingWorkItem existing = BillingWorkItem(
      id: 'inv-3',
      displayId: 'INV-3',
      kind: BillingWorkItemKind.invoice,
      patientId: 'patient-other',
      billingStatus: 'DRAFT',
      amount: 100,
      financials: BillingFinancials(effectiveTotal: 100, balanceDue: 100),
      items: <BillingInvoiceItem>[
        BillingInvoiceItem(
          id: 'line-3',
          description: 'Consultation',
          quantity: 1,
          unitPrice: 100,
          totalPrice: 100,
        ),
      ],
    );

    final BillingChargeSimilarityResult result = checkBillingChargeSimilarity(
      draft: draft,
      candidates: <BillingWorkItem>[existing],
    );

    expect(result.hasMatches, isFalse);
  });
}
