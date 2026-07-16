import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';

void main() {
  testWidgets('pharmacyOrderSearchMatcher matches patient and order id', (
    WidgetTester tester,
  ) async {
    const PharmacyOrder order = PharmacyOrder(
      id: 'order-1',
      displayId: 'PHO-100',
      patientDisplayName: 'Jane Pharmacy',
      location: 'OUTPATIENT',
      status: 'ORDERED',
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) {
            expect(pharmacyOrderSearchMatcher(context, order, 'jane'), isTrue);
            expect(
              pharmacyOrderSearchMatcher(context, order, 'pho-100'),
              isTrue,
            );
            expect(
              pharmacyOrderSearchMatcher(context, order, 'missing'),
              isFalse,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });
}
