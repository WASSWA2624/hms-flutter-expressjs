import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/features/reception/domain/entities/reception_entities.dart';

BillingWorkItem _invoice({
  required String id,
  String patientId = 'patient-1',
  String patientDisplayId = 'PAT-001',
  String patientName = 'Penny Patient',
  String encounterId = 'encounter-1',
  String encounterDisplayId = 'ENC-001',
  String source = 'LABORATORY',
  String status = 'SENT',
  String billingStatus = 'ISSUED',
  num total = 100,
  num paid = 0,
  num balance = 100,
  String currency = 'UGX',
  DateTime? timelineAt,
}) {
  return BillingWorkItem(
    id: id,
    displayId: id.toUpperCase(),
    kind: BillingWorkItemKind.invoice,
    patientId: patientId,
    patientDisplayId: patientDisplayId,
    patientDisplayName: patientName,
    encounterId: encounterId,
    encounterDisplayId: encounterDisplayId,
    sourceModule: source,
    status: status,
    billingStatus: billingStatus,
    currency: currency,
    timelineAt: timelineAt,
    items: <BillingInvoiceItem>[
      BillingInvoiceItem(
        id: 'line-$id',
        description: '$source service',
        sourceModule: source,
        totalPrice: total,
      ),
    ],
    financials: BillingFinancials(
      invoiceTotal: total,
      effectiveTotal: total,
      netPaidTotal: paid,
      balanceDue: balance,
    ),
  );
}

void main() {
  group('aggregateReceptionPaymentGateEntries', () {
    test('groups outstanding OPD invoices by patient and encounter', () {
      final List<ReceptionPaymentGateEntry> entries =
          aggregateReceptionPaymentGateEntries(<BillingWorkItem>[
            _invoice(id: 'lab-1'),
            _invoice(
              id: 'rad-1',
              source: 'RADIOLOGY',
              billingStatus: 'PARTIAL',
              total: 200,
              paid: 50,
              balance: 150,
            ),
            _invoice(
              id: 'pharm-1',
              source: 'PHARMACY',
              patientId: 'patient-2',
              patientDisplayId: 'PAT-002',
              patientName: 'Paul Pharmacy',
              encounterId: 'encounter-2',
              encounterDisplayId: 'ENC-002',
              total: 75,
              balance: 75,
            ),
          ]);

      expect(entries, hasLength(2));
      final ReceptionPaymentGateEntry penny = entries.singleWhere(
        (ReceptionPaymentGateEntry entry) =>
            entry.patientIdentifier == 'PAT-001',
      );
      expect(penny.invoices, hasLength(2));
      expect(penny.services, <String>{'LABORATORY', 'RADIOLOGY'});
      expect(penny.outstandingByCurrency, <String, num>{'UGX': 250});
      expect(penny.clearanceState, BillingClearanceState.partiallyPaid);
    });

    test('keeps currencies separate instead of adding unlike money', () {
      final ReceptionPaymentGateEntry entry =
          aggregateReceptionPaymentGateEntries(<BillingWorkItem>[
            _invoice(id: 'ugx'),
            _invoice(id: 'usd', balance: 5, currency: 'USD'),
          ]).single;

      expect(entry.outstandingByCurrency, <String, num>{'UGX': 100, 'USD': 5});
    });

    test('issuedAt uses the latest invoice timelineAt', () {
      final ReceptionPaymentGateEntry entry =
          aggregateReceptionPaymentGateEntries(<BillingWorkItem>[
            _invoice(
              id: 'older',
              timelineAt: DateTime.utc(2026, 6, 1),
            ),
            _invoice(
              id: 'newer',
              source: 'RADIOLOGY',
              timelineAt: DateTime.utc(2026, 7, 15),
            ),
          ]).single;

      expect(entry.issuedAt, DateTime.utc(2026, 7, 15));
    });

    test('excludes resolved, unknown, non-OPD, and unlinked invoices', () {
      final List<ReceptionPaymentGateEntry> entries =
          aggregateReceptionPaymentGateEntries(<BillingWorkItem>[
            _invoice(id: 'paid', billingStatus: 'PAID', balance: 0),
            _invoice(id: 'cancelled', status: 'CANCELLED'),
            _invoice(id: 'unknown-status', billingStatus: 'MYSTERY'),
            _invoice(id: 'unknown-source', source: 'MYSTERY'),
            _invoice(id: 'inpatient', source: 'ADMISSION'),
            _invoice(
              id: 'no-encounter',
              encounterId: '',
              encounterDisplayId: '',
            ),
          ]);

      expect(entries, isEmpty);
    });

    test('recovers encounter-linked consultation invoices without source_module', () {
      final BillingWorkItem orphanConsultation = BillingWorkItem(
        id: 'consult-orphan',
        displayId: 'INV-ORPHAN',
        kind: BillingWorkItemKind.invoice,
        patientId: 'patient-1',
        patientDisplayId: 'PAT-001',
        patientDisplayName: 'Penny Patient',
        encounterId: 'encounter-1',
        encounterDisplayId: 'ENC-001',
        status: 'SENT',
        billingStatus: 'ISSUED',
        currency: 'UGX',
        items: const <BillingInvoiceItem>[
          BillingInvoiceItem(
            id: 'line-consult',
            description: 'Consultation fee',
            totalPrice: 25000,
          ),
        ],
        financials: const BillingFinancials(
          invoiceTotal: 25000,
          effectiveTotal: 25000,
          netPaidTotal: 0,
          balanceDue: 25000,
        ),
      );

      expect(isReceptionOutstandingOpdInvoice(orphanConsultation), isTrue);
      final List<ReceptionPaymentGateEntry> entries =
          aggregateReceptionPaymentGateEntries(<BillingWorkItem>[
            orphanConsultation,
          ]);
      expect(entries, hasLength(1));
      expect(entries.single.services, <String>{'CONSULTATION'});
      expect(entries.single.outstandingByCurrency, <String, num>{'UGX': 25000});
    });

    test('recognizes all supported OPD service sources', () {
      for (final String source in receptionOpdBillingSources) {
        expect(
          isReceptionOutstandingOpdInvoice(
            _invoice(id: source.toLowerCase(), source: source),
          ),
          isTrue,
          reason: source,
        );
      }
    });
  });
}
