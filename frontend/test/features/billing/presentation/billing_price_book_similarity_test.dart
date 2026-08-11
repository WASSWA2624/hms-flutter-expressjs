import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_price_book_entry.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_price_book_similarity.dart';

void main() {
  const BillingPriceBookEntry active = BillingPriceBookEntry(
    id: 'pb-1',
    catalogType: 'SERVICE',
    catalogItemId: 'CONSULT-OPD',
    paymentMode: 'SELF_PAY',
    unitPrice: 25000,
    currency: 'UGX',
    billingEntity: 'FACILITY',
    isActive: true,
    effectiveFrom: null,
  );

  test('exact active match blocks silent create', () {
    final BillingPriceBookSimilarityResult result =
        checkBillingPriceBookSimilarity(
          draft: const BillingPriceBookSimilarityDraft(
            catalogItemId: 'CONSULT-OPD',
            paymentMode: 'SELF_PAY',
          ),
          candidates: const <BillingPriceBookEntry>[active],
        );

    expect(result.hasMatches, isTrue);
    expect(result.hasExactConflict, isTrue);
    expect(result.matches.single.entry.id, 'pb-1');
  });

  test('edit excludes self from exact conflict', () {
    final BillingPriceBookSimilarityResult result =
        checkBillingPriceBookSimilarity(
          draft: const BillingPriceBookSimilarityDraft(
            catalogItemId: 'CONSULT-OPD',
            paymentMode: 'SELF_PAY',
          ),
          candidates: const <BillingPriceBookEntry>[active],
          excludeEntryId: 'pb-1',
        );

    expect(result.hasMatches, isFalse);
  });

  test('near item token match surfaces review', () {
    final BillingPriceBookSimilarityResult result =
        checkBillingPriceBookSimilarity(
          draft: const BillingPriceBookSimilarityDraft(
            catalogItemId: 'CONSULTATION-OPD',
            paymentMode: 'SELF_PAY',
          ),
          candidates: const <BillingPriceBookEntry>[active],
        );

    expect(result.hasMatches, isTrue);
    expect(result.hasExactConflict, isFalse);
    expect(result.closestScore, greaterThanOrEqualTo(70));
  });
}
