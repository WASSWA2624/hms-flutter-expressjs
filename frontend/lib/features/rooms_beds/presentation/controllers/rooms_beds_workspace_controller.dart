import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/realtime/realtime_message.dart';
import 'package:hosspi_hms/core/realtime/realtime_refresh.dart';
import 'package:hosspi_hms/core/realtime/realtime_scope.dart';
import 'package:hosspi_hms/core/security/session_isolation.dart';
import 'package:hosspi_hms/core/workspace/workspace_session_guard.dart';
import 'package:hosspi_hms/features/rooms_beds/data/repositories/rooms_beds_repository_impl.dart';
import 'package:hosspi_hms/features/rooms_beds/domain/entities/rooms_beds_entities.dart';
import 'package:hosspi_hms/features/rooms_beds/domain/repositories/rooms_beds_repository.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final roomsBedsWorkspaceControllerProvider =
    AsyncNotifierProvider<
      RoomsBedsWorkspaceController,
      Result<RoomsBedsWorkspaceState>
    >(RoomsBedsWorkspaceController.new);

final class RoomsBedsWorkspaceController
    extends AsyncNotifier<Result<RoomsBedsWorkspaceState>> {
  RoomsBedsRepository get _repository => ref.read(roomsBedsRepositoryProvider);

  @override
  Future<Result<RoomsBedsWorkspaceState>> build() {
    watchSessionEpoch(ref);
    listenForRealtimeRefresh(
      ref: ref,
      events: RealtimeEventGroups.roomsBeds,
      includeCrudMutations: true,
      shouldDefer: () => _currentState?.isSaving ?? false,
      shouldRefresh: (RealtimeMessage message) {
        final String? facilityId = ref.read(appAccessPolicyProvider).facilityId;
        return RealtimeScope.matchesMessage(
          message: message,
          facilityId: facilityId,
        );
      },
      onRefresh: (_) => refresh(),
    );
    final String? facilityId = ref.read(appAccessPolicyProvider).facilityId;
    return runWorkspaceInitialLoad(
      ref,
      () => _loadState(RoomsBedsQuery(facilityId: facilityId)),
    );
  }

  Future<AppFailure?> applyRouteQuery(RoomsBedsQuery query) async {
    final String? facilityId = ref.read(appAccessPolicyProvider).facilityId;
    final RoomsBedsQuery resolved = query.copyWith(
      facilityId: query.facilityId ?? facilityId,
    );
    _emitLoading(resolved);
    final Result<RoomsBedsWorkspaceState> result = await _loadState(
      resolved,
      selectedBedId: resolved.bedId,
    );
    state = AsyncData<Result<RoomsBedsWorkspaceState>>(result);
    return result.when(success: (_) => null, failure: (failure) => failure);
  }

  Future<AppFailure?> refresh() async {
    final RoomsBedsWorkspaceState? current = _currentState;
    if (current == null) {
      state = const AsyncValue<Result<RoomsBedsWorkspaceState>>.loading();
      final Result<RoomsBedsWorkspaceState> result = await build();
      state = AsyncData<Result<RoomsBedsWorkspaceState>>(result);
      return result.when(success: (_) => null, failure: (failure) => failure);
    }

    _emit(current.copyWith(isRefreshing: true, clearLastFailure: true));
    final Result<RoomsBedsWorkspaceState> result = await _loadState(
      current.query,
      selectedBedId: current.selectedBed?.id,
    );
    state = AsyncData<Result<RoomsBedsWorkspaceState>>(result);
    return result.when(success: (_) => null, failure: (failure) => failure);
  }

  Future<AppFailure?> applySearch(String search) {
    return _applyQuery((RoomsBedsQuery query) {
      return query.copyWith(
        search: search.trim(),
        pageRequest: query.pageRequest.first(),
      );
    });
  }

  Future<AppFailure?> applyFacility(String? facilityId) async {
    final RoomsBedsWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        query: current.query.copyWith(
          facilityId: facilityId,
          clearFacility: facilityId == null,
          clearWard: true,
          clearRoom: true,
          clearBed: true,
          pageRequest: current.query.pageRequest.first(),
        ),
        isRefreshing: true,
        clearSelectedBed: true,
        clearLastFailure: true,
      ),
    );

    final Result<RoomsBedsWorkspaceState> result = await _loadState(
      _currentState?.query ?? current.query,
    );
    state = AsyncData<Result<RoomsBedsWorkspaceState>>(result);
    return result.when(success: (_) => null, failure: (failure) => failure);
  }

  Future<AppFailure?> applyWard(String? wardId) {
    return _applyQuery((RoomsBedsQuery query) {
      return query.copyWith(
        wardId: wardId,
        clearWard: wardId == null,
        clearRoom: true,
        clearBed: true,
        pageRequest: query.pageRequest.first(),
      );
    });
  }

  Future<AppFailure?> applyRoom(String? roomId) {
    return _applyQuery((RoomsBedsQuery query) {
      return query.copyWith(
        roomId: roomId,
        clearRoom: roomId == null,
        clearBed: true,
        pageRequest: query.pageRequest.first(),
      );
    });
  }

  Future<AppFailure?> applyStatus(BedSetupStatus? status) {
    return _applyQuery((RoomsBedsQuery query) {
      return query.copyWith(
        status: status,
        clearStatus: status == null,
        pageRequest: query.pageRequest.first(),
      );
    });
  }

  Future<AppFailure?> changePage(AppPageRequest request) {
    return _applyQuery((RoomsBedsQuery query) {
      return query.copyWith(pageRequest: request);
    });
  }

  Future<AppFailure?> clearFilters() {
    final String? facilityId = _currentState?.query.facilityId;
    return _applyQuery((_) => RoomsBedsQuery(facilityId: facilityId));
  }

  Future<AppFailure?> selectBed(BedBoardItem bed) async {
    final RoomsBedsWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    final Result<List<BedAssignmentRecord>> assignmentsResult =
        await _repository.listBedAssignmentsForBed(bed.id);
    return assignmentsResult.when(
      success: (List<BedAssignmentRecord> assignments) async {
        BedBoardItem selected = bed.copyWith(
          activeAssignment: _activeAssignment(assignments),
          assignmentHistory: assignments,
          clearActiveAssignment: _activeAssignment(assignments) == null,
        );

        final String? admissionId = selected.currentAdmissionId;
        if (admissionId != null && admissionId.trim().isNotEmpty) {
          final Result<BedAdmissionContext> contextResult = await _repository
              .loadAdmissionContext(admissionId);
          contextResult.when(
            success: (BedAdmissionContext context) {
              selected = selected.copyWith(admissionContext: context);
            },
            failure: (_) {},
          );
        }

        final RoomsBedsWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              selectedBed: selected,
              beds: _replaceBedItem(latest.beds, selected),
              clearLastFailure: true,
            ),
          );
        }
        return null;
      },
      failure: (AppFailure failure) {
        _emit(current.copyWith(lastFailure: failure));
        return failure;
      },
    );
  }

  void clearSelection() {
    final RoomsBedsWorkspaceState? current = _currentState;
    if (current != null) {
      _emit(current.copyWith(clearSelectedBed: true));
    }
  }

  Future<AppFailure?> updateBedStatus(
    BedBoardItem item,
    BedSetupStatus status,
  ) async {
    final RoomsBedsWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    return _mutateBedStatus(current, item, status);
  }

  Future<AppFailure?> assignBed({
    required BedBoardItem item,
    required String admissionId,
  }) async {
    final RoomsBedsWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    return _mutateIpdBedAction(
      current,
      () => _repository.assignBed(admissionId: admissionId, bedId: item.id),
      item: item,
      status: BedSetupStatus.occupied,
    );
  }

  Future<AppFailure?> releaseBed({
    required BedBoardItem item,
    required String admissionId,
  }) async {
    final RoomsBedsWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    return _mutateIpdBedAction(
      current,
      () => _repository.releaseBed(admissionId: admissionId),
      item: item,
      status: BedSetupStatus.cleaning,
      clearAssignment: true,
    );
  }

  Future<AppFailure?> requestTransfer({
    required BedBoardItem item,
    required String admissionId,
    required String toWardId,
  }) async {
    final RoomsBedsWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    final Result<void> result = await _repository.requestTransfer(
      admissionId: admissionId,
      fromWardId: item.wardId,
      toWardId: toWardId,
    );

    return result.when(
      success: (_) async {
        final Result<BedAdmissionContext> contextResult = await _repository
            .loadAdmissionContext(admissionId);
        final RoomsBedsWorkspaceState? latest = _currentState;
        if (latest != null) {
          BedBoardItem? selected = latest.selectedBed?.id == item.id
              ? latest.selectedBed
              : item;
          contextResult.when(
            success: (BedAdmissionContext context) {
              selected = selected?.copyWith(admissionContext: context);
            },
            failure: (_) {},
          );
          _emit(
            latest.copyWith(
              isSaving: false,
              clearLastFailure: true,
              selectedBed: selected,
              beds: selected == null
                  ? latest.beds
                  : _replaceBedItem(latest.beds, selected!),
            ),
          );
        }
        return null;
      },
      failure: (AppFailure failure) {
        final RoomsBedsWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(isSaving: false, lastFailure: failure));
        }
        return failure;
      },
    );
  }

  Future<AppFailure?> updateTransfer({
    required BedBoardItem item,
    required String admissionId,
    required String action,
    String? transferRequestId,
    String? toBedId,
  }) async {
    final RoomsBedsWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    final Result<void> result = await _repository.updateTransfer(
      admissionId: admissionId,
      action: action,
      transferRequestId: transferRequestId,
      toBedId: toBedId,
    );

    return result.when(
      success: (_) async {
        final Result<RoomsBedsWorkspaceState> reload = await _loadState(
          current.query,
          selectedBedId: item.id,
        );
        state = AsyncData<Result<RoomsBedsWorkspaceState>>(reload);
        return reload.when(
          success: (_) => null,
          failure: (AppFailure failure) => failure,
        );
      },
      failure: (AppFailure failure) {
        final RoomsBedsWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(isSaving: false, lastFailure: failure));
        }
        return failure;
      },
    );
  }

  List<BedBoardItem> availableDestinationBeds({String? excludeBedId}) {
    final RoomsBedsWorkspaceState? current = _currentState;
    if (current == null) {
      return const <BedBoardItem>[];
    }

    return current.referenceData.beds
        .where((BedProfile bed) {
          if (excludeBedId != null && bed.id == excludeBedId) {
            return false;
          }
          return bed.status.isAssignable;
        })
        .map((BedProfile bed) {
          return BedBoardItem(
            bed: bed,
            facility: current.referenceData.facility,
            ward: current.referenceData.wards
                .where((WardProfile ward) => ward.id == bed.wardId)
                .firstOrNull,
            room: bed.roomId == null
                ? null
                : current.referenceData.rooms
                      .where((RoomProfile room) => room.id == bed.roomId)
                      .firstOrNull,
          );
        })
        .toList(growable: false);
  }

  Future<Result<RoomsBedsWorkspaceState>> _loadState(
    RoomsBedsQuery query, {
    String? selectedBedId,
  }) async {
    final Result<FacilitySetupSnapshot> result = await _repository.loadSetup(
      facilityId: query.facilityId,
    );

    return result.when(
      success: (FacilitySetupSnapshot snapshot) async {
        final RoomsBedsQuery resolvedQuery = query.copyWith(
          facilityId: query.facilityId ?? snapshot.facility?.id,
        );
        final RoomsBedsWorkspaceState nextState = await _stateFromSnapshot(
          resolvedQuery,
          snapshot,
          selectedBedId: selectedBedId ?? resolvedQuery.bedId,
        );
        return Result<RoomsBedsWorkspaceState>.success(nextState);
      },
      failure: (AppFailure failure) async {
        return Result<RoomsBedsWorkspaceState>.failure(failure);
      },
    );
  }

  Future<AppFailure?> _applyQuery(
    RoomsBedsQuery Function(RoomsBedsQuery query) update,
  ) async {
    final RoomsBedsWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    final RoomsBedsQuery query = update(current.query);
    _emit(
      current.copyWith(
        query: query,
        isRefreshing: true,
        clearLastFailure: true,
      ),
    );
    final RoomsBedsWorkspaceState nextState = await _stateFromSnapshot(
      query,
      current.referenceData.snapshot,
      selectedBedId: current.selectedBed?.id,
    );
    _emit(nextState.copyWith(isRefreshing: false));
    return null;
  }

  Future<AppFailure?> _mutateBedStatus(
    RoomsBedsWorkspaceState current,
    BedBoardItem item,
    BedSetupStatus status,
  ) async {
    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    final Result<BedProfile> result = await _repository.updateBedStatus(
      bed: item.bed,
      status: status,
    );
    return result.when(
      success: (BedProfile bed) async {
        final RoomsBedsWorkspaceState? latest = _currentState;
        if (latest == null) {
          return null;
        }
        final FacilitySetupSnapshot snapshot = _replaceBedProfile(
          latest.referenceData.snapshot,
          bed,
        );
        final RoomsBedsWorkspaceState nextState = await _stateFromSnapshot(
          latest.query,
          snapshot,
          selectedBedId: item.id,
        );
        _emit(nextState.copyWith(isSaving: false, clearLastFailure: true));
        return null;
      },
      failure: (AppFailure failure) {
        final RoomsBedsWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(isSaving: false, lastFailure: failure));
        }
        return failure;
      },
    );
  }

  Future<AppFailure?> _mutateIpdBedAction(
    RoomsBedsWorkspaceState current,
    Future<Result<void>> Function() action, {
    required BedBoardItem item,
    required BedSetupStatus status,
    bool clearAssignment = false,
  }) async {
    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    final Result<void> result = await action();
    return result.when(
      success: (_) async {
        final RoomsBedsWorkspaceState? latest = _currentState;
        if (latest == null) {
          return null;
        }
        final FacilitySetupSnapshot snapshot = _replaceBedStatus(
          latest.referenceData.snapshot,
          item.id,
          status,
        );
        final RoomsBedsWorkspaceState nextState = await _stateFromSnapshot(
          latest.query,
          snapshot,
          selectedBedId: item.id,
        );
        if (clearAssignment) {
          final BedBoardItem? selected = nextState.selectedBed;
          if (selected != null) {
            _emit(
              nextState.copyWith(
                isSaving: false,
                clearLastFailure: true,
                selectedBed: selected.copyWith(
                  clearActiveAssignment: true,
                  clearAdmissionContext: true,
                  assignmentHistory: selected.assignmentHistory
                      .map(
                        (BedAssignmentRecord record) => record.isActive
                            ? BedAssignmentRecord(
                                id: record.id,
                                admissionId: record.admissionId,
                                bedId: record.bedId,
                                admissionDisplayId: record.admissionDisplayId,
                                assignedAt: record.assignedAt,
                                releasedAt: DateTime.now().toUtc(),
                              )
                            : record,
                      )
                      .toList(growable: false),
                ),
              ),
            );
            return null;
          }
        }
        _emit(nextState.copyWith(isSaving: false, clearLastFailure: true));
        return null;
      },
      failure: (AppFailure failure) {
        final RoomsBedsWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(isSaving: false, lastFailure: failure));
        }
        return failure;
      },
    );
  }

  Future<RoomsBedsWorkspaceState> _stateFromSnapshot(
    RoomsBedsQuery query,
    FacilitySetupSnapshot snapshot, {
    String? selectedBedId,
  }) async {
    final RoomsBedsReferenceData referenceData = RoomsBedsReferenceData(
      snapshot: snapshot,
    );
    final AppPage<BedBoardItem> page = _pageFromSnapshot(query, snapshot);
    final AppPage<BedBoardItem> pageWithAssignments =
        await _attachAssignmentsToPage(page);
    final BedBoardItem? selectedBed = selectedBedId == null
        ? null
        : await _selectedBedFromSnapshot(
            selectedBedId,
            snapshot,
            pageWithAssignments,
          );

    return RoomsBedsWorkspaceState(
      query: query,
      beds: pageWithAssignments,
      referenceData: referenceData,
      selectedBed: selectedBed,
    );
  }

  AppPage<BedBoardItem> _pageFromSnapshot(
    RoomsBedsQuery query,
    FacilitySetupSnapshot snapshot,
  ) {
    final Map<String, FacilityProfile> facilitiesById =
        <String, FacilityProfile>{
          for (final FacilityProfile facility in snapshot.facilities)
            facility.id: facility,
        };
    final Map<String, WardProfile> wardsById = <String, WardProfile>{
      for (final WardProfile ward in snapshot.wards) ward.id: ward,
    };
    final Map<String, RoomProfile> roomsById = <String, RoomProfile>{
      for (final RoomProfile room in snapshot.rooms) room.id: room,
    };

    final List<BedBoardItem> filtered = snapshot.beds
        .where((BedProfile bed) {
          if (query.facilityId != null && bed.facilityId != query.facilityId) {
            return false;
          }
          if (query.wardId != null && bed.wardId != query.wardId) {
            return false;
          }
          if (query.roomId != null && bed.roomId != query.roomId) {
            return false;
          }
          if (query.bedId != null && bed.id != query.bedId) {
            return false;
          }
          if (query.status != null && bed.status != query.status) {
            return false;
          }
          return true;
        })
        .map(
          (BedProfile bed) => BedBoardItem(
            bed: bed,
            facility: facilitiesById[bed.facilityId] ?? snapshot.facility,
            ward: wardsById[bed.wardId],
            room: bed.roomId == null ? null : roomsById[bed.roomId],
          ),
        )
        .where((BedBoardItem item) => item.matchesSearch(query.search))
        .toList(growable: false);

    final int start = query.pageRequest.offset.clamp(0, filtered.length);
    final int end = (start + query.pageRequest.pageSize).clamp(
      start,
      filtered.length,
    );

    return AppPage<BedBoardItem>(
      items: filtered.sublist(start, end),
      request: query.pageRequest,
      totalItemCount: filtered.length,
    );
  }

  Future<AppPage<BedBoardItem>> _attachAssignmentsToPage(
    AppPage<BedBoardItem> page,
  ) async {
    final List<BedBoardItem> items = await Future.wait(
      page.items.map(_attachAssignmentsIfOperational),
    );
    return AppPage<BedBoardItem>(
      items: items,
      request: page.request,
      totalItemCount: page.totalItemCount,
    );
  }

  Future<BedBoardItem> _attachAssignmentsIfOperational(BedBoardItem item) {
    if (item.status.isAssignable || item.status.isNonAssignableOperational) {
      return Future<BedBoardItem>.value(item);
    }
    return _attachAssignments(item);
  }

  Future<BedBoardItem> _attachAssignments(BedBoardItem item) async {
    final Result<List<BedAssignmentRecord>> result = await _repository
        .listBedAssignmentsForBed(item.id);
    return result.when(
      success: (List<BedAssignmentRecord> assignments) async {
        BedBoardItem next = item.copyWith(
          activeAssignment: _activeAssignment(assignments),
          assignmentHistory: assignments,
          clearActiveAssignment: _activeAssignment(assignments) == null,
        );
        final String? admissionId = next.currentAdmissionId;
        if (admissionId != null && admissionId.trim().isNotEmpty) {
          final Result<BedAdmissionContext> contextResult = await _repository
              .loadAdmissionContext(admissionId);
          contextResult.when(
            success: (BedAdmissionContext context) {
              next = next.copyWith(admissionContext: context);
            },
            failure: (_) {},
          );
        }
        return next;
      },
      failure: (_) => item,
    );
  }

  Future<BedBoardItem?> _selectedBedFromSnapshot(
    String bedId,
    FacilitySetupSnapshot snapshot,
    AppPage<BedBoardItem> visiblePage,
  ) async {
    final BedBoardItem? visible = visiblePage.items
        .where((BedBoardItem item) => item.id == bedId)
        .firstOrNull;
    if (visible != null) {
      return _attachAssignments(visible);
    }

    final BedProfile? bed = snapshot.beds
        .where((BedProfile item) => item.id == bedId)
        .firstOrNull;
    if (bed == null) {
      return null;
    }

    final FacilityProfile? facility =
        snapshot.facilities
            .where((FacilityProfile item) => item.id == bed.facilityId)
            .firstOrNull ??
        snapshot.facility;
    final WardProfile? ward = snapshot.wards
        .where((WardProfile item) => item.id == bed.wardId)
        .firstOrNull;
    final RoomProfile? room = bed.roomId == null
        ? null
        : snapshot.rooms
              .where((RoomProfile item) => item.id == bed.roomId)
              .firstOrNull;
    return _attachAssignments(
      BedBoardItem(bed: bed, facility: facility, ward: ward, room: room),
    );
  }

  AppPage<BedBoardItem> _replaceBedItem(
    AppPage<BedBoardItem> page,
    BedBoardItem item,
  ) {
    return AppPage<BedBoardItem>(
      items: <BedBoardItem>[
        for (final BedBoardItem current in page.items)
          if (current.id == item.id) item else current,
      ],
      request: page.request,
      totalItemCount: page.totalItemCount,
    );
  }

  FacilitySetupSnapshot _replaceBedStatus(
    FacilitySetupSnapshot snapshot,
    String bedId,
    BedSetupStatus status,
  ) {
    final BedProfile? bed = snapshot.beds
        .where((BedProfile item) => item.id == bedId)
        .firstOrNull;
    if (bed == null) {
      return snapshot;
    }
    return _replaceBedProfile(
      snapshot,
      BedProfile(
        id: bed.id,
        tenantId: bed.tenantId,
        facilityId: bed.facilityId,
        wardId: bed.wardId,
        label: bed.label,
        status: status,
        roomId: bed.roomId,
      ),
    );
  }

  FacilitySetupSnapshot _replaceBedProfile(
    FacilitySetupSnapshot snapshot,
    BedProfile bed,
  ) {
    return snapshot.copyWith(
      beds: <BedProfile>[
        for (final BedProfile current in snapshot.beds)
          if (current.id == bed.id) bed else current,
      ],
    );
  }

  BedAssignmentRecord? _activeAssignment(
    List<BedAssignmentRecord> assignments,
  ) {
    return assignments
        .where((BedAssignmentRecord item) => item.isActive)
        .firstOrNull;
  }

  RoomsBedsWorkspaceState? get _currentState {
    final Result<RoomsBedsWorkspaceState>? currentResult = state.asData?.value;
    return switch (currentResult) {
      ResultSuccess<RoomsBedsWorkspaceState>(value: final value) => value,
      _ => null,
    };
  }

  void _emitLoading(RoomsBedsQuery query) {
    final RoomsBedsWorkspaceState? current = _currentState;
    if (current != null) {
      _emit(
        current.copyWith(
          query: query,
          isRefreshing: true,
          clearLastFailure: true,
        ),
      );
      return;
    }
    state = const AsyncValue<Result<RoomsBedsWorkspaceState>>.loading();
  }

  void _emit(RoomsBedsWorkspaceState nextState) {
    state = AsyncData<Result<RoomsBedsWorkspaceState>>(
      Result<RoomsBedsWorkspaceState>.success(nextState),
    );
  }
}
