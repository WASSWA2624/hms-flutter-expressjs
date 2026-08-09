import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/realtime/realtime_message.dart';
import 'package:hosspi_hms/core/realtime/realtime_refresh.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_isolation.dart';
import 'package:hosspi_hms/core/workspace/workspace_adaptive_polling.dart';
import 'package:hosspi_hms/core/workspace/workspace_event_refresh_plan.dart';
import 'package:hosspi_hms/core/workspace/workspace_fast_sync.dart';
import 'package:hosspi_hms/core/workspace/workspace_session_guard.dart';
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

  final WorkspaceAdaptivePolling _adaptivePolling = WorkspaceAdaptivePolling();
  final WorkspacePendingRefresh _pendingRefresh = WorkspacePendingRefresh();
  bool _isSyncing = false;

  @override
  Future<Result<HrWorkspaceState>> build() async {
    watchSessionEpoch(ref);
    listenForRealtimeRefresh(
      ref: ref,
      events: RealtimeEventGroups.hr,
      includeCrudMutations: true,
      shouldDefer: () => _isSyncing || (_currentState?.isMutating ?? false),
      onRefresh: _syncFromRealtime,
    );
    final Result<HrWorkspaceState> result = await runWorkspaceInitialLoad(
      ref,
      _loadInitialState,
    );
    _startAdaptivePolling();
    return result;
  }

  Future<void> _syncFromRealtime(RealtimeMessage message) async {
    if (_isSyncing || (_currentState?.isMutating ?? false)) {
      _pendingRefresh.defer(
        WorkspaceEventRefreshPlan.forMessage(
          message,
          profile: WorkspaceRefreshProfile.hr,
        ),
      );
      return;
    }
    final WorkspaceRefreshPlan plan = WorkspaceEventRefreshPlan.forMessage(
      message,
      profile: WorkspaceRefreshProfile.hr,
    );
    if (plan.isEmpty) {
      return;
    }
    await _syncVisibleData(plan: plan);
  }

  Future<AppFailure?> refresh() {
    return _syncVisibleData(showLoading: true, refreshReferences: true);
  }

  /// Loads facility-scoped reference data when onboarding dropdowns are empty.
  Future<void> ensureOnboardingReferenceData({String? facilityId}) async {
    final HrWorkspaceState? current = _currentState;
    if (current != null &&
        hasHrOnboardingReferenceData(current.referenceData)) {
      return;
    }
    await _refreshReferences(facilityId: facilityId, forOnboarding: true);
  }

  /// Refreshes facility departments, units, and rooms before assignment dialogs.
  Future<void> ensureAssignmentReferenceData() async {
    await _refreshReferences(forOnboarding: true);
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

  Future<AppFailure?> applyWorkItemsSearch(String value) async {
    final HrWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        workItemsQuery: current.workItemsQuery.copyWith(
          search: value.trim(),
          pageRequest: current.workItemsQuery.pageRequest.first(),
        ),
        isRefreshingWorkItems: true,
        clearLastFailure: true,
      ),
    );
    return _refreshWorkItems(showLoading: true);
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

  /// Resolve a staff profile by its display id (or uuid) and load its detail.
  ///
  /// Used by `/hr?id=` deep links where only an identifier is known. Reuses an
  /// already-loaded row when possible, otherwise loads detail directly.
  Future<AppFailure?> selectStaffByDisplayId(String identifier) async {
    final String target = identifier.trim();
    if (target.isEmpty) {
      return AppFailure.validation();
    }

    final HrWorkspaceState? current = _currentState;
    if (current == null) {
      final AppFailure? failure = await refresh();
      if (failure != null) {
        return failure;
      }
    }

    final HrWorkspaceState? state = _currentState;
    if (state == null) {
      return AppFailure.validation();
    }

    for (final HrStaffProfile profile in state.staff.items) {
      if (profile.id == target ||
          profile.displayId == target ||
          profile.staffNumber == target) {
        return selectStaff(profile);
      }
    }

    return selectStaff(HrStaffProfile(id: target, displayId: target));
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
          clearFrom: true,
          clearTo: true,
          pageRequest: current.workItemsQuery.pageRequest.first(),
        ),
        isRefreshingWorkItems: true,
        clearLastFailure: true,
      ),
    );
    return _refreshWorkItems(showLoading: true);
  }

  Future<AppFailure?> applyWorkItemsScope({
    required HrQueue queue,
    String? status,
    DateTime? from,
    DateTime? to,
  }) async {
    final HrWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        workItemsQuery: current.workItemsQuery.copyWith(
          queue: queue,
          status: status,
          from: from,
          to: to,
          clearStatus: status == null,
          clearFrom: from == null,
          clearTo: to == null,
          pageRequest: current.workItemsQuery.pageRequest.first(),
        ),
        isRefreshingWorkItems: true,
        clearLastFailure: true,
      ),
    );
    return _refreshWorkItems(showLoading: true);
  }

  static DateTime startOfLocalDay([DateTime? reference]) {
    final DateTime now = (reference ?? DateTime.now()).toLocal();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime endOfLocalDay([DateTime? reference]) {
    final DateTime start = startOfLocalDay(reference);
    return start
        .add(const Duration(days: 1))
        .subtract(const Duration(microseconds: 1));
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

  Future<AppFailure?> createAssignment(Map<String, Object?> payload) async {
    final AppFailure? failure = await _mutateSelected(
      (HrStaffDetail selected) =>
          _repository.createStaffAssignment(<String, Object?>{
            'staff_profile_id': selected.profile.effectiveId,
            ...payload,
          }),
      refreshReferencesAfter: true,
    );
    if (failure == null) {
      unawaited(_refreshStaff(showLoading: false));
    }
    return failure;
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

  Future<AppFailure?> createAvailabilitySchedule(
    Map<String, Object?> batchPayload,
  ) {
    final Object? days = batchPayload['days'];
    if (days is! List || days.isEmpty) {
      return Future<AppFailure?>.value(AppFailure.validation());
    }
    return _mutateSelected(
      (HrStaffDetail selected) =>
          _repository.createStaffAvailabilityBatch(<String, Object?>{
            'staff_profile_id': selected.profile.effectiveId,
            ...batchPayload,
          }),
    );
  }

  Future<Result<List<HrStaffAvailability>>> loadStaffAvailabilities(
    String staffProfileId,
  ) {
    return _repository.listStaffAvailabilities(staffProfileId);
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

  Future<AppFailure?> assignUserRole({
    required String roleId,
    String? facilityId,
  }) {
    final HrStaffDetail? selected = _currentState?.selectedStaff;
    final HrStaffProfile? profile = selected?.profile;
    if (profile == null || (profile.userId ?? '').trim().isEmpty) {
      return Future<AppFailure?>.value(AppFailure.validation());
    }
    return _mutateSelected(
      (_) => _repository.assignUserRole(
        userId: profile.userId!,
        roleId: roleId,
        tenantId: profile.tenantId ?? '',
        facilityId: facilityId,
      ),
    );
  }

  Future<AppFailure?> revokeUserRole(HrUserRole userRole) async {
    final HrWorkspaceState? current = _currentState;
    if (current == null) {
      return AppFailure.validation();
    }

    // Access tab revoke has no selected staff; staff-detail revoke refreshes
    // the open profile after success.
    final HrStaffDetail? selected = current.selectedStaff;
    _emit(current.copyWith(isMutating: true, clearLastFailure: true));
    final AppFailure? failure = await _finishGenericMutation(
      await _repository.revokeUserRole(
        userRole.backendIdentifier ?? userRole.effectiveId,
      ),
      refreshReferencesAfter: true,
    );
    if (failure == null && selected != null) {
      unawaited(_refreshSelectedDetail(selected.profile));
    }
    return failure;
  }

  Future<Result<AppPage<HrAccessUser>>> loadAccessUsers(HrAccessQuery query) {
    return _repository.listAccessUsers(query);
  }

  Future<Result<AppPage<HrAccessRole>>> loadAccessRoles(HrAccessQuery query) {
    return _repository.listAccessRoles(query);
  }

  Future<Result<AppPage<HrAccessPermission>>> loadAccessPermissions(
    HrAccessQuery query,
  ) {
    return _repository.listAccessPermissions(query);
  }

  Future<Result<List<HrAccessPermission>>> loadAllAccessPermissions(
    HrAccessQuery query,
  ) {
    return _repository.listAllAccessPermissions(query);
  }

  Future<AppFailure?> updateAccessUser(
    String userId,
    Map<String, Object?> payload, {
    bool refreshReferences = true,
  }) async {
    final HrWorkspaceState? current = _currentState;
    if (current == null) {
      return AppFailure.validation();
    }
    _emit(current.copyWith(isMutating: true, clearLastFailure: true));
    return _finishGenericMutation(
      await _repository.updateUserAccount(userId, payload),
      refreshReferencesAfter: refreshReferences,
    );
  }

  Future<AppFailure?> createAccessRole(Map<String, Object?> payload) async {
    final HrWorkspaceState? current = _currentState;
    if (current == null) {
      return AppFailure.validation();
    }
    _emit(current.copyWith(isMutating: true, clearLastFailure: true));
    return _finishGenericMutation(
      await _repository.createRole(payload),
      refreshReferencesAfter: true,
    );
  }

  Future<AppFailure?> updateAccessRole(
    String roleId,
    Map<String, Object?> payload,
  ) async {
    final HrWorkspaceState? current = _currentState;
    if (current == null) {
      return AppFailure.validation();
    }
    _emit(current.copyWith(isMutating: true, clearLastFailure: true));
    return _finishGenericMutation(
      await _repository.updateRole(roleId, payload),
      refreshReferencesAfter: true,
    );
  }

  Future<AppFailure?> deleteAccessRole(String roleId) async {
    final HrWorkspaceState? current = _currentState;
    if (current == null) {
      return AppFailure.validation();
    }
    _emit(current.copyWith(isMutating: true, clearLastFailure: true));
    return _finishGenericMutation(
      await _repository.deleteRole(roleId),
      refreshReferencesAfter: true,
    );
  }

  Future<AppFailure?> createAccessPermission(
    Map<String, Object?> payload,
  ) async {
    final HrWorkspaceState? current = _currentState;
    if (current == null) {
      return AppFailure.validation();
    }
    _emit(current.copyWith(isMutating: true, clearLastFailure: true));
    return _finishGenericMutation(
      await _repository.createPermission(payload),
      refreshReferencesAfter: true,
    );
  }

  Future<AppFailure?> updateAccessPermission(
    String permissionId,
    Map<String, Object?> payload,
  ) async {
    final HrWorkspaceState? current = _currentState;
    if (current == null) {
      return AppFailure.validation();
    }
    _emit(current.copyWith(isMutating: true, clearLastFailure: true));
    return _finishGenericMutation(
      await _repository.updatePermission(permissionId, payload),
      refreshReferencesAfter: true,
    );
  }

  Future<AppFailure?> deleteAccessPermission(String permissionId) async {
    final HrWorkspaceState? current = _currentState;
    if (current == null) {
      return AppFailure.validation();
    }
    _emit(current.copyWith(isMutating: true, clearLastFailure: true));
    return _finishGenericMutation(
      await _repository.deletePermission(permissionId),
      refreshReferencesAfter: true,
    );
  }

  Future<AppFailure?> assignRolePermissionsBatch({
    required String roleId,
    required List<String> permissionIds,
  }) {
    return syncRolePermissions(roleId: roleId, permissionIds: permissionIds);
  }

  Future<Result<HrAccessUserDetail>> loadAccessUserDetail(
    String userId, {
    String? tenantId,
  }) async {
    final Result<HrAccessUserDetail> detailResult = await _repository
        .loadAccessUserDetail(userId);
    return detailResult.when(
      success: (HrAccessUserDetail detail) async {
        final Result<List<HrUserRole>> rolesResult = await _repository
            .listUserRoles(userId: userId, tenantId: tenantId);
        return rolesResult.when(
          success: (List<HrUserRole> userRoles) {
            final List<String> effectiveLabels =
                detail.effectivePermissionLabels.isNotEmpty
                ? detail.effectivePermissionLabels
                : <String>[
                    ...userRoles
                        .map((HrUserRole role) => role.roleName)
                        .whereType<String>(),
                    ...detail.directPermissions
                        .map((HrAccessPermission permission) => permission.name)
                        .whereType<String>(),
                  ];
            return Result<HrAccessUserDetail>.success(
              HrAccessUserDetail(
                id: detail.id,
                displayId: detail.displayId,
                email: detail.email,
                phone: detail.phone,
                positionTitle: detail.positionTitle,
                status: detail.status,
                profileName: detail.profileName,
                staffProfileId: detail.staffProfileId,
                staffProfileName: detail.staffProfileName,
                userRoles: userRoles,
                directPermissions: detail.directPermissions,
                effectivePermissionLabels: effectiveLabels.toSet().toList()
                  ..sort(),
              ),
            );
          },
          failure: (AppFailure failure) {
            return Result<HrAccessUserDetail>.failure(failure);
          },
        );
      },
      failure: (AppFailure failure) {
        return Result<HrAccessUserDetail>.failure(failure);
      },
    );
  }

  Future<Result<AppPage<HrOption>>> listRolePermissionOptions(String roleId) {
    return _repository.listRolePermissions(roleId);
  }

  Future<AppFailure?> syncUserRoles({
    required String userId,
    required String tenantId,
    required List<String> roleIds,
    String? facilityId,
  }) async {
    final Result<List<HrUserRole>> currentResult = await _repository
        .listUserRoles(userId: userId, tenantId: tenantId);
    final List<HrUserRole> currentRoles = currentResult.when(
      success: (List<HrUserRole> value) => value,
      failure: (_) => const <HrUserRole>[],
    );
    final Set<String> desiredRoleIds = roleIds.toSet();
    final Set<String> currentRoleIds = currentRoles
        .map((HrUserRole role) => role.roleId)
        .whereType<String>()
        .toSet();

    AppFailure? lastFailure;
    for (final HrUserRole assignment in currentRoles) {
      final String? roleId = assignment.roleId;
      if (roleId == null || desiredRoleIds.contains(roleId)) {
        continue;
      }
      final Result<void> result = await _repository.revokeUserRole(
        assignment.backendIdentifier ?? assignment.effectiveId,
      );
      lastFailure ??= _failureOrNull(result);
    }

    for (final String roleId in desiredRoleIds) {
      if (currentRoleIds.contains(roleId)) {
        continue;
      }
      final Result<void> result = await _repository.assignUserRole(
        userId: userId,
        roleId: roleId,
        tenantId: tenantId,
        facilityId: facilityId,
      );
      lastFailure ??= _failureOrNull(result);
    }

    unawaited(_refreshReferences());
    return lastFailure;
  }

  Future<AppFailure?> syncRolePermissions({
    required String roleId,
    required List<String> permissionIds,
  }) async {
    final Result<AppPage<HrOption>> currentResult = await _repository
        .listRolePermissions(roleId);
    final List<HrOption> currentAssignments = currentResult.when(
      success: (AppPage<HrOption> page) => page.items,
      failure: (_) => const <HrOption>[],
    );
    final Set<String> desiredPermissionIds = permissionIds.toSet();
    final Set<String> currentPermissionIds = currentAssignments
        .map((HrOption option) => option.value)
        .toSet();

    AppFailure? lastFailure;
    for (final HrOption assignment in currentAssignments) {
      if (desiredPermissionIds.contains(assignment.value)) {
        continue;
      }
      final String? assignmentId = assignment.displayId;
      if (assignmentId == null || assignmentId.isEmpty) {
        continue;
      }
      final Result<void> result = await _repository.revokeRolePermission(
        assignmentId,
      );
      lastFailure ??= _failureOrNull(result);
    }

    for (final String permissionId in desiredPermissionIds) {
      if (currentPermissionIds.contains(permissionId)) {
        continue;
      }
      final Result<void> result = await _repository.assignRolePermission(
        roleId: roleId,
        permissionId: permissionId,
      );
      lastFailure ??= _failureOrNull(result);
    }

    unawaited(_refreshReferences());
    return lastFailure;
  }

  Future<AppFailure?> assignUserRolesBatch({
    required String userId,
    required String tenantId,
    required List<String> roleIds,
    String? facilityId,
  }) async {
    AppFailure? lastFailure;
    for (final String roleId in roleIds) {
      final Result<void> result = await _repository.assignUserRole(
        userId: userId,
        roleId: roleId,
        tenantId: tenantId,
        facilityId: facilityId,
      );
      lastFailure ??= _failureOrNull(result);
    }
    unawaited(_refreshReferences());
    return lastFailure;
  }

  Future<AppFailure?> createUserAndLinkStaff(Map<String, Object?> payload) {
    return onboardStaff(payload);
  }

  /// Coordinated staff onboarding: user create/link, profile, roles, compensation.
  Future<AppFailure?> onboardStaff(Map<String, Object?> payload) async {
    final HrWorkspaceState? current = _currentState;
    if (current == null) {
      return AppFailure.validation();
    }

    final bool isEdit = payload['_edit'] == true;
    final String? tenantId = payload['tenant_id']?.toString();
    final String? facilityId = payload['facility_id']?.toString();
    final List<String> roleIds =
        (payload['_role_ids'] as List<Object?>?)
            ?.map((Object? id) => id.toString())
            .where((String id) => id.isNotEmpty)
            .toList(growable: false) ??
        const <String>[];

    _emit(current.copyWith(isMutating: true, clearLastFailure: true));

    String? userId = payload['user_id']?.toString();
    if (!isEdit) {
      final Result<Object?> userResult = await _repository
          .createUserAccount(<String, Object?>{
            'tenant_id': tenantId,
            'facility_id': facilityId,
            'email': payload['email'],
            'password': payload['password'],
            'phone': payload['phone'],
            'position_title': payload['position_title'],
            'status': payload['status'] ?? 'ACTIVE',
          });
      final AppFailure? userFailure = userResult.when(
        success: (_) => null,
        failure: (AppFailure failure) => failure,
      );
      if (userFailure != null) {
        final HrWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(isMutating: false, lastFailure: userFailure));
        }
        return userFailure;
      }
      userId = _extractCreatedUserId(userResult);

      final String? firstName = payload['_first_name']?.toString().trim();
      if (userId != null && firstName != null && firstName.isNotEmpty) {
        final Result<Object?> profileResult = await _repository
            .createUserProfile(<String, Object?>{
              'user_id': userId,
              'facility_id': facilityId,
              'first_name': firstName,
              'last_name': payload['_last_name'],
            });
        final AppFailure? profileFailure = profileResult.when(
          success: (_) => null,
          failure: (AppFailure failure) => failure,
        );
        if (profileFailure != null) {
          final HrWorkspaceState? latest = _currentState;
          if (latest != null) {
            _emit(
              latest.copyWith(isMutating: false, lastFailure: profileFailure),
            );
          }
          return profileFailure;
        }
      }
    }

    final Map<String, Object?> staffPayload = <String, Object?>{
      if (!isEdit) 'tenant_id': tenantId,
      if (!isEdit && userId != null) 'user_id': userId,
      if (payload['generate_staff_number'] == true)
        'generate_staff_number': true,
      'staff_number': payload['staff_number'],
      'position': payload['position'],
      'department_id': payload['department_id'],
      'facility_id': facilityId,
      'practitioner_type': payload['practitioner_type'],
      'hire_date': payload['hire_date'],
      'consultation_fee': payload['consultation_fee'],
      'consultation_currency': payload['consultation_currency'],
      'compensations': payload['compensations'],
    };

    final Result<HrStaffProfile> staffResult = isEdit
        ? await _repository.updateStaffProfile(
            payload['_staff_profile_id']?.toString() ?? '',
            staffPayload,
          )
        : await _repository.createStaffProfile(staffPayload);

    final AppFailure? staffFailure = staffResult.when(
      success: (_) => null,
      failure: (AppFailure failure) => failure,
    );
    if (staffFailure != null) {
      final HrWorkspaceState? latest = _currentState;
      if (latest != null) {
        _emit(latest.copyWith(isMutating: false, lastFailure: staffFailure));
      }
      return staffFailure;
    }

    final HrStaffProfile profile = staffResult.when(
      success: (HrStaffProfile value) => value,
      failure: (_) => throw StateError('unreachable'),
    );
    final String? effectiveUserId = userId ?? profile.userId;
    AppFailure? roleFailure;
    if (!isEdit &&
        effectiveUserId != null &&
        tenantId != null &&
        roleIds.isNotEmpty) {
      roleFailure = await syncUserRoles(
        userId: effectiveUserId,
        tenantId: tenantId,
        roleIds: roleIds,
        facilityId: facilityId,
      );
    }

    final HrWorkspaceState? latest = _currentState;
    if (latest != null) {
      _emit(
        latest.copyWith(
          staff: _replaceStaff(latest.staff, profile),
          selectedStaff: HrStaffDetail(profile: profile),
          isMutating: false,
          lastFailure: roleFailure,
        ),
      );
    }
    if (!isEdit) {
      await _refreshSelectedDetail(profile);
      final HrWorkspaceState? refreshed = _currentState;
      if (refreshed != null) {
        _emit(
          refreshed.copyWith(
            isMutating: false,
            lastFailure: roleFailure,
            openStaffDetailAfterOnboarding: roleFailure == null,
          ),
        );
      }
    }
    unawaited(_refreshOverview());
    unawaited(_refreshReferences());
    return roleFailure;
  }

  void clearOpenStaffDetailAfterOnboarding() {
    final HrWorkspaceState? current = _currentState;
    if (current == null || !current.openStaffDetailAfterOnboarding) {
      return;
    }
    _emit(current.copyWith(clearOpenStaffDetailAfterOnboarding: true));
  }

  Future<AppFailure?> endAssignment(
    HrStaffAssignment assignment, {
    DateTime? endDate,
  }) async {
    final AppFailure? failure = await _mutateSelected(
      (_) => _repository.updateStaffAssignment(
        assignment.effectiveId,
        <String, Object?>{
          'end_date': (endDate ?? DateTime.now()).toIso8601String(),
        },
      ),
    );
    if (failure == null) {
      unawaited(_refreshStaff(showLoading: false));
    }
    return failure;
  }

  Future<AppFailure?> createShiftTemplate(Map<String, Object?> payload) async {
    final HrWorkspaceState? current = _currentState;
    if (current == null) {
      return AppFailure.validation();
    }
    _emit(current.copyWith(isMutating: true, clearLastFailure: true));
    return _finishGenericMutation(
      await _repository.createShiftTemplate(payload),
      refreshReferencesAfter: true,
    );
  }

  Future<AppFailure?> createRoster(Map<String, Object?> payload) async {
    final HrWorkspaceState? current = _currentState;
    if (current == null) {
      return AppFailure.validation();
    }
    _emit(current.copyWith(isMutating: true, clearLastFailure: true));
    return _finishGenericMutation(
      await _repository.createRoster(payload),
      refreshWorkItemsAfter: true,
      refreshReferencesAfter: true,
    );
  }

  Future<AppFailure?> updateRoster(
    String rosterId,
    Map<String, Object?> payload,
  ) async {
    final HrWorkspaceState? current = _currentState;
    if (current == null) {
      return AppFailure.validation();
    }
    _emit(current.copyWith(isMutating: true, clearLastFailure: true));
    return _finishGenericMutation(
      await _repository.updateRoster(rosterId, payload),
      refreshWorkItemsAfter: true,
      refreshReferencesAfter: true,
    );
  }

  Future<Result<Map<String, Object?>>> getRoster(String rosterId) {
    return _repository.getRoster(rosterId);
  }

  Future<Result<Map<String, Object?>>> attachRosterStaff({
    required String rosterId,
    required String staffProfileId,
    String? staffCategory,
  }) async {
    final Result<Map<String, Object?>> result = await _repository
        .attachRosterStaff(
          rosterId: rosterId,
          staffProfileId: staffProfileId,
          staffCategory: staffCategory,
        );
    result.when(
      success: (_) {
        unawaited(_refreshWorkItems(showLoading: false));
      },
      failure: (_) {},
    );
    return result;
  }

  Future<Result<Map<String, Object?>>> detachRosterStaff({
    required String rosterId,
    required String staffProfileId,
  }) async {
    final Result<Map<String, Object?>> result = await _repository
        .detachRosterStaff(rosterId: rosterId, staffProfileId: staffProfileId);
    result.when(
      success: (_) {
        unawaited(_refreshWorkItems(showLoading: false));
      },
      failure: (_) {},
    );
    return result;
  }

  Future<AppFailure?> updateShiftTemplate(
    String templateId,
    Map<String, Object?> payload,
  ) async {
    final HrWorkspaceState? current = _currentState;
    if (current == null) {
      return AppFailure.validation();
    }
    _emit(current.copyWith(isMutating: true, clearLastFailure: true));
    return _finishGenericMutation(
      await _repository.updateShiftTemplate(templateId, payload),
      refreshReferencesAfter: true,
    );
  }

  Future<AppFailure?> deleteShiftTemplate(String templateId) async {
    final HrWorkspaceState? current = _currentState;
    if (current == null) {
      return AppFailure.validation();
    }
    _emit(current.copyWith(isMutating: true, clearLastFailure: true));
    return _finishGenericMutation(
      await _repository.deleteShiftTemplate(templateId),
      refreshReferencesAfter: true,
    );
  }

  Future<Result<HrPayrollPreview>> previewPayrollRunById(
    String payrollRunId, {
    String? staffProfileId,
  }) {
    return _repository.previewPayrollRun(
      payrollRunId,
      staffProfileId: staffProfileId,
    );
  }

  Future<AppFailure?> processPayrollRunById(
    String payrollRunId, {
    bool replaceExistingItems = false,
  }) async {
    final HrWorkspaceState? current = _currentState;
    if (current == null) {
      return AppFailure.validation();
    }
    _emit(current.copyWith(isMutating: true, clearLastFailure: true));
    return _finishGenericMutation(
      await _repository.processPayrollRun(
        payrollRunId,
        replaceExistingItems: replaceExistingItems,
      ),
      refreshOverviewAfter: true,
      refreshWorkItemsAfter: true,
      refreshReferencesAfter: true,
    );
  }

  Future<Result<String>> createPayrollRunDraft(
    Map<String, Object?> payload,
  ) async {
    final Result<Object?> result = await _repository.createPayrollRun(payload);
    return result.when(
      success: (Object? data) {
        final String? runId = _extractApiRecordId(data);
        if (runId == null) {
          return Result<String>.failure(AppFailure.validation());
        }
        return Result<String>.success(runId);
      },
      failure: Result<String>.failure,
    );
  }

  Future<AppFailure?> offboardStaff(Map<String, Object?> payload) async {
    final HrWorkspaceState? current = _currentState;
    final HrStaffDetail? selected = current?.selectedStaff;
    if (current == null || selected == null) {
      return AppFailure.validation();
    }
    _emit(current.copyWith(isMutating: true, clearLastFailure: true));
    final Result<Object?> result = await _repository.offboardStaff(
      selected.profile.effectiveId,
      payload,
    );
    return result.when(
      success: (_) async {
        final DateTime? separationDate = DateTime.tryParse(
          payload['last_working_day']?.toString() ?? '',
        );
        final HrStaffProfile separated = selected.profile.copyWith(
          status: 'SEPARATED',
          separationType: payload['separation_type']?.toString(),
          separationDate: separationDate,
          separationNotes: payload['reason']?.toString(),
        );
        final HrWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              staff: _replaceStaff(latest.staff, separated),
              selectedStaff: selected.copyWith(profile: separated),
              isMutating: false,
            ),
          );
        }
        unawaited(_refreshStaff(showLoading: false));
        unawaited(_refreshOverview());
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

  Future<Result<HrPayrollPreview>> previewPayrollRun(HrWorkItem item) {
    return _repository.previewPayrollRun(item.effectiveId);
  }

  Future<Result<HrRosterGenerateResult>> previewRosterGenerate(
    HrWorkItem item,
  ) {
    return _repository.generateRosterPreview(item.effectiveId);
  }

  Future<Result<String>> generateStaffNumber({
    required String tenantId,
    String? facilityId,
  }) {
    return _repository.generateStaffNumber(
      tenantId: tenantId,
      facilityId: facilityId,
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

    return Result<HrWorkspaceState>.success(
      HrWorkspaceState(
        overview: overview,
        staffQuery: staffQuery,
        staff: staff,
        workItemsQuery: workItemsQuery,
        workItems: workItems,
        referenceData: referenceData,
      ),
    );
  }

  void _startAdaptivePolling() {
    installWorkspaceAdaptivePolling(
      ref: ref,
      polling: _adaptivePolling,
      intervalWhenDisconnected: _syncInterval,
      disconnectProfile: WorkspaceRefreshProfile.hr,
      syncOnDisconnect: (WorkspaceRefreshPlan plan) =>
          _syncVisibleData(plan: plan),
    );
  }

  Future<AppFailure?> _syncVisibleData({
    bool showLoading = false,
    bool refreshReferences = false,
    WorkspaceRefreshPlan plan = WorkspaceRefreshPlan.full,
  }) async {
    if (plan.isEmpty) {
      return null;
    }
    final HrWorkspaceState? current = _currentState;
    if (current == null || _isSyncing || current.isMutating) {
      _pendingRefresh.defer(plan);
      return null;
    }

    final bool refreshOverview = plan.summaryCounts;
    final bool refreshStaff = plan.primaryList;
    final bool refreshWorkItems = plan.primaryList;
    final bool refreshRefs =
        refreshReferences || workspacePlanRefreshesReferenceData(plan);
    final bool refreshDetail =
        plan.selectedDetail && current.selectedStaff != null;
    if (!refreshOverview &&
        !refreshStaff &&
        !refreshWorkItems &&
        !refreshRefs &&
        !refreshDetail) {
      return null;
    }

    _isSyncing = true;
    if (showLoading) {
      _emit(
        current.copyWith(
          isRefreshing: true,
          isRefreshingStaff: refreshStaff,
          isRefreshingWorkItems: refreshWorkItems,
          isRefreshingDetail: refreshDetail,
          clearLastFailure: true,
        ),
      );
    }

    try {
      AppFailure? overviewFailure;
      AppFailure? staffFailure;
      AppFailure? workItemsFailure;
      AppFailure? referencesFailure;

      if (refreshOverview) {
        overviewFailure = await _refreshOverview();
      }
      if (refreshStaff) {
        staffFailure = await _refreshStaff(showLoading: showLoading);
      }
      if (refreshWorkItems) {
        workItemsFailure = await _refreshWorkItems(showLoading: showLoading);
      }
      if (refreshRefs) {
        referencesFailure = await _refreshReferences();
      }
      if (refreshDetail) {
        final HrStaffProfile? profile = _currentState?.selectedStaff?.profile;
        if (profile != null) {
          await _refreshSelectedDetail(profile);
        }
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
      if (_pendingRefresh.refreshPending &&
          !(_currentState?.isMutating ?? false)) {
        final WorkspaceRefreshPlan pendingPlan = _pendingRefresh.takePending();
        if (!pendingPlan.isEmpty) {
          unawaited(_syncVisibleData(plan: pendingPlan));
        }
      }
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

  Future<AppFailure?> _refreshReferences({
    String? facilityId,
    bool forOnboarding = false,
  }) async {
    final HrWorkspaceState? current = _currentState;
    final String? departmentId = forOnboarding
        ? null
        : current?.staffQuery.departmentId;
    final String? resolvedFacilityId =
        facilityId ?? ref.read(sessionStateProvider).session?.user?.facilityId;
    final Result<HrReferenceData> result = await _repository.loadReferenceData(
      facilityId: resolvedFacilityId,
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
    final String? facilityId = ref
        .read(sessionStateProvider)
        .session
        ?.user
        ?.facilityId;
    final Result<HrReferenceData> result = await _repository.loadReferenceData(
      facilityId: facilityId,
    );
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

  String? _extractCreatedUserId(Result<Object?> userResult) {
    return userResult.when(
      success: (Object? data) {
        if (data is! Map) {
          return null;
        }
        final Map<Object?, Object?> source = data['data'] is Map
            ? data['data'] as Map
            : data;
        return source['id']?.toString() ??
            source['user_id']?.toString() ??
            source['display_id']?.toString() ??
            source['human_friendly_id']?.toString();
      },
      failure: (_) => null,
    );
  }

  String? _extractApiRecordId(Object? data) {
    if (data is! Map) {
      return null;
    }
    final Map<Object?, Object?> source = data['data'] is Map
        ? data['data'] as Map
        : data;
    return source['display_id']?.toString() ??
        source['human_friendly_id']?.toString() ??
        source['id']?.toString();
  }
}

/// Whether HR staff onboarding dropdowns have enough reference data to render.
bool hasHrOnboardingReferenceData(HrReferenceData data) {
  return data.staffPositions.isNotEmpty &&
      data.departments.isNotEmpty &&
      data.practitionerTypes.isNotEmpty &&
      data.roles.isNotEmpty;
}
