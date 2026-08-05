import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pharmacy_order_invoice_print_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';

void main() {
  group('pharmacyOrderInvoiceHtml', () {
    testWidgets('renders medication lines with qty columns', (tester) async {
      late String html;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (BuildContext context) {
              html = pharmacyOrderInvoiceHtml(
                context,
                PharmacyOrderWorkflow(
                  order: _sampleOrder(),
                  items: <PharmacyOrderItem>[_sampleItem()],
                ),
                includeMoney: false,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(html, contains('Paracetamol'));
      expect(html, contains('print-template-table'));
      expect(html, contains('<td>1</td>'));
      expect(html, contains('<td>10</td>'));
    });

    testWidgets('includes money columns when includeMoney is true', (
      tester,
    ) async {
      late String html;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (BuildContext context) {
              html = pharmacyOrderInvoiceHtml(
                context,
                PharmacyOrderWorkflow(
                  order: _sampleOrder(
                    billing: const <String, Object?>{
                      'total_amount': 50,
                      'currency': 'UGX',
                    },
                  ),
                  items: <PharmacyOrderItem>[
                    _sampleItem(pharmacyUnitPrice: 5, pharmacyCurrency: 'UGX'),
                  ],
                ),
                includeMoney: true,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(html, contains('Paracetamol'));
      expect(html, contains('5'));
    });
  });

  group('pharmacyOrderInvoiceSubtitle', () {
    testWidgets('includes order id and payment status when present', (
      tester,
    ) async {
      late String subtitle;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (BuildContext context) {
              subtitle = pharmacyOrderInvoiceSubtitle(
                context,
                _sampleOrder(paymentStatus: 'PAID'),
                false,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(subtitle, contains('PHO-1'));
      expect(subtitle.toLowerCase(), contains('paid'));
    });
  });
}

PharmacyOrder _sampleOrder({
  Map<String, Object?> billing = const <String, Object?>{},
  String? paymentStatus,
}) {
  return PharmacyOrder(
    id: 'order-1',
    displayId: 'PHO-1',
    patientDisplayName: 'Ada Lovelace',
    patientId: 'patient-1',
    status: 'ORDERED',
    itemCount: 1,
    quantityPrescribedTotal: 10,
    paymentStatus: paymentStatus,
    billing: billing,
    items: <PharmacyOrderItem>[_sampleItem()],
  );
}

PharmacyOrderItem _sampleItem({num? pharmacyUnitPrice, String? pharmacyCurrency}) {
  return PharmacyOrderItem(
    id: 'item-1',
    drugDisplayName: 'Paracetamol',
    quantityPrescribed: 10,
    quantityDispensed: 0,
    quantityRemaining: 10,
    pharmacyUnitPrice: pharmacyUnitPrice,
    pharmacyCurrency: pharmacyCurrency,
  );
}
