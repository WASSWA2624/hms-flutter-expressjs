import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pharmacy_cancel_reasons.dart';
import 'package:hosspi_hms/l10n/app_localizations_en.dart';

void main() {
  final AppLocalizationsEn l10n = AppLocalizationsEn();

  test('composePharmacyCancelReason joins selected labels and custom text', () {
    final String reason = composePharmacyCancelReason(
      l10n: l10n,
      selected: <PharmacyCancelReason>{
        PharmacyCancelReason.duplicateOrder,
        PharmacyCancelReason.outOfStock,
      },
      customReason: '  Ward request  ',
    );

    expect(
      reason,
      '${l10n.pharmacyCancelReasonDuplicateOrder}; '
      '${l10n.pharmacyCancelReasonOutOfStock}; '
      'Ward request',
    );
  });

  test('composePharmacyCancelReason allows custom-only reason', () {
    expect(
      composePharmacyCancelReason(
        l10n: l10n,
        selected: <PharmacyCancelReason>{},
        customReason: 'Clinical hold',
      ),
      'Clinical hold',
    );
  });

  test('pharmacy cancel catalog is exhaustive and stable', () {
    expect(pharmacyCancelReasonsCatalog(), hasLength(PharmacyCancelReason.values.length));
    expect(pharmacyCancelReasonsCatalog().first, PharmacyCancelReason.discontinuedByPrescriber);
  });
}
