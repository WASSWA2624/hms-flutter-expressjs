import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';

void main() {
  group('IpdBedBoardEntry', () {
    const IpdBedBoardEntry occupied = IpdBedBoardEntry(
      id: 'bed-1',
      displayId: 'BED-1',
      label: 'Bed 101',
      status: 'OCCUPIED',
      wardName: 'Medical Ward',
      roomName: 'Room A',
      occupantPatientName: 'Jane Doe',
      occupantAdmissionId: 'adm-1',
      occupantAdmissionDisplayId: 'ADM-1',
    );

    const IpdBedBoardEntry available = IpdBedBoardEntry(
      id: 'bed-2',
      label: 'Bed 102',
      status: 'AVAILABLE',
      wardName: 'Surgical Ward',
    );

    test('isOccupied reflects status and occupant', () {
      expect(occupied.isOccupied, isTrue);
      expect(available.isOccupied, isFalse);
    });

    test('bedLabel falls back through label, display id, then id', () {
      expect(occupied.bedLabel, 'Bed 101');
      expect(
        const IpdBedBoardEntry(id: 'bed-x', displayId: 'BED-X').bedLabel,
        'BED-X',
      );
      expect(const IpdBedBoardEntry(id: 'bed-y').bedLabel, 'bed-y');
    });

    test('matchesSearch matches patient and ward', () {
      expect(occupied.matchesSearch('jane'), isTrue);
      expect(occupied.matchesSearch('medical'), isTrue);
      expect(occupied.matchesSearch('xyz'), isFalse);
      expect(occupied.matchesSearch(''), isTrue);
    });
  });

  group('IpdDetailPanelX.fromToken', () {
    test('returns null for empty and unknown tokens', () {
      expect(IpdDetailPanelX.fromToken(null), isNull);
      expect(IpdDetailPanelX.fromToken(''), isNull);
      expect(IpdDetailPanelX.fromToken('bogus'), isNull);
    });

    test('resolves known panel tokens', () {
      expect(IpdDetailPanelX.fromToken('nursing'), IpdDetailPanel.nursing);
      expect(IpdDetailPanelX.fromToken('transfers'), IpdDetailPanel.transfer);
      expect(IpdDetailPanelX.fromToken('rounds'), IpdDetailPanel.rounds);
    });
  });

  group('IpdDischargeClearance', () {
    test('isComplete requires all steps unless override is set', () {
      const IpdDischargeClearance partial = IpdDischargeClearance(
        summaryReady: true,
        billingCleared: true,
      );
      expect(partial.isComplete, isFalse);

      const IpdDischargeClearance complete = IpdDischargeClearance(
        summaryReady: true,
        pendingOrdersReviewed: true,
        pharmacyCleared: true,
        billingCleared: true,
        nursingCleared: true,
        documentsReady: true,
        patientExited: true,
      );
      expect(complete.isComplete, isTrue);

      const IpdDischargeClearance override = IpdDischargeClearance(
        overrideReason: 'Clinical emergency',
      );
      expect(override.isComplete, isTrue);
    });
  });

  group('IpdWorkspaceSectionX', () {
    test('maps queue scopes and bed board', () {
      expect(
        IpdWorkspaceSection.admissionQueue.queueScope,
        IpdQueueScope.admissionQueue,
      );
      expect(
        IpdWorkspaceSection.activePatients.queueScope,
        IpdQueueScope.activePatients,
      );
      expect(IpdWorkspaceSection.bedBoard.queueScope, isNull);
      expect(IpdWorkspaceSection.bedBoard.isBedBoard, isTrue);
      expect(IpdWorkspaceSection.activePatients.isBedBoard, isFalse);
    });

    test('fromQueryParam accepts aliases', () {
      expect(
        IpdWorkspaceSectionX.fromQueryParam('active-patients'),
        IpdWorkspaceSection.activePatients,
      );
      expect(
        IpdWorkspaceSectionX.fromQueryParam('beds'),
        IpdWorkspaceSection.bedBoard,
      );
      expect(
        IpdWorkspaceSectionX.fromQueryParam('follow-ups'),
        IpdWorkspaceSection.followUps,
      );
      expect(
        IpdWorkspaceSectionX.fromQueryParam('unknown'),
        IpdWorkspaceSection.admissionQueue,
      );
    });
  });
}
