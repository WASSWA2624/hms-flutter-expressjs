import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/features/integrations/data/repositories/integrations_repository_impl.dart';
import 'package:hosspi_hms/features/integrations/domain/entities/integration_entities.dart';
import 'package:hosspi_hms/features/integrations/domain/repositories/integrations_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final integrationsWorkspaceControllerProvider =
    AsyncNotifierProvider<
      IntegrationsWorkspaceController,
      Result<IntegrationWorkspaceState>
    >(IntegrationsWorkspaceController.new);

final class IntegrationsWorkspaceController
    extends AsyncNotifier<Result<IntegrationWorkspaceState>> {
  IntegrationsRepository get _repository {
    return ref.read(integrationsRepositoryProvider);
  }

  @override
  Future<Result<IntegrationWorkspaceState>> build() async {
    return _loadSnapshot(const IntegrationWorkspaceQuery());
  }

  Future<AppFailure?> refresh() async {
    final IntegrationWorkspaceState? current = _currentState;
    if (current == null) {
      ref.invalidateSelf();
      return null;
    }

    _emit(current.copyWith(isRefreshing: true, clearLastFailure: true));
    final Result<IntegrationWorkspaceState> result = await _loadSnapshot(
      current.query,
    );
    return result.when(
      success: (IntegrationWorkspaceState snapshot) {
        _emit(
          snapshot.copyWith(
            selectedItem: _selectedFromSnapshot(snapshot, current.selectedItem),
          ),
        );
        return null;
      },
      failure: (AppFailure failure) {
        _emit(current.copyWith(isRefreshing: false, lastFailure: failure));
        return failure;
      },
    );
  }

  Future<AppFailure?> applySearch(String value) async {
    final IntegrationWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        query: current.query.copyWith(
          search: value.trim(),
          pageRequest: current.query.pageRequest.first(),
        ),
        clearLastFailure: true,
      ),
    );
    return null;
  }

  Future<AppFailure?> applyFilter(IntegrationWorkspaceFilter filter) async {
    final IntegrationWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        query: current.query.copyWith(
          filter: filter,
          pageRequest: current.query.pageRequest.first(),
        ),
        clearLastFailure: true,
      ),
    );
    return null;
  }

  Future<AppFailure?> changePage(AppPageRequest request) async {
    final IntegrationWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        query: current.query.copyWith(pageRequest: request),
        clearLastFailure: true,
      ),
    );
    return null;
  }

  Future<AppFailure?> selectItem(IntegrationWorkItem item) async {
    final IntegrationWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    if (item.kind == IntegrationWorkItemKind.log) {
      final Result<IntegrationLogRecord> result = await _repository.getLog(
        item.id,
      );
      return result.when(
        success: (IntegrationLogRecord log) {
          final IntegrationWorkItem detailItem = IntegrationWorkItem.log(log);
          _emit(
            current.copyWith(
              logs: _upsertById(current.logs, log, (record) => record.id),
              selectedItem: detailItem,
              clearLastFailure: true,
            ),
          );
          return null;
        },
        failure: (AppFailure failure) {
          _emit(current.copyWith(lastFailure: failure));
          return failure;
        },
      );
    }

    _emit(current.copyWith(selectedItem: item, clearLastFailure: true));
    return null;
  }

  Future<AppFailure?> createIntegration(Map<String, Object?> payload) async {
    return _mutateRecord<IntegrationRecord>(
      _repository.createIntegration(payload),
      onSuccess: (IntegrationWorkspaceState current, IntegrationRecord record) {
        return current.copyWith(
          integrations: _upsertById(
            current.integrations,
            record,
            (IntegrationRecord item) => item.id,
          ),
          selectedItem: IntegrationWorkItem.integration(record),
        );
      },
    );
  }

  Future<AppFailure?> updateIntegration(
    String integrationId,
    Map<String, Object?> payload,
  ) async {
    return _mutateRecord<IntegrationRecord>(
      _repository.updateIntegration(integrationId, payload),
      onSuccess: (IntegrationWorkspaceState current, IntegrationRecord record) {
        return current.copyWith(
          integrations: _upsertById(
            current.integrations,
            record,
            (IntegrationRecord item) => item.id,
          ),
          selectedItem: IntegrationWorkItem.integration(record),
        );
      },
    );
  }

  Future<AppFailure?> deleteIntegration(String integrationId) async {
    return _mutateVoid(
      _repository.deleteIntegration(integrationId),
      onSuccess: (IntegrationWorkspaceState current) {
        return current.copyWith(
          integrations: _removeById(
            current.integrations,
            integrationId,
            (IntegrationRecord item) => item.id,
          ),
          clearSelectedItem: _selectedMatches(
            current.selectedItem,
            IntegrationWorkItemKind.integration,
            integrationId,
          ),
        );
      },
    );
  }

  Future<Result<IntegrationActionResult>> testConnection(
    String integrationId,
    Map<String, Object?> payload,
  ) {
    return _runAction(_repository.testConnection(integrationId, payload));
  }

  Future<Result<IntegrationActionResult>> syncNow(
    String integrationId,
    Map<String, Object?> payload,
  ) {
    return _runAction(_repository.syncNow(integrationId, payload));
  }

  Future<Result<ApiKeyRecord>> createApiKey(
    Map<String, Object?> payload,
  ) async {
    final IntegrationWorkspaceState? current = _currentState;
    if (current == null) {
      return const Result<ApiKeyRecord>.failure(AppFailure.unexpected());
    }

    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    final Result<ApiKeyRecord> result = await _repository.createApiKey(payload);
    return result.when(
      success: (ApiKeyRecord record) async {
        final AppFailure? refreshFailure = await _refreshApiKeys();
        final IntegrationWorkspaceState? refreshed = _currentState;
        if (refreshed != null) {
          _emit(refreshed.copyWith(isSaving: false));
        }
        if (refreshFailure != null) {
          return Result<ApiKeyRecord>.failure(refreshFailure);
        }
        return Result<ApiKeyRecord>.success(record);
      },
      failure: (AppFailure failure) {
        _emit(current.copyWith(isSaving: false, lastFailure: failure));
        return Result<ApiKeyRecord>.failure(failure);
      },
    );
  }

  Future<AppFailure?> updateApiKey(
    String apiKeyId,
    Map<String, Object?> payload,
  ) async {
    return _mutateRecord<ApiKeyRecord>(
      _repository.updateApiKey(apiKeyId, payload),
      onSuccess: (IntegrationWorkspaceState current, ApiKeyRecord record) {
        return current.copyWith(
          apiKeys: _upsertById(
            current.apiKeys,
            record,
            (ApiKeyRecord item) => item.id,
          ),
          selectedItem: IntegrationWorkItem.apiKey(
            record,
            current.apiKeyPermissions,
          ),
        );
      },
    );
  }

  Future<AppFailure?> deleteApiKey(String apiKeyId) async {
    return _mutateVoid(
      _repository.deleteApiKey(apiKeyId),
      onSuccess: (IntegrationWorkspaceState current) {
        return current.copyWith(
          apiKeys: _removeById(
            current.apiKeys,
            apiKeyId,
            (ApiKeyRecord item) => item.id,
          ),
          apiKeyPermissions: current.apiKeyPermissions
              .where(
                (ApiKeyPermissionRecord permission) =>
                    permission.apiKeyId != apiKeyId,
              )
              .toList(growable: false),
          clearSelectedItem: _selectedMatches(
            current.selectedItem,
            IntegrationWorkItemKind.apiKey,
            apiKeyId,
          ),
        );
      },
    );
  }

  Future<AppFailure?> addApiKeyPermission({
    required String apiKeyId,
    required String permissionId,
  }) async {
    return _mutateRecord<ApiKeyPermissionRecord>(
      _repository.createApiKeyPermission(<String, Object?>{
        'api_key_id': apiKeyId,
        'permission_id': permissionId,
      }),
      onSuccess:
          (IntegrationWorkspaceState current, ApiKeyPermissionRecord record) {
            final IntegrationWorkspaceState next = current.copyWith(
              apiKeyPermissions: _upsertById(
                current.apiKeyPermissions,
                record,
                (ApiKeyPermissionRecord item) => item.id,
              ),
            );
            return next.copyWith(
              selectedItem: _selectedFromSnapshot(next, current.selectedItem),
            );
          },
    );
  }

  Future<AppFailure?> removeApiKeyPermission(String grantId) async {
    return _mutateVoid(
      _repository.deleteApiKeyPermission(grantId),
      onSuccess: (IntegrationWorkspaceState current) {
        final IntegrationWorkspaceState next = current.copyWith(
          apiKeyPermissions: _removeById(
            current.apiKeyPermissions,
            grantId,
            (ApiKeyPermissionRecord item) => item.id,
          ),
        );
        return next.copyWith(
          selectedItem: _selectedFromSnapshot(next, current.selectedItem),
        );
      },
    );
  }

  Future<AppFailure?> createWebhook(Map<String, Object?> payload) async {
    return _mutateRecord<WebhookSubscriptionRecord>(
      _repository.createWebhook(payload),
      onSuccess:
          (
            IntegrationWorkspaceState current,
            WebhookSubscriptionRecord record,
          ) {
            return current.copyWith(
              webhooks: _upsertById(
                current.webhooks,
                record,
                (WebhookSubscriptionRecord item) => item.id,
              ),
              selectedItem: IntegrationWorkItem.webhook(record),
            );
          },
    );
  }

  Future<AppFailure?> updateWebhook(
    String webhookId,
    Map<String, Object?> payload,
  ) async {
    return _mutateRecord<WebhookSubscriptionRecord>(
      _repository.updateWebhook(webhookId, payload),
      onSuccess:
          (
            IntegrationWorkspaceState current,
            WebhookSubscriptionRecord record,
          ) {
            return current.copyWith(
              webhooks: _upsertById(
                current.webhooks,
                record,
                (WebhookSubscriptionRecord item) => item.id,
              ),
              selectedItem: IntegrationWorkItem.webhook(record),
            );
          },
    );
  }

  Future<AppFailure?> deleteWebhook(String webhookId) async {
    return _mutateVoid(
      _repository.deleteWebhook(webhookId),
      onSuccess: (IntegrationWorkspaceState current) {
        return current.copyWith(
          webhooks: _removeById(
            current.webhooks,
            webhookId,
            (WebhookSubscriptionRecord item) => item.id,
          ),
          clearSelectedItem: _selectedMatches(
            current.selectedItem,
            IntegrationWorkItemKind.webhook,
            webhookId,
          ),
        );
      },
    );
  }

  Future<Result<IntegrationActionResult>> replayWebhook(
    String webhookId,
    Map<String, Object?> payload,
  ) {
    return _runAction(_repository.replayWebhook(webhookId, payload));
  }

  Future<Result<IntegrationActionResult>> replayLog(
    String logId,
    Map<String, Object?> payload,
  ) {
    return _runAction(_repository.replayLog(logId, payload));
  }

  Map<String, Object?> currentApiKeyCreateContext() {
    final session = ref.read(sessionStateProvider).session;
    return <String, Object?>{
      'tenant_id': session?.user?.tenantId,
      'user_id': session?.user?.id,
    };
  }

  String? currentTenantId() {
    return ref.read(sessionStateProvider).session?.user?.tenantId;
  }

  Future<Result<IntegrationWorkspaceState>> _loadSnapshot(
    IntegrationWorkspaceQuery query,
  ) async {
    final Result<List<IntegrationRecord>> integrationsResult = await _repository
        .listIntegrations();
    final Result<List<ApiKeyRecord>> apiKeysResult = await _repository
        .listApiKeys();
    final Result<List<ApiKeyPermissionRecord>> apiKeyPermissionsResult =
        await _repository.listApiKeyPermissions();
    final Result<List<IntegrationPermissionOption>> permissionOptionsResult =
        await _repository.listPermissionOptions();
    final Result<List<WebhookSubscriptionRecord>> webhooksResult =
        await _repository.listWebhooks();
    final Result<List<IntegrationLogRecord>> logsResult = await _repository
        .listLogs();

    final AppFailure? failure = _firstFailure(<AppFailure?>[
      _failureOf(integrationsResult),
      _failureOf(apiKeysResult),
      _failureOf(apiKeyPermissionsResult),
      _failureOf(permissionOptionsResult),
      _failureOf(webhooksResult),
      _failureOf(logsResult),
    ]);
    if (failure != null) {
      return Result<IntegrationWorkspaceState>.failure(failure);
    }

    return Result<IntegrationWorkspaceState>.success(
      IntegrationWorkspaceState(
        query: query,
        integrations: _valueOf(integrationsResult),
        apiKeys: _valueOf(apiKeysResult),
        apiKeyPermissions: _valueOf(apiKeyPermissionsResult),
        permissionOptions: _valueOf(permissionOptionsResult),
        webhooks: _valueOf(webhooksResult),
        logs: _valueOf(logsResult),
        interopStatuses: _repository.interopCapabilities(),
      ),
    );
  }

  Future<Result<IntegrationActionResult>> _runAction(
    Future<Result<IntegrationActionResult>> action,
  ) async {
    final IntegrationWorkspaceState? current = _currentState;
    if (current == null) {
      return const Result<IntegrationActionResult>.failure(
        AppFailure.unexpected(),
      );
    }

    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    final Result<IntegrationActionResult> result = await action;
    return result.when(
      success: (IntegrationActionResult actionResult) async {
        await _refreshLogs();
        final IntegrationWorkspaceState? refreshed = _currentState;
        if (refreshed != null) {
          _emit(
            refreshed.copyWith(isSaving: false, lastActionResult: actionResult),
          );
        }
        return Result<IntegrationActionResult>.success(actionResult);
      },
      failure: (AppFailure failure) {
        _emit(current.copyWith(isSaving: false, lastFailure: failure));
        return Result<IntegrationActionResult>.failure(failure);
      },
    );
  }

  Future<AppFailure?> _mutateRecord<T>(
    Future<Result<T>> action, {
    required IntegrationWorkspaceState Function(
      IntegrationWorkspaceState current,
      T record,
    )
    onSuccess,
  }) async {
    final IntegrationWorkspaceState? current = _currentState;
    if (current == null) {
      return const AppFailure.unexpected();
    }

    _emit(
      current.copyWith(
        isSaving: true,
        clearLastFailure: true,
        clearLastActionResult: true,
      ),
    );
    final Result<T> result = await action;
    return result.when(
      success: (T record) {
        final IntegrationWorkspaceState next = onSuccess(
          _currentState!,
          record,
        );
        _emit(next.copyWith(isSaving: false));
        return null;
      },
      failure: (AppFailure failure) {
        _emit(_currentState!.copyWith(isSaving: false, lastFailure: failure));
        return failure;
      },
    );
  }

  Future<AppFailure?> _mutateVoid(
    Future<Result<void>> action, {
    required IntegrationWorkspaceState Function(
      IntegrationWorkspaceState current,
    )
    onSuccess,
  }) async {
    final IntegrationWorkspaceState? current = _currentState;
    if (current == null) {
      return const AppFailure.unexpected();
    }

    _emit(
      current.copyWith(
        isSaving: true,
        clearLastFailure: true,
        clearLastActionResult: true,
      ),
    );
    final Result<void> result = await action;
    return result.when(
      success: (_) {
        final IntegrationWorkspaceState next = onSuccess(_currentState!);
        _emit(next.copyWith(isSaving: false));
        return null;
      },
      failure: (AppFailure failure) {
        _emit(_currentState!.copyWith(isSaving: false, lastFailure: failure));
        return failure;
      },
    );
  }

  Future<AppFailure?> _refreshApiKeys() async {
    final Result<List<ApiKeyRecord>> result = await _repository.listApiKeys();
    return result.when(
      success: (List<ApiKeyRecord> apiKeys) {
        final IntegrationWorkspaceState current = _currentState!;
        _emit(
          current.copyWith(
            apiKeys: apiKeys,
            selectedItem: _selectedFromSnapshot(
              current.copyWith(apiKeys: apiKeys),
              current.selectedItem,
            ),
          ),
        );
        return null;
      },
      failure: (AppFailure failure) {
        _emit(_currentState!.copyWith(lastFailure: failure));
        return failure;
      },
    );
  }

  Future<AppFailure?> _refreshLogs() async {
    final Result<List<IntegrationLogRecord>> result = await _repository
        .listLogs();
    return result.when(
      success: (List<IntegrationLogRecord> logs) {
        final IntegrationWorkspaceState current = _currentState!;
        _emit(
          current.copyWith(
            logs: logs,
            selectedItem: _selectedFromSnapshot(
              current.copyWith(logs: logs),
              current.selectedItem,
            ),
          ),
        );
        return null;
      },
      failure: (AppFailure failure) {
        _emit(_currentState!.copyWith(lastFailure: failure));
        return failure;
      },
    );
  }

  IntegrationWorkspaceState? get _currentState {
    final Result<IntegrationWorkspaceState>? currentResult =
        state.asData?.value;
    return switch (currentResult) {
      ResultSuccess<IntegrationWorkspaceState>(value: final value) => value,
      _ => null,
    };
  }

  void _emit(IntegrationWorkspaceState nextState) {
    state = AsyncData<Result<IntegrationWorkspaceState>>(
      Result<IntegrationWorkspaceState>.success(nextState),
    );
  }
}

