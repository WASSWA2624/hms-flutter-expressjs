import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/realtime/realtime_refresh.dart';
import 'package:hosspi_hms/core/security/session_isolation.dart';
import 'package:hosspi_hms/core/workspace/workspace_session_guard.dart';
import 'package:hosspi_hms/features/settings/data/repositories/settings_workspace_repository_impl.dart';
import 'package:hosspi_hms/features/settings/domain/entities/settings_workspace_entities.dart';
import 'package:hosspi_hms/features/settings/domain/repositories/settings_workspace_repository.dart';
import 'package:hosspi_hms/features/settings/presentation/state/settings_workspace_state.dart';

final settingsWorkspaceControllerProvider =
    AsyncNotifierProvider<
      SettingsWorkspaceController,
      Result<SettingsWorkspaceState>
    >(SettingsWorkspaceController.new);

final class SettingsWorkspaceController
    extends AsyncNotifier<Result<SettingsWorkspaceState>> {
  SettingsWorkspaceRepository get _repository =>
      ref.read(settingsWorkspaceRepositoryProvider);

  @override
  Future<Result<SettingsWorkspaceState>> build() async {
    watchSessionEpoch(ref);
    listenForRealtimeRefresh(
      ref: ref,
      events: RealtimeEventGroups.settings,
      includeCrudMutations: true,
      onRefresh: (_) => refresh(),
    );
    return runWorkspaceInitialLoad(
      ref,
      () => _load(const SettingsWorkspaceQuery()),
    );
  }

  Future<AppFailure?> refresh() async {
    final SettingsWorkspaceState? current = _currentState;
    if (current == null) {
      state = const AsyncLoading<Result<SettingsWorkspaceState>>();
      state = AsyncData<Result<SettingsWorkspaceState>>(
        await _load(const SettingsWorkspaceQuery()),
      );
      return _failureOrNull(state.asData?.value);
    }

    _emit(current.copyWith(isRefreshing: true));
    final Result<SettingsWorkspaceState> result = await _load(current.query);
    state = AsyncData<Result<SettingsWorkspaceState>>(result);
    return _failureOrNull(result);
  }

  Future<AppFailure?> applySearch(String search) {
    return _applyQuery((SettingsWorkspaceQuery query) {
      return query.copyWith(search: search.trim());
    });
  }

  Future<AppFailure?> applyGroup(String? group) {
    return _applyQuery((SettingsWorkspaceQuery query) {
      return query.copyWith(group: group, clearGroup: group == null);
    });
  }

  Future<AppFailure?> applyState(SettingsModuleState? moduleState) {
    return _applyQuery((SettingsWorkspaceQuery query) {
      return query.copyWith(
        state: moduleState,
        clearState: moduleState == null,
      );
    });
  }

  Future<AppFailure?> toggleActionableOnly(bool value) {
    return _applyQuery((SettingsWorkspaceQuery query) {
      return query.copyWith(actionableOnly: value);
    });
  }

  Future<AppFailure?> selectTenant(String? tenantId) {
    return _applyQuery((SettingsWorkspaceQuery query) {
      return query.copyWith(
        tenantId: tenantId,
        clearTenant: tenantId == null,
        clearFacility: true,
      );
    });
  }

  Future<AppFailure?> selectFacility(String? facilityId) {
    return _applyQuery((SettingsWorkspaceQuery query) {
      return query.copyWith(
        facilityId: facilityId,
        clearFacility: facilityId == null,
      );
    });
  }

  Future<AppFailure?> _applyQuery(
    SettingsWorkspaceQuery Function(SettingsWorkspaceQuery query) update,
  ) async {
    final SettingsWorkspaceState? current = _currentState;
    final SettingsWorkspaceQuery nextQuery = update(
      current?.query ?? const SettingsWorkspaceQuery(),
    );

    if (current == null) {
      state = const AsyncLoading<Result<SettingsWorkspaceState>>();
    } else {
      _emit(current.copyWith(query: nextQuery, isRefreshing: true));
    }

    final Result<SettingsWorkspaceState> result = await _load(nextQuery);
    state = AsyncData<Result<SettingsWorkspaceState>>(result);
    return _failureOrNull(result);
  }

  Future<Result<SettingsWorkspaceState>> _load(
    SettingsWorkspaceQuery query,
  ) async {
    final Result<SettingsWorkspace> workspaceResult = await _repository
        .getWorkspace(query);
    return workspaceResult.when(
      success: (SettingsWorkspace workspace) async {
        SettingsReferenceData referenceData = workspace.referenceData;
        final bool needsReferenceData =
            referenceData.tenants.isEmpty && referenceData.facilities.isEmpty;
        if (needsReferenceData ||
            workspace.status == SettingsWorkspaceStatus.tenantContextRequired) {
          final Result<SettingsReferenceData> referenceResult =
              await _repository.getReferenceData(query);
          referenceData = referenceResult.when(
            success: (SettingsReferenceData data) => data,
            failure: (_) => referenceData,
          );
        }

        return Result<SettingsWorkspaceState>.success(
          SettingsWorkspaceState(
            query: query,
            workspace: workspace,
            referenceData: referenceData,
          ),
        );
      },
      failure: (AppFailure failure) async {
        return Result<SettingsWorkspaceState>.failure(failure);
      },
    );
  }

  SettingsWorkspaceState? get _currentState {
    final Result<SettingsWorkspaceState>? currentResult = state.asData?.value;
    return switch (currentResult) {
      ResultSuccess<SettingsWorkspaceState>(value: final value) => value,
      _ => null,
    };
  }

  AppFailure? _failureOrNull<T>(Result<T>? result) {
    return switch (result) {
      ResultFailure<T>(failure: final failure) => failure,
      _ => null,
    };
  }

  void _emit(SettingsWorkspaceState nextState) {
    state = AsyncData<Result<SettingsWorkspaceState>>(
      Result<SettingsWorkspaceState>.success(nextState),
    );
  }
}
