import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/realtime/realtime_refresh.dart';
import 'package:hosspi_hms/features/hr/data/repositories/hr_repository_impl.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/domain/repositories/hr_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final hrWorkspaceControllerProvider =
    AsyncNotifierProvider<HrWorkspaceController, Result<HrWorkspaceState>>(
      HrWorkspaceController.new,
    );

final class HrWorkspaceController
    extends AsyncNotifier<Result<HrWorkspaceState>> {
  static const Duration _syncInterval = Duration(seconds: 20);

  HrRepository get _repository => ref.read(hrRepositoryProvider);

  Timer? _syncTimer;
  bool _isSyncing = false;

  @override
  Future<Result<HrWorkspaceState>> build() async {
    ref.onDispose(() => _syncTimer?.cancel());
    listenForRealtimeRefresh(
      ref: ref,
      events: RealtimeEventGroups.hr,
      onRefresh: (_) => _syncFromRealtime(),
    );
    final Result<HrWorkspaceState> result = await _loadInitialState();
    _startSync();
    return result;
  }

  Future<void> _syncFromRealtime() async {
    await _syncVisibleData();
  }

  Future<AppFailure?> refresh() {
    return _syncVisibleData(showLoading: true, refreshReferences: true);
  }

  Future<AppFailure?> applyStaffSearch(String value) async {
    final HrWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        staffQuery: current.staffQuery.copyWith(
          search: value.trim(),
          pageRequest: current.staffQuery.pageRequest.first(),
        ),
        isRefreshingStaff: true,
        clearLastFailure: true,
      ),
    );
    return _refreshStaff(showLoading: true);
  }

  Future<AppFailure?> applyStaffFilters({
    String? departmentId,
    String? position,
    String? practitionerType,
  }) async {
    final HrWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        staffQuery: current.staffQuery.copyWith(
          departmentId: departmentId,
          position: position,
          practitionerType: practitionerType,
          clearDepartmentId: departmentId == null,
          clearPosition: position == null,
          clearPractitionerType: practitionerType == null,
          pageRequest: current.staffQuery.pageRequest.first(),
        ),
        workItemsQuery: current.workItemsQuery.copyWith(
          departmentId: departmentId,
          clearDepartmentId: departmentId == null,
          pageRequest: current.workItemsQuery.pageRequest.first(),
        ),
        isRefreshingStaff: true,
        isRefreshingWorkItems: true,
        clearLastFailure: true,
      ),
    );
    final AppFailure? staffFailure = await _refreshStaff(showLoading: true);
    final AppFailure? itemsFailure = await _refreshWorkItems(showLoading: true);
    return staffFailure ?? itemsFailure;
  }

  Future<AppFailure?> clearStaffFilters() {
    return applyStaffFilters();
  }

  Future<AppFailure?> changeStaffPage(AppPageRequest request) async {
    final HrWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        staffQuery: current.staffQuery.copyWith(pageRequest: request),
        isRefreshingStaff: true,
        clearLastFailure: true,
      ),
    );
    return _refreshStaff(showLoading: true);
  }

  Future<AppFailure?> selectStaff(HrStaffProfile profile) async {
    final HrWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(current.copyWith(isRefreshingDetail: true, clearLastFailure: true));
    final Result<HrStaffDetail> result = await _repository.loadStaffDetail(
      profile,
    );
    return result.when(
      success: (HrStaffDetail detail) {
        final HrWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              selectedStaff: detail,
              staff: _replaceStaff(latest.staff, detail.profile),
              isRefreshingDetail: false,
            ),
          );
        }
        return null;
      },
      failure: (AppFailure failure) {
        final HrWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(isRefreshingDetail: false, lastFailure: failure),
          );
        }
        return failure;
      },
    );
  }

  Future<AppFailure?> applyQueue(HrQueue queue) async {
    final HrWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        workItemsQuery: current.workItemsQuery.copyWith(
          queue: queue,
          clearStatus: true,
          pageRequest: current.workItemsQuery.pageRequest.first(),
        ),
        isRefreshingWorkItems: true,
        clearLastFailure: true,
      ),
    );
    return _refreshWorkItems(showLoading: true);
  }

  Future<AppFailure?> changeWorkItemsPage(AppPageRequest request) async {
    final HrWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        workItemsQuery: current.workItemsQuery.copyWith(pageRequest: request),
        isRefreshingWorkItems: true,
        clearLastFailure: true,
      ),
    );
    return _refreshWorkItems(showLoading: true);
  }

  Future<AppFailure?> createStaffProfile(Map<String, Object?> payload) async {
    final HrWorkspaceState? current = _currentState;
    if (current == null) {
      return AppFailure.validation();
    }

    _emit(current.copyWith(isMutating: true, clearLastFailure: true));
    final Result<HrStaffProfile> result = await _repository.createStaffProfile(
      payload,
    );
    return result.when(
      success: (HrStaffProfile profile) async {
        final HrWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              staff: _replaceStaff(latest.staff, profile),
              selectedStaff: HrStaffDetail(profile: profile),
              isMutating: false,
            ),
          );
        }
        unawaited(_refreshOverview());
        unawaited(_refreshReferences());
        return null;
      },
      failure: (AppFailure failure) {
        final HrWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(isMutating: false, lastFailure: failure));
        }
        return failure;
      },
    );
  }

  Future<AppFailure?> updateSelectedStaffProfile(
    Map<String, Object?> payload,
  ) async {
    final HrWorkspaceState? current = _currentState;
    final HrStaffDetail? selected = current?.selectedStaff;
    if (current == null || selected == null) {
      return AppFailure.validation();
    }

    _emit(current.copyWith(isMutating: true, clearLastFailure: true));
    final Result<HrStaffProfile> result = await _repository.updateStaffProfile(
      selected.profile.effectiveId,
      payload,
    );
    return result.when(
      success: (HrStaffProfile profile) async {
        final HrWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              staff: _replaceStaff(latest.staff, profile),
              selectedStaff: selected.copyWith(profile: profile),
              isMutating: false,
            ),
          );
        }
        unawaited(_refreshSelectedDetail(profile));
        unawaited(_refreshReferences());
        return null;
      },
      failure: (AppFailure failure) {
        final HrWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(isMutating: false, lastFailure: failure));
        }
        return failure;
      },
    );
  }

  Future<AppFailure?> createAssignment(Map<String, Object?> payload) {
    return _mutateSelected(
      (HrStaffDetail selected) =>
          _repository.createStaffAssignment(<String, Object?>{
            'staff_profile_id': selected.profile.effectiveId,
            ...payload,
          }),
      refreshReferencesAfter: true,
    );
  }

  Future<AppFailure?> createAvailability(Map<String, Object?> payload) {
    return _mutateSelected(
      (HrStaffDetail selected) =>
          _repository.createStaffAvailability(<String, Object?>{
            'staff_profile_id': selected.profile.effectiveId,
            ...payload,
          }),
    );
  }

  Future<AppFailure?> createLeave(Map<String, Object?> payload) {
    return _mutateSelected(
      (HrStaffDetail selected) =>
          _repository.createStaffLeave(<String, Object?>{
            'staff_profile_id': selected.profile.effectiveId,
            'status': 'REQUESTED',
            ...payload,
          }),
      refreshOverviewAfter: true,
      refreshWorkItemsAfter: true,
    );
  }

  Future<AppFailure?> createShiftAssignment(Map<String, Object?> payload) {
    return _mutateSelected(
      (HrStaffDetail selected) =>
          _repository.createShiftAssignment(<String, Object?>{
            'staff_profile_id': selected.profile.effectiveId,
            ...payload,
          }),
      refreshOverviewAfter: true,
      refreshWorkItemsAfter: true,
    );
  }

  Future<AppFailure?> createShiftSwapRequest(Map<String, Object?> payload) {
    return _mutateSelected(
      (HrStaffDetail selected) =>
          _repository.createShiftSwapRequest(<String, Object?>{
            'requester_staff_id': selected.profile.effectiveId,
            'status': 'SCHEDULED',
            ...payload,
          }),
      refreshOverviewAfter: true,
      refreshWorkItemsAfter: true,
    );
  }

  Future<AppFailure?> createPayrollRun(Map<String, Object?> payload) async {
    final HrWorkspaceState? current = _currentState;
    if (current == null) {
      return AppFailure.validation();
    }
    _emit(current.copyWith(isMutating: true, clearLastFailure: true));
    final Result<Object?> result = await _repository.createPayrollRun(payload);
    return _finishGenericMutation(
      result,
      refreshOverviewAfter: true,
      refreshWorkItemsAfter: true,
      refreshReferencesAfter: true,
    );
  }

  Future<AppFailure?> approveLeave(HrWorkItem item, {String? reason}) {
    return _mutateWorkItem(
      _repository.approveLeave(item.effectiveId, reason: reason),
    );
  }

  Future<AppFailure?> rejectLeave(HrWorkItem item, {required String reason}) {
    return _mutateWorkItem(
      _repository.rejectLeave(item.effectiveId, reason: reason),
    );
  }

  Future<AppFailure?> approveSwap(HrWorkItem item, {String? reason}) {
    return _mutateWorkItem(
      _repository.approveSwap(item.effectiveId, reason: reason),
    );
  }

  Future<AppFailure?> rejectSwap(HrWorkItem item, {required String reason}) {
    return _mutateWorkItem(
      _repository.rejectSwap(item.effectiveId, reason: reason),
    );
  }

  Future<AppFailure?> publishRoster(
    HrWorkItem item, {
    bool notifyStaff = true,
    bool allowPartialPublish = false,
    String? publishNote,
  }) {
    return _mutateWorkItem(
      _repository.publishRoster(
        item.effectiveId,
        notifyStaff: notifyStaff,
        allowPartialPublish: allowPartialPublish,
        publishNote: publishNote,
      ),
      refreshReferencesAfter: true,
    );
  }

  Future<AppFailure?> generateRoster(HrWorkItem item, {bool dryRun = false}) {
    return _mutateWorkItem(
      _repository.generateRoster(item.effectiveId, dryRun: dryRun),
    );
  }

  Future<AppFailure?> overrideShift(
    HrWorkItem item, {
    required String staffProfileId,
    required String reason,
  }) {
    return _mutateWorkItem(
      _repository.overrideShift(
        item.effectiveId,
        staffProfileId: staffProfileId,
        reason: reason,
      ),
    );
  }

  Future<AppFailure?> processPayrollRun(
    HrWorkItem item, {
    bool replaceExistingItems = false,
    String? notes,
  }) {
    return _mutateWorkItem(
      _repository.processPayrollRun(
        item.effectiveId,
        replaceExistingItems: replaceExistingItems,
        notes: notes,
      ),
      refreshReferencesAfter: true,
    );
  }

  Future<Result<HrWorkspaceState>> _loadInitialState() async {
    const HrStaffQuery staffQuery = HrStaffQuery();
    const HrWorkItemsQuery workItemsQuery = HrWorkItemsQuery();

    final Result<HrWorkspaceOverview> overviewResult = await _repository
        .loadOverview();
    final HrWorkspaceOverview? overview = _successOrNull(overviewResult);
    if (overview == null) {
      return Result<HrWorkspaceState>.failure(_failureOrNull(overviewResult)!);
    }

    final Result<AppPage<HrStaffProfile>> staffResult = await _repository
        .listStaffProfiles(staffQuery);
    final AppPage<HrStaffProfile>? staff = _successOrNull(staffResult);
    if (staff == null) {
      return Result<HrWorkspaceState>.failure(_failureOrNull(staffResult)!);
    }

    final HrReferenceData referenceData = await _loadReferenceDataOrEmpty();
    final AppPage<HrWorkItem> workItems = await _loadWorkItemsOrEmpty(
      workItemsQuery,
    );
    final HrStaffDetail? selectedStaff = staff.items.isEmpty
        ? null
        : await _loadDetailOrNull(staff.items.first);

    return Result<HrWorkspaceState>.success(
      HrWorkspaceState(
        overview: overview,
        staffQuery: staffQuery,
        staff: staff,
        workItemsQuery: workItemsQuery,
        workItems: workItems,
        referenceData: referenceData,
        selectedStaff: selectedStaff,
      ),
    );
  }

  void _startSync() {
    _syncTimer ??= Timer.periodic(_syncInterval, (_) {
      unawaited(_syncVisibleData());
    });
  }

  Future<AppFailure?> _syncVisibleData({
    bool showLoading = false,
    bool refreshReferences = false,
  }) async {
    final HrWorkspaceState? current = _currentState;
    if (current == null || _isSyncing || current.isMutating) {
      return null;
    }

    _isSyncing = true;
    if (showLoading) {
      _emit(
        current.copyWith(
          isRefreshing: true,
          isRefreshingStaff: true,
          isRefreshingWorkItems: true,
          isRefreshingDetail: current.selectedStaff != null,
          clearLastFailure: true,
        ),
      );
    }

    try {
      final AppFailure? overviewFailure = await _refreshOverview();
      final AppFailure? staffFailure = await _refreshStaff(
        showLoading: showLoading,
      );
      final AppFailure? workItemsFailure = await _refreshWorkItems(
        showLoading: showLoading,
      );
      AppFailure? referencesFailure;
      if (refreshReferences) {
        referencesFailure = await _refreshReferences();
      }

      final HrStaffDetail? selected = _currentState?.selectedStaff;
      if (selected != null) {
        await _refreshSelectedDetail(selected.profile);
      }

      return overviewFailure ??
          staffFailure ??
          workItemsFailure ??
          referencesFailure;
    } finally {
      final HrWorkspaceState? latest = _currentState;
      if (showLoading && latest != null) {
        _emit(
          latest.copyWith(
            isRefreshing: false,
            isRefreshingStaff: false,
            isRefreshingWorkItems: false,
            isRefreshingDetail: false,
          ),
        );
      }
      _isSyncing = false;
    }
  }

  Future<AppFailure?> _refreshOverview() async {
    final Result<HrWorkspaceOverview> result = await _repository.loadOverview();
    return result.when(
      success: (HrWorkspaceOverview overview) {
        final HrWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(overview: overview, clearLastFailure: true));
        }
        return null;
      },
      failure: (AppFailure failure) {
        final HrWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(lastFailure: failure));
        }
        return failure;
      },
    );
  }

  Future<AppFailure?> _refreshReferences() async {
    final HrWorkspaceState? current = _currentState;
    final String? departmentId = current?.staffQuery.departmentId;
    final Result<HrReferenceData> result = await _repository.loadReferenceData(
      departmentId: departmentId,
    );
    return result.when(
      success: (HrReferenceData referenceData) {
        final HrWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              referenceData: referenceData,
              clearLastFailure: true,
            ),
          );
        }
        return null;
      },
      failure: (AppFailure failure) {
        final HrWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(lastFailure: failure));
        }
        return failure;
      },
    );
  }

  Future<AppFailure?> _refreshStaff({required bool showLoading}) async {
    final HrWorkspaceState? current = _currentState;
    if (current == null) {
      return null;
    }

    final Result<AppPage<HrStaffProfile>> result = await _repository
        .listStaffProfiles(current.staffQuery);
    return result.when(
      success: (AppPage<HrStaffProfile> page) {
        final HrWorkspaceState? latest = _currentState;
        if (latest != null) {
          final HrStaffDetail? selected = _selectedAfterStaffRefresh(
            page,
            latest.selectedStaff,
          );
          _emit(
            latest.copyWith(
              staff: page,
              selectedStaff: selected,
              clearSelectedStaff:
                  latest.selectedStaff != null && selected == null,
              isRefreshingStaff: false,
              clearLastFailure: true,
            ),
          );
        }
        return null;
      },
      failure: (AppFailure failure) {
        final HrWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(isRefreshingStaff: false, lastFailure: failure),
          );
        }
        return failure;
      },
    );
  }

  Future<AppFailure?> _refreshWorkItems({required bool showLoading}) async {
    final HrWorkspaceState? current = _currentState;
    if (current == null) {
      return null;
    }

    final Result<AppPage<HrWorkItem>> result = await _repository.listWorkItems(
      current.workItemsQuery,
    );
    return result.when(
      success: (AppPage<HrWorkItem> page) {
        final HrWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              workItems: page,
              isRefreshingWorkItems: false,
              clearLastFailure: true,
            ),
          );
        }
        return null;
      },
      failure: (AppFailure failure) {
        final HrWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(isRefreshingWorkItems: false, lastFailure: failure),
          );
        }
        return failure;
      },
    );
  }

  Future<AppFailure?> _refreshSelectedDetail(HrStaffProfile profile) async {
    final Result<HrStaffDetail> result = await _repository.loadStaffDetail(
      profile,
    );
    return result.when(
      success: (HrStaffDetail detail) {
        final HrWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              selectedStaff: detail,
              staff: _replaceStaff(latest.staff, detail.profile),
              isRefreshingDetail: false,
              clearLastFailure: true,
            ),
          );
        }
        return null;
      },
      failure: (AppFailure failure) {
        final HrWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(isRefreshingDetail: false, lastFailure: failure),
          );
        }
        return failure;
      },
    );
  }

  Future<AppFailure?> _mutateSelected(
    Future<Result<Object?>> Function(HrStaffDetail selected) action, {
    bool refreshOverviewAfter = false,
    bool refreshWorkItemsAfter = false,
    bool refreshReferencesAfter = false,
  }) async {
    final HrWorkspaceState? current = _currentState;
    final HrStaffDetail? selected = current?.selectedStaff;
    if (current == null || selected == null) {
      return AppFailure.validation();
    }

    _emit(current.copyWith(isMutating: true, clearLastFailure: true));
    final Result<Object?> result = await action(selected);
    final AppFailure? failure = await _finishGenericMutation(
      result,
      refreshOverviewAfter: refreshOverviewAfter,
      refreshWorkItemsAfter: refreshWorkItemsAfter,
      refreshReferencesAfter: refreshReferencesAfter,
    );
    if (failure == null) {
      unawaited(_refreshSelectedDetail(selected.profile));
    }
    return failure;
  }

  Future<AppFailure?> _mutateWorkItem(
    Future<Result<Object?>> mutation, {
    bool refreshReferencesAfter = false,
  }) async {
    final HrWorkspaceState? current = _currentState;
    if (current == null) {
      return AppFailure.validation();
    }

    _emit(current.copyWith(isMutating: true, clearLastFailure: true));
    return _finishGenericMutation(
      await mutation,
      refreshOverviewAfter: true,
      refreshWorkItemsAfter: true,
      refreshReferencesAfter: refreshReferencesAfter,
    );
  }

  Future<AppFailure?> _finishGenericMutation(
    Result<Object?> result, {
    bool refreshOverviewAfter = false,
    bool refreshWorkItemsAfter = false,
    bool refreshReferencesAfter = false,
  }) async {
    return result.when(
      success: (_) async {
        final HrWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(isMutating: false, clearLastFailure: true));
        }
        if (refreshOverviewAfter) {
          unawaited(_refreshOverview());
        }
        if (refreshWorkItemsAfter) {
          unawaited(_refreshWorkItems(showLoading: false));
        }
        if (refreshReferencesAfter) {
          unawaited(_refreshReferences());
        }
        return null;
      },
      failure: (AppFailure failure) {
        final HrWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(isMutating: false, lastFailure: failure));
        }
        return failure;
      },
    );
  }

  Future<HrReferenceData> _loadReferenceDataOrEmpty() async {
    final Result<HrReferenceData> result = await _repository
        .loadReferenceData();
    return result.when(
      success: (HrReferenceData value) => value,
      failure: (_) => const HrReferenceData(),
    );
  }

  Future<AppPage<HrWorkItem>> _loadWorkItemsOrEmpty(
    HrWorkItemsQuery query,
  ) async {
    final Result<AppPage<HrWorkItem>> result = await _repository.listWorkItems(
      query,
    );
    return result.when(
      success: (AppPage<HrWorkItem> value) => value,
      failure: (_) => AppPage<HrWorkItem>(
        items: const <HrWorkItem>[],
        request: query.pageRequest,
        totalItemCount: 0,
      ),
    );
  }

  Future<HrStaffDetail?> _loadDetailOrNull(HrStaffProfile profile) async {
    final Result<HrStaffDetail> result = await _repository.loadStaffDetail(
      profile,
    );
    return result.when(
      success: (HrStaffDetail detail) => detail,
      failure: (_) => null,
    );
  }

  HrStaffDetail? _selectedAfterStaffRefresh(
    AppPage<HrStaffProfile> page,
    HrStaffDetail? selected,
  ) {
    if (selected == null) {
      return null;
    }
    for (final HrStaffProfile item in page.items) {
      if (_isSameStaff(item, selected.profile)) {
        return selected.copyWith(
          profile: selected.profile.copyWith(
            displayId: item.displayId,
            staffNumber: item.staffNumber,
            position: item.position,
            practitionerType: item.practitionerType,
            departmentId: item.departmentId,
            departmentDisplayId: item.departmentDisplayId,
            departmentName: item.departmentName,
            updatedAt: item.updatedAt,
          ),
        );
      }
    }
    return selected;
  }

  AppPage<HrStaffProfile> _replaceStaff(
    AppPage<HrStaffProfile> page,
    HrStaffProfile replacement,
  ) {
    var replaced = false;
    final List<HrStaffProfile> items = <HrStaffProfile>[];
    for (final HrStaffProfile item in page.items) {
      if (_isSameStaff(item, replacement)) {
        if (!replaced) {
          items.add(replacement);
          replaced = true;
        }
      } else {
        items.add(item);
      }
    }

    if (!replaced) {
      items.insert(0, replacement);
    }

    return AppPage<HrStaffProfile>(
      items: items.take(page.request.pageSize).toList(growable: false),
      request: page.request,
      totalItemCount: page.totalItemCount == null || replaced
          ? page.totalItemCount
          : page.totalItemCount! + 1,
    );
  }

  bool _isSameStaff(HrStaffProfile left, HrStaffProfile right) {
    return left.id == right.id ||
        (left.displayId != null && left.displayId == right.displayId) ||
        (left.staffNumber != null && left.staffNumber == right.staffNumber);
  }

  T? _successOrNull<T>(Result<T> result) {
    return result.when(success: (T value) => value, failure: (_) => null);
  }

  AppFailure? _failureOrNull<T>(Result<T> result) {
    return result.when(
      success: (_) => null,
      failure: (AppFailure failure) => failure,
    );
  }

  HrWorkspaceState? get _currentState {
    final Result<HrWorkspaceState>? currentResult = state.asData?.value;
    return switch (currentResult) {
      ResultSuccess<HrWorkspaceState>(value: final value) => value,
      _ => null,
    };
  }

  void _emit(HrWorkspaceState nextState) {
    state = AsyncData<Result<HrWorkspaceState>>(
      Result<HrWorkspaceState>.success(nextState),
    );
  }
}