AppFailure? _failureOf<T>(Result<T> result) {
  return result.when(
    success: (_) => null,
    failure: (AppFailure failure) => failure,
  );
}

AppFailure? _firstFailure(Iterable<AppFailure?> failures) {
  for (final AppFailure? failure in failures) {
    if (failure != null) {
      return failure;
    }
  }
  return null;
}

T _valueOf<T>(Result<T> result) {
  return result.when(
    success: (T value) => value,
    failure: (_) => throw StateError('Result failure has no value.'),
  );
}

List<T> _upsertById<T>(List<T> source, T value, String Function(T value) idOf) {
  final String id = idOf(value);
  final List<T> items = List<T>.of(source);
  final int index = items.indexWhere((T item) => idOf(item) == id);
  if (index < 0) {
    items.insert(0, value);
  } else {
    items[index] = value;
  }
  return List<T>.unmodifiable(items);
}

List<T> _removeById<T>(
  List<T> source,
  String id,
  String Function(T value) idOf,
) {
  return source.where((T item) => idOf(item) != id).toList(growable: false);
}

bool _selectedMatches(
  IntegrationWorkItem? selected,
  IntegrationWorkItemKind kind,
  String id,
) {
  return selected?.kind == kind && selected?.id == id;
}

IntegrationWorkItem? _selectedFromSnapshot(
  IntegrationWorkspaceState snapshot,
  IntegrationWorkItem? selected,
) {
  if (selected == null) {
    return null;
  }
  for (final IntegrationWorkItem item in snapshot.workItems) {
    if (item.rowKey == selected.rowKey) {
      return item;
    }
  }
  return selected;
}
