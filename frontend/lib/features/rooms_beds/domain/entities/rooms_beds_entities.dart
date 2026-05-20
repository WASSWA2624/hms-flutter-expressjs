import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/shared/data/data.dart';

@immutable
final class RoomsBedsQuery {
  const RoomsBedsQuery({
    this.search = '',
    this.facilityId,
    this.wardId,
    this.roomId,
    this.status,
    this.pageRequest = const AppPageRequest(),
  });

  final String search;
  final String? facilityId;
  final String? wardId;
  final String? roomId;
  final BedSetupStatus? status;
  final AppPageRequest pageRequest;

  RoomsBedsQuery copyWith({
    String? search,
    String? facilityId,
    String? wardId,
    String? roomId,
    BedSetupStatus? status,
    AppPageRequest? pageRequest,
    bool clearFacility = false,
    bool clearWard = false,
    bool clearRoom = false,
    bool clearStatus = false,
  }) {
    return RoomsBedsQuery(
      search: search ?? this.search,
      facilityId: clearFacility ? null : facilityId ?? this.facilityId,
      wardId: clearWard ? null : wardId ?? this.wardId,
      roomId: clearRoom ? null : roomId ?? this.roomId,
      status: clearStatus ? null : status ?? this.status,
      pageRequest: pageRequest ?? this.pageRequest,
    );
  }

  bool get hasFilters {
    return search.trim().isNotEmpty ||
        facilityId != null ||
        wardId != null ||
        roomId != null ||
        status != null;
  }
}

@immutable
final class BedAssignmentRecord {
  const BedAssignmentRecord({
    required this.id,
    required this.admissionId,
    required this.bedId,
    this.assignedAt,
    this.releasedAt,
  });

  final String id;
  final String admissionId;
  final String bedId;
  final DateTime? assignedAt;
  final DateTime? releasedAt;

  bool get isActive => releasedAt == null;
}

@immutable
final class BedBoardItem {
  const BedBoardItem({
    required this.bed,
    this.facility,
    this.ward,
    this.room,
    this.activeAssignment,
    this.assignmentHistory = const <BedAssignmentRecord>[],
  });

  final BedProfile bed;
  final FacilityProfile? facility;
  final WardProfile? ward;
  final RoomProfile? room;
  final BedAssignmentRecord? activeAssignment;
  final List<BedAssignmentRecord> assignmentHistory;

  String get id => bed.id;
  String get label => bed.label;
  BedSetupStatus get status => bed.status;
  String? get facilityId => bed.facilityId;
  String? get wardId => bed.wardId;
  String? get roomId => bed.roomId;
  String? get currentAdmissionId => activeAssignment?.admissionId;

  bool get isAvailable => status == BedSetupStatus.available;
  bool get isOccupied => status == BedSetupStatus.occupied;
  bool get isReserved => status == BedSetupStatus.reserved;
  bool get isOutOfService => status == BedSetupStatus.outOfService;

  BedBoardItem copyWith({
    BedProfile? bed,
    FacilityProfile? facility,
    WardProfile? ward,
    RoomProfile? room,
    BedAssignmentRecord? activeAssignment,
    List<BedAssignmentRecord>? assignmentHistory,
    bool clearActiveAssignment = false,
  }) {
    return BedBoardItem(
      bed: bed ?? this.bed,
      facility: facility ?? this.facility,
      ward: ward ?? this.ward,
      room: room ?? this.room,
      activeAssignment: clearActiveAssignment
          ? null
          : activeAssignment ?? this.activeAssignment,
      assignmentHistory: assignmentHistory ?? this.assignmentHistory,
    );
  }

  bool matchesSearch(String search) {
    final String needle = search.trim().toLowerCase();
    if (needle.isEmpty) {
      return true;
    }

    return <String?>[
      bed.id,
      bed.label,
      bed.status.apiValue,
      facility?.name,
      ward?.name,
      room?.name,
      room?.floor,
      activeAssignment?.admissionId,
    ].whereType<String>().any(
      (String value) => value.toLowerCase().contains(needle),
    );
  }
}

@immutable
final class RoomsBedsReferenceData {
  const RoomsBedsReferenceData({required this.snapshot});

  final FacilitySetupSnapshot snapshot;

  TenantProfile? get tenant => snapshot.tenant;
  FacilityProfile? get facility => snapshot.facility;
  List<FacilityProfile> get facilities => snapshot.facilities;
  List<WardProfile> get wards => snapshot.wards;
  List<RoomProfile> get rooms => snapshot.rooms;
  List<BedProfile> get beds => snapshot.beds;

  RoomsBedsReferenceData copyWith({FacilitySetupSnapshot? snapshot}) {
    return RoomsBedsReferenceData(snapshot: snapshot ?? this.snapshot);
  }
}

@immutable
final class RoomsBedsWorkspaceState {
  const RoomsBedsWorkspaceState({
    required this.query,
    required this.beds,
    required this.referenceData,
    this.selectedBed,
    this.lastFailure,
    this.isRefreshing = false,
    this.isSaving = false,
  });

  final RoomsBedsQuery query;
  final AppPage<BedBoardItem> beds;
  final RoomsBedsReferenceData referenceData;
  final BedBoardItem? selectedBed;
  final Object? lastFailure;
  final bool isRefreshing;
  final bool isSaving;

  int get totalBedCount => referenceData.beds.length;
  int get availableCount => _statusCount(BedSetupStatus.available);
  int get occupiedCount => _statusCount(BedSetupStatus.occupied);
  int get reservedCount => _statusCount(BedSetupStatus.reserved);
  int get outOfServiceCount => _statusCount(BedSetupStatus.outOfService);
  int get workloadCount => occupiedCount + reservedCount + outOfServiceCount;

  RoomsBedsWorkspaceState copyWith({
    RoomsBedsQuery? query,
    AppPage<BedBoardItem>? beds,
    RoomsBedsReferenceData? referenceData,
    BedBoardItem? selectedBed,
    Object? lastFailure,
    bool? isRefreshing,
    bool? isSaving,
    bool clearSelectedBed = false,
    bool clearLastFailure = false,
  }) {
    return RoomsBedsWorkspaceState(
      query: query ?? this.query,
      beds: beds ?? this.beds,
      referenceData: referenceData ?? this.referenceData,
      selectedBed: clearSelectedBed ? null : selectedBed ?? this.selectedBed,
      lastFailure: clearLastFailure ? null : lastFailure ?? this.lastFailure,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isSaving: isSaving ?? this.isSaving,
    );
  }

  int _statusCount(BedSetupStatus status) {
    return referenceData.beds.where((BedProfile bed) {
      return bed.status == status;
    }).length;
  }
}
