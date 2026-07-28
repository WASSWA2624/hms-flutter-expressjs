import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/icu/domain/entities/icu_entities.dart';
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_next_action_button.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';

void main() {
  final AppLocalizations l10n = lookupAppLocalizations(const Locale('en'));

  group('icuBoardNextActionKind', () {
    test('active patient without bed resolves to assign bed', () {
      const IcuPatientSummary item = IcuPatientSummary(
        id: 'ADM-1',
        admissionId: 'ADM-1',
        icuStatus: 'ACTIVE',
        hasActiveBed: false,
      );
      expect(
        icuBoardNextActionKind(item, IcuWorkspaceSection.active),
        IcuNextActionKind.assignBed,
      );
    });

    test('critical section prefers acknowledge alert', () {
      const IcuPatientSummary item = IcuPatientSummary(
        id: 'ADM-2',
        admissionId: 'ADM-2',
        icuStatus: 'ACTIVE',
        hasCriticalAlert: true,
        hasActiveBed: true,
      );
      expect(
        icuBoardNextActionKind(item, IcuWorkspaceSection.critical),
        IcuNextActionKind.acknowledgeAlert,
      );
    });

    test('transfers section without open transfer requests transfer', () {
      const IcuPatientSummary item = IcuPatientSummary(
        id: 'ADM-3',
        admissionId: 'ADM-3',
        icuStatus: 'ACTIVE',
        hasActiveBed: true,
      );
      expect(
        icuBoardNextActionKind(item, IcuWorkspaceSection.transfers),
        IcuNextActionKind.requestTransfer,
      );
    });

    test('ended section resolves to open IPD', () {
      const IcuPatientSummary item = IcuPatientSummary(
        id: 'ADM-4',
        admissionId: 'ADM-4',
        icuStatus: 'ENDED',
      );
      expect(
        icuBoardNextActionKind(item, IcuWorkspaceSection.ended),
        IcuNextActionKind.openIpd,
      );
    });

    test('eligible non-active patient resolves to start stay', () {
      const IcuPatientSummary item = IcuPatientSummary(
        id: 'ADM-5',
        admissionId: 'ADM-5',
        icuStatus: 'PENDING',
        admissionStatus: 'ADMITTED',
      );
      expect(
        icuBoardNextActionKind(item, IcuWorkspaceSection.active),
        IcuNextActionKind.startStay,
      );
    });

    test('detail omit kind matches board primary so duplicates stay removed', () {
      const IcuPatientSummary item = IcuPatientSummary(
        id: 'ADM-6',
        admissionId: 'ADM-6',
        icuStatus: 'ACTIVE',
        hasCriticalAlert: true,
        hasActiveBed: true,
      );
      final IcuNextActionKind? kind = icuBoardNextActionKind(
        item,
        IcuWorkspaceSection.critical,
      );
      expect(kind, IcuNextActionKind.acknowledgeAlert);
      expect(
        icuNextActionLabel(l10n, kind!),
        l10n.icuActionAcknowledgeAlert,
      );
    });
  });
}
