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
}
