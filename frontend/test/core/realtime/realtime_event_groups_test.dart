import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/realtime/realtime_events.dart';

void main() {
  group('RealtimeEventGroups', () {
    test('exposes patient registry invalidation events', () {
      expect(RealtimeEvents.patientCreated, 'patient.created');
      expect(
        RealtimeEventGroups.patientRegistry,
        contains(RealtimeEvents.patientCreated),
      );
      expect(
        RealtimeEventGroups.patientRegistry,
        contains(RealtimeEvents.patientUpdated),
      );
      expect(
        RealtimeEventGroups.patientRegistry,
        contains(RealtimeEvents.patientDeleted),
      );
    });

    test('routes encounter and visit queue events to OPD workspace', () {
      expect(
        RealtimeEventGroups.opdFlow,
        contains(RealtimeEvents.encounterCreated),
      );
      expect(
        RealtimeEventGroups.opdFlow,
        contains(RealtimeEvents.encounterUpdated),
      );
      expect(
        RealtimeEventGroups.opdFlow,
        contains(RealtimeEvents.visitQueueCreated),
      );
      expect(
        RealtimeEventGroups.opdFlow,
        contains(RealtimeEvents.visitQueuePositionChanged),
      );
    });

    test('routes payment, invoice, and balance events to billing workspace', () {
      expect(RealtimeEvents.paymentReconciled, 'payment.reconciled');
      expect(
        RealtimeEventGroups.billingWorkspace,
        contains(RealtimeEvents.paymentCreated),
      );
      expect(
        RealtimeEventGroups.billingWorkspace,
        contains(RealtimeEvents.paymentReconciled),
      );
      expect(
        RealtimeEventGroups.billingWorkspace,
        contains(RealtimeEvents.invoiceUpdated),
      );
      expect(
        RealtimeEventGroups.billingWorkspace,
        contains(RealtimeEvents.billingBalanceUpdated),
      );
    });
  });
}
