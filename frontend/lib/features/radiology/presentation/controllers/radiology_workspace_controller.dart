import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/realtime/realtime_refresh.dart';
import 'package:hosspi_hms/core/workspace/workspace_session_guard.dart';
import 'package:hosspi_hms/features/radiology/data/repositories/radiology_repository_impl.dart';
import 'package:hosspi_hms/features/radiology/domain/entities/radiology_entities.dart';
import 'package:hosspi_hms/features/radiology/domain/repositories/radiology_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final radiologyWorkspaceControllerProvider =
    AsyncNotifierProvider<
      RadiologyWorkspaceController,
      Result<RadiologyWorkspaceState>
    >(RadiologyWorkspaceController.new);

final class RadiologyWorkspaceController
    extends AsyncNotifier<Result<RadiologyWorkspaceState>> {
  static const Duration _syncInterval = Duration(seconds: 12);

  RadiologyRepository get _repository => ref.read(radiologyRepositoryProvider);

  Timer? _syncTimer;
  bool _isSyncing = false;

  @override
  Future<Result<RadiologyWorkspaceState>> build() async {
    ref.onDispose(() => _syncTimer?.cancel());
    listenForRealtimeRefresh(
      ref: ref,
      events: RealtimeEventGroups.radiology,
      includeCrudMutations: true,
      shouldDefer: () {
        final RadiologyWorkspaceState? current = _currentState;
        return _isSyncing || (current?.isMutating ?? false);
      },
      onRefresh: (_) => _syncFromRealtime(),
    );
    final Result<RadiologyWorkspaceState> result =
        await runWorkspaceInitialLoad(ref, _loadInitialState);
    _startSync();
    return result;
  }

  Future<void> _syncFromRealtime() async {
    await _syncVisibleData();
  }

  Future<AppFailure?> refresh() {
    return _syncVisibleData(showLoading: true);
  }

  Future<AppFailure?> applySearch(String value) async {
    final RadiologyWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        query: current.query.copyWith(
          search: value.trim(),
          pageRequest: current.query.pageRequest.first(),
        ),
        isRefreshing: true,
        clearLastFailure: true,
      ),
    );
    return _refreshWorkbench(showLoading: true);
  }

  Future<AppFailure?> applyStage(String stage) async {
    final RadiologyWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        query: current.query.copyWith(
          stage: stage,
          pageRequest: current.query.pageRequest.first(),
        ),
        isRefreshing: true,
        clearLastFailure: true,
      ),
    );
    return _refreshWorkbench(showLoading: true);
  }

  Future<AppFailure?> applyView(RadiologyWorkbenchView view) async {
    final RadiologyWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        query: current.query.copyWith(
          view: view,
          stage: 'ALL',
          clearStatus: true,
          pageRequest: current.query.pageRequest.first(),
        ),
        isRefreshing: true,
        clearSelectedWorkflow: true,
        clearLastFailure: true,
      ),
    );
    return _refreshWorkbench(showLoading: true);
  }

  Future<AppFailure?> applyStatus(String? status) async {
    final RadiologyWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        query: current.query.copyWith(
          status: status,
          clearStatus: status == null,
          pageRequest: current.query.pageRequest.first(),
        ),
        isRefreshing: true,
        clearLastFailure: true,
      ),
    );
    return _refreshWorkbench(showLoading: true);
  }

  Future<AppFailure?> applyModality(String? modality) async {
    final RadiologyWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        query: current.query.copyWith(
          modality: modality,
          clearModality: modality == null,
          pageRequest: current.query.pageRequest.first(),
        ),
        isRefreshing: true,
        clearLastFailure: true,
      ),
    );
    return _refreshWorkbench(showLoading: true);
  }

  Future<AppFailure?> applyPriority(String? priority) async {
    final RadiologyWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        query: current.query.copyWith(
          priority: priority,
          clearPriority: priority == null,
          pageRequest: current.query.pageRequest.first(),
        ),
        isRefreshing: true,
        clearLastFailure: true,
      ),
    );
    return _refreshWorkbench(showLoading: true);
  }

  Future<AppFailure?> applyBillingGate(String? billingGate) async {
    final RadiologyWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        query: current.query.copyWith(
          billingGate: billingGate,
          clearBillingGate: billingGate == null,
          pageRequest: current.query.pageRequest.first(),
        ),
        isRefreshing: true,
        clearLastFailure: true,
      ),
    );
    return _refreshWorkbench(showLoading: true);
  }

  Future<AppFailure?> applyOrderedDate(DateTime? date) async {
    final RadiologyWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    final DateTime? start = date == null
        ? null
        : DateTime(date.year, date.month, date.day);
    final DateTime? end = start?.add(const Duration(days: 1));
    _emit(
      current.copyWith(
        query: current.query.copyWith(
          from: start,
          to: end,
          clearFrom: date == null,
          clearTo: date == null,
          pageRequest: current.query.pageRequest.first(),
        ),
        isRefreshing: true,
        clearLastFailure: true,
      ),
    );
    return _refreshWorkbench(showLoading: true);
  }

  Future<AppFailure?> clearFilters() async {
    final RadiologyWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        query: RadiologyWorkspaceQuery(
          pageRequest: current.query.pageRequest.first(),
        ),
        isRefreshing: true,
        clearLastFailure: true,
      ),
    );
    return _refreshWorkbench(showLoading: true);
  }

  Future<AppFailure?> changePage(AppPageRequest request) async {
    final RadiologyWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        query: current.query.copyWith(pageRequest: request),
        isRefreshing: true,
        clearLastFailure: true,
      ),
    );
    return _refreshWorkbench(showLoading: true);
  }

  Future<AppFailure?> searchReferences({
    String? search,
    String? patientId,
  }) async {
    final RadiologyWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(current.copyWith(isRefreshing: true, clearLastFailure: true));
    final Result<RadiologyReferenceData> result = await _repository
        .getReferenceData(search: search, patientId: patientId);

    return result.when(
      success: (RadiologyReferenceData references) {
        final RadiologyWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(references: references, isRefreshing: false));
        }
        return null;
      },
      failure: (AppFailure failure) {
        final RadiologyWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(isRefreshing: false, lastFailure: failure));
        }
        return failure;
      },
    );
  }

  Future<AppFailure?> refreshConfigurations({String? search}) async {
    final RadiologyCatalogScope? scope = _currentState?.catalogScope;
    if (scope?.isReady == true) {
      return loadFacilityCatalogConfig(scope!);
    }
    final RadiologyWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(current.copyWith(isRefreshing: true, clearLastFailure: true));
    final AppFailure? failure = await _refreshEquipmentRecords(search: search);
    final RadiologyWorkspaceState? latest = _currentState;
    if (latest != null) {
      _emit(
        latest.copyWith(
          isRefreshing: false,
          lastFailure: failure,
          clearLastFailure: failure == null,
        ),
      );
    }
    return failure;
  }

  Future<AppFailure?> loadFacilityCatalogConfig(
    RadiologyCatalogScope scope, {
    String? search,
  }) async {
    final RadiologyWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }
    if (!scope.isReady) {
      _emit(
        current.copyWith(
          catalogScope: scope,
          catalogTests: const <RadiologyCatalogTest>[],
          isLoadingCatalog: false,
          clearCatalogLoadFailure: true,
        ),
      );
      return null;
    }

    _emit(
      current.copyWith(
        catalogScope: scope,
        isLoadingCatalog: true,
        clearCatalogLoadFailure: true,
      ),
    );
    final Result<List<RadiologyCatalogTest>> testsResult = await _repository
        .listFacilityRadiologyTests(
          tenantId: scope.tenantId,
          facilityId: scope.facilityId,
          search: search,
          offeredOnly: true,
        );

    AppFailure? failure;
    final List<RadiologyCatalogTest> tests = testsResult.when(
      success: (List<RadiologyCatalogTest> value) => value,
      failure: (AppFailure value) {
        failure ??= value;
        return const <RadiologyCatalogTest>[];
      },
    );
    final RadiologyWorkspaceState? latest = _currentState;
    if (latest != null) {
      _emit(
        latest.copyWith(
          catalogTests: tests,
          catalogScope: scope,
          isLoadingCatalog: false,
          catalogLoadFailure: failure,
          clearCatalogLoadFailure: failure == null,
        ),
      );
    }
    return failure;
  }

  Future<Result<List<RadiologyCatalogTest>>> searchPlatformRadiologyCatalogForOffering({
    required RadiologyCatalogScope scope,
    String? query,
    int limit = 100,
  }) async {
    if (!scope.isReady) {
      return const Result<List<RadiologyCatalogTest>>.success(
        <RadiologyCatalogTest>[],
      );
    }

    final Future<Result<List<RadiologyCatalogTest>>> platformFuture =
        _repository.listRadiologyCatalogTests(
          search: query,
          limit: limit,
        );
    final Future<Result<List<RadiologyCatalogTest>>> offeredFuture =
        _repository.listFacilityRadiologyTests(
          tenantId: scope.tenantId,
          facilityId: scope.facilityId,
          offeredOnly: true,
          limit: limit,
        );

    final List<Result<List<RadiologyCatalogTest>>> results = await Future.wait(
      <Future<Result<List<RadiologyCatalogTest>>>>[
        platformFuture,
        offeredFuture,
      ],
    );
    return _mergePlatformRadiologyOfferingStatus(results[0], results[1]);
  }

  Result<List<RadiologyCatalogTest>> _mergePlatformRadiologyOfferingStatus(
    Result<List<RadiologyCatalogTest>> platformResult,
    Result<List<RadiologyCatalogTest>> offeredResult,
  ) {
    return platformResult.when(
      success: (List<RadiologyCatalogTest> platformItems) {
        final Set<String> offeredIds = <String>{};
        final Set<String> offeredCodes = <String>{};
        offeredResult.when(
          success: (List<RadiologyCatalogTest> offeredItems) {
            for (final RadiologyCatalogTest item in offeredItems) {
              offeredIds.add(item.apiId);
              final String? code = item.code?.trim();
              if (code != null && code.isNotEmpty) {
                offeredCodes.add(code.toUpperCase());
              }
            }
          },
          failure: (_) {},
        );
        return Result<List<RadiologyCatalogTest>>.success(
          platformItems
              .map((RadiologyCatalogTest item) {
                final String? code = item.code?.trim();
                final bool isOffered =
                    offeredIds.contains(item.apiId) ||
                    (code != null &&
                        code.isNotEmpty &&
                        offeredCodes.contains(code.toUpperCase()));
                if (!isOffered) {
                  return item;
                }
                return RadiologyCatalogTest(
                  id: item.id,
                  name: item.name,
                  displayId: item.displayId,
                  code: item.code,
                  modality: item.modality,
                  bodyRegion: item.bodyRegion,
                  laterality: item.laterality,
                  procedureType: item.procedureType,
                  equipment: item.equipment,
                  status: item.status,
                  source: item.source,
                  searchText: item.searchText,
                  unitPrice: item.unitPrice,
                  currency: item.currency,
                  isOfferedAtFacility: true,
                  facilityOfferingId: item.facilityOfferingId,
                  createdAt: item.createdAt,
                  updatedAt: item.updatedAt,
                );
              })
              .toList(growable: false),
        );
      },
      failure: (AppFailure failure) =>
          Result<List<RadiologyCatalogTest>>.failure(failure),
    );
  }

  Future<AppFailure?> upsertRadiologyTestOffering(
    String testId,
    Map<String, Object?> payload, {
    RadiologyCatalogScope? scope,
  }) async {
    final RadiologyWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }
    final RadiologyCatalogScope? effectiveScope = scope ?? current.catalogScope;
    _emit(current.copyWith(isMutating: true, clearLastFailure: true));
    final Result<RadiologyCatalogTest> result = await _repository
        .upsertFacilityRadiologyTestOffering(
          testId,
          payload,
          tenantId: effectiveScope?.tenantId,
          facilityId: effectiveScope?.facilityId,
        );
    return result.when(
      success: (RadiologyCatalogTest updated) async {
        final RadiologyWorkspaceState? latest = _currentState;
        if (latest == null) {
          return null;
        }
        final List<RadiologyCatalogTest> tests = _mergeCatalogOfferingUpdate(
          latest.catalogTests,
          updated,
          testId,
        );
        _emit(
          latest.copyWith(
            catalogTests: tests,
            isMutating: false,
            clearLastFailure: true,
          ),
        );
        unawaited(searchReferences());
        return null;
      },
      failure: (AppFailure failure) {
        final RadiologyWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(isMutating: false, lastFailure: failure));
        }
        return failure;
      },
    );
  }

  Future<AppFailure?> disableRadiologyTestOffering(
    String testId,
    String reason,
  ) async {
    final RadiologyCatalogScope? scope = _currentState?.catalogScope;
    final RadiologyWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }
    _emit(current.copyWith(isMutating: true, clearLastFailure: true));
    final Result<void> result = await _repository
        .disableFacilityRadiologyTestOffering(
          testId,
          reason,
          tenantId: scope?.tenantId,
          facilityId: scope?.facilityId,
        );
    return result.when(
      success: (_) async {
        final RadiologyWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              catalogTests: latest.catalogTests
                  .where(
                    (RadiologyCatalogTest item) =>
                        item.apiId != testId && item.id != testId,
                  )
                  .toList(growable: false),
              isMutating: false,
              clearLastFailure: true,
            ),
          );
        }
        unawaited(searchReferences());
        return null;
      },
      failure: (AppFailure failure) {
        final RadiologyWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(isMutating: false, lastFailure: failure));
        }
        return failure;
      },
    );
  }

  Future<AppFailure?> createRadiologyTest(Map<String, Object?> payload) {
    return upsertRadiologyTestOffering(
      payload['radiology_test_id']?.toString() ?? '',
      payload,
    );
  }

  Future<AppFailure?> updateRadiologyTest(
    String testId,
    Map<String, Object?> payload,
  ) {
    return upsertRadiologyTestOffering(testId, payload);
  }

  Future<AppFailure?> deleteRadiologyTest(String testId) {
    return disableRadiologyTestOffering(testId, 'Removed from facility catalog');
  }

  Future<AppFailure?> selectOrder(RadiologyOrder order) async {
    final RadiologyWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(current.copyWith(isRefreshingDetail: true, clearLastFailure: true));
    final Result<RadiologyWorkflow> result = await _repository.getWorkflow(
      order.effectiveDisplayId,
    );

    return result.when(
      success: (RadiologyWorkflow workflow) {
        final RadiologyWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              selectedWorkflow: workflow,
              orders: _replaceOrder(latest.orders, workflow.order),
              isRefreshingDetail: false,
            ),
          );
        }
        return null;
      },
      failure: (AppFailure failure) {
        final RadiologyWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(isRefreshingDetail: false, lastFailure: failure),
          );
        }
        return failure;
      },
    );
  }

  void setDetailViewMode(RadiologyDetailViewMode mode) {
    final RadiologyWorkspaceState? current = _currentState;
    if (current == null || current.detailViewMode == mode) {
      return;
    }
    _emit(current.copyWith(detailViewMode: mode));
  }

  Future<AppFailure?> createOrder(Map<String, Object?> payload) {
    return _mutate(() => _repository.createOrder(payload));
  }

  Future<AppFailure?> updateOrderRequestDetails(Map<String, Object?> payload) {
    return _mutateSelected(
      (String orderId) =>
          _repository.updateOrderRequestDetails(orderId, payload),
    );
  }

  Future<AppFailure?> assignOrder(Map<String, Object?> payload) {
    return _mutateSelected(
      (String orderId) => _repository.assignOrder(orderId, payload),
    );
  }

  Future<AppFailure?> startOrder(Map<String, Object?> payload) {
    return _mutateSelected(
      (String orderId) => _repository.startOrder(orderId, payload),
    );
  }

  Future<AppFailure?> completeOrder(Map<String, Object?> payload) {
    return _mutateSelected(
      (String orderId) => _repository.completeOrder(orderId, payload),
    );
  }

  Future<AppFailure?> cancelOrder(Map<String, Object?> payload) {
    return _mutateSelected(
      (String orderId) => _repository.cancelOrder(orderId, payload),
    );
  }

  Future<AppFailure?> createStudy(Map<String, Object?> payload) {
    return _mutateSelected(
      (String orderId) => _repository.createStudy(orderId, payload),
    );
  }

  Future<AppFailure?> draftResult(Map<String, Object?> payload) {
    return _mutateSelected(
      (String orderId) => _repository.draftResult(orderId, payload),
    );
  }

  Future<AppFailure?> finalizeResult(
    RadiologyResult result,
    Map<String, Object?> payload,
  ) {
    return _mutate(
      () => _repository.finalizeResult(result.effectiveDisplayId, payload),
    );
  }

  Future<AppFailure?> requestFinalization(
    RadiologyResult result,
    Map<String, Object?> payload,
  ) {
    return _mutate(
      () => _repository.requestFinalization(result.effectiveDisplayId, payload),
    );
  }

  Future<AppFailure?> attestFinalization(
    RadiologyResult result,
    Map<String, Object?> payload,
  ) {
    return _mutate(
      () => _repository.attestFinalization(result.effectiveDisplayId, payload),
    );
  }

  Future<AppFailure?> addendumResult(
    RadiologyResult result,
    Map<String, Object?> payload,
  ) {
    return _mutate(
      () => _repository.addendumResult(result.effectiveDisplayId, payload),
    );
  }

  Future<AppFailure?> syncStudyToPacs(
    ImagingStudy study,
    Map<String, Object?> payload,
  ) {
    return _mutate(
      () => _repository.syncStudyToPacs(study.effectiveDisplayId, payload),
    );
  }

  Future<AppFailure?> uploadStudyAssets({
    required ImagingStudy study,
    required List<StudyAssetUploadRequest> uploads,
  }) async {
    for (final StudyAssetUploadRequest upload in uploads) {
      final Result<StudyAssetUploadSession> initResult = await _repository
          .initStudyAssetUpload(study.effectiveDisplayId, <String, Object?>{
            'file_name': upload.fileName,
            'content_type': upload.contentType,
            'size_bytes': upload.sizeBytes,
          });
      final StudyAssetUploadSession? session = initResult.when(
        success: (StudyAssetUploadSession value) => value,
        failure: (_) => null,
      );
      if (session == null) {
        return initResult.when(
          success: (_) => null,
          failure: (AppFailure failure) => failure,
        );
      }

      final AppFailure? commitFailure = await _mutate(
        () => _repository
            .commitStudyAssetUpload(study.effectiveDisplayId, <String, Object?>{
              'storage_key': session.storageKey,
              'file_name': upload.caption?.trim().isNotEmpty == true
                  ? upload.caption!.trim()
                  : upload.fileName,
              'content_type': upload.contentType,
              'upload_token': session.uploadToken,
            }),
      );
      if (commitFailure != null) {
        return commitFailure;
      }
    }
    return null;
  }

  Future<AppFailure?> deleteStudyAsset(ImagingAsset asset) async {
    final RadiologyWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(current.copyWith(isMutating: true, clearLastFailure: true));
    final Result<void> result = await _repository.deleteStudyAsset(
      asset.effectiveDisplayId,
    );
    return result.when(
      success: (_) async {
        final String? orderId =
            current.selectedWorkflow?.order.effectiveDisplayId;
        if (orderId != null) {
          final Result<RadiologyWorkflow> workflowResult = await _repository
              .getWorkflow(orderId);
          workflowResult.when(
            success: (RadiologyWorkflow workflow) {
              final RadiologyWorkspaceState? latest = _currentState;
              if (latest != null) {
                _emit(
                  latest.copyWith(
                    selectedWorkflow: workflow,
                    orders: _replaceOrder(latest.orders, workflow.order),
                    isMutating: false,
                  ),
                );
              }
            },
            failure: (_) {
              final RadiologyWorkspaceState? latest = _currentState;
              if (latest != null) {
                _emit(latest.copyWith(isMutating: false));
              }
            },
          );
        } else {
          final RadiologyWorkspaceState? latest = _currentState;
          if (latest != null) {
            _emit(latest.copyWith(isMutating: false));
          }
        }
        return null;
      },
      failure: (AppFailure failure) {
        final RadiologyWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(isMutating: false, lastFailure: failure));
        }
        return failure;
      },
    );
  }

  Future<Result<RadiologyWorkspaceState>> _loadInitialState() async {
    const RadiologyWorkspaceQuery query = RadiologyWorkspaceQuery();
    final Result<RadiologyReferenceData> referencesResult = await _repository
        .getReferenceData();
    final Result<RadiologyWorkbench> workbenchResult = await _repository
        .getWorkbench(query);
    final Result<List<RadiologyEquipmentRecord>> equipmentResult =
        await _repository.listEquipmentRecords();

    return workbenchResult.when(
      success: (RadiologyWorkbench workbench) async {
        RadiologyWorkflow? selectedWorkflow;
        if (workbench.orders.items.isNotEmpty) {
          final Result<RadiologyWorkflow> detailResult = await _repository
              .getWorkflow(workbench.orders.items.first.effectiveDisplayId);
          selectedWorkflow = detailResult.when(
            success: (RadiologyWorkflow workflow) => workflow,
            failure: (_) => null,
          );
        }

        return Result<RadiologyWorkspaceState>.success(
          RadiologyWorkspaceState(
            orders: selectedWorkflow == null
                ? workbench.orders
                : _replaceOrder(workbench.orders, selectedWorkflow.order),
            summary: workbench.summary,
            references: referencesResult.when(
              success: (RadiologyReferenceData references) => references,
              failure: (_) => RadiologyReferenceData.empty,
            ),
            query: query,
            equipmentRecords: equipmentResult.when(
              success: (List<RadiologyEquipmentRecord> records) => records,
              failure: (_) => const <RadiologyEquipmentRecord>[],
            ),
            selectedWorkflow: selectedWorkflow,
            lastFailure: referencesResult.when(
              success: (_) => null,
              failure: (AppFailure failure) => failure,
            ),
          ),
        );
      },
      failure: (AppFailure failure) =>
          Result<RadiologyWorkspaceState>.failure(failure),
    );
  }

  void _startSync() {
    _syncTimer ??= Timer.periodic(_syncInterval, (_) {
      unawaited(_syncVisibleData());
    });
  }

  Future<AppFailure?> _syncVisibleData({bool showLoading = false}) async {
    final RadiologyWorkspaceState? current = _currentState;
    if (current == null || _isSyncing || current.isMutating) {
      return null;
    }

    _isSyncing = true;
    if (showLoading) {
      _emit(
        current.copyWith(
          isRefreshing: true,
          isRefreshingDetail: current.selectedWorkflow != null,
          clearLastFailure: true,
        ),
      );
    }

    try {
      final AppFailure? failure = await _refreshWorkbench(
        showLoading: showLoading,
      );
      if (failure != null) {
        return failure;
      }

      final RadiologyWorkflow? selected = _currentState?.selectedWorkflow;
      if (selected != null) {
        final Result<RadiologyWorkflow> detailResult = await _repository
            .getWorkflow(selected.order.effectiveDisplayId);
        detailResult.when(
          success: (RadiologyWorkflow workflow) {
            final RadiologyWorkspaceState? latest = _currentState;
            if (latest != null) {
              _emit(
                latest.copyWith(
                  selectedWorkflow: workflow,
                  orders: _replaceOrder(latest.orders, workflow.order),
                ),
              );
            }
          },
          failure: (_) {},
        );
      }

      return null;
    } finally {
      final RadiologyWorkspaceState? latest = _currentState;
      if (showLoading && latest != null) {
        _emit(latest.copyWith(isRefreshing: false, isRefreshingDetail: false));
      }
      _isSyncing = false;
    }
  }

  Future<AppFailure?> _refreshWorkbench({required bool showLoading}) async {
    final RadiologyWorkspaceState? current = _currentState;
    if (current == null) {
      return null;
    }

    final Result<RadiologyWorkbench> result = await _repository.getWorkbench(
      current.query,
    );
    return result.when(
      success: (RadiologyWorkbench workbench) {
        final RadiologyWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              orders: workbench.orders,
              summary: workbench.summary,
              selectedWorkflow: _selectedAfterRefresh(
                workbench.orders,
                latest.selectedWorkflow,
              ),
              isRefreshing: false,
            ),
          );
        }
        return null;
      },
      failure: (AppFailure failure) {
        final RadiologyWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(isRefreshing: false, lastFailure: failure));
        }
        return failure;
      },
    );
  }

  Future<AppFailure?> _refreshEquipmentRecords({String? search}) async {
    final Result<List<RadiologyEquipmentRecord>> equipmentResult =
        await _repository.listEquipmentRecords(search: search);
    AppFailure? failure;
    List<RadiologyEquipmentRecord>? equipment;

    equipmentResult.when(
      success: (List<RadiologyEquipmentRecord> value) => equipment = value,
      failure: (AppFailure value) => failure ??= value,
    );

    final RadiologyWorkspaceState? latest = _currentState;
    if (latest != null) {
      _emit(
        latest.copyWith(
          equipmentRecords: equipment ?? latest.equipmentRecords,
          lastFailure: failure,
          clearLastFailure: failure == null,
        ),
      );
    }
    return failure;
  }

  Future<AppFailure?> _mutateSelected(
    Future<Result<RadiologyWorkflow>> Function(String orderId) submit,
  ) async {
    final RadiologyWorkspaceState? current = _currentState;
    final RadiologyOrder? selected = current?.selectedWorkflow?.order;
    if (current == null || selected == null) {
      return AppFailure.validation();
    }

    return _mutate(() => submit(selected.effectiveDisplayId));
  }

  Future<AppFailure?> _mutate(
    Future<Result<RadiologyWorkflow>> Function() submit,
  ) async {
    final RadiologyWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(current.copyWith(isMutating: true, clearLastFailure: true));
    final Result<RadiologyWorkflow> result = await submit();
    return result.when(
      success: (RadiologyWorkflow workflow) async {
        final RadiologyWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              selectedWorkflow: workflow,
              orders: _replaceOrder(latest.orders, workflow.order),
              isMutating: false,
            ),
          );
        }
        await _refreshWorkbench(showLoading: false);
        return null;
      },
      failure: (AppFailure failure) {
        final RadiologyWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(isMutating: false, lastFailure: failure));
        }
        return failure;
      },
    );
  }

  RadiologyWorkflow? _selectedAfterRefresh(
    AppPage<RadiologyOrder> page,
    RadiologyWorkflow? selected,
  ) {
    if (selected == null) {
      return null;
    }
    for (final RadiologyOrder item in page.items) {
      if (_isSameOrder(item, selected.order)) {
        return selected;
      }
    }
    return selected;
  }

  AppPage<RadiologyOrder> _replaceOrder(
    AppPage<RadiologyOrder> page,
    RadiologyOrder replacement,
  ) {
    var replaced = false;
    final List<RadiologyOrder> items = page.items
        .map((RadiologyOrder item) {
          if (_isSameOrder(item, replacement)) {
            replaced = true;
            return replacement;
          }
          return item;
        })
        .toList(growable: true);

    if (!replaced) {
      items.insert(0, replacement);
    }

    return AppPage<RadiologyOrder>(
      items: items,
      request: page.request,
      totalItemCount: page.totalItemCount == null
          ? null
          : replaced
          ? page.totalItemCount
          : page.totalItemCount! + 1,
    );
  }

  bool _isSameOrder(RadiologyOrder left, RadiologyOrder right) {
    return left.id == right.id ||
        (left.displayId != null && left.displayId == right.displayId);
  }

  RadiologyWorkspaceState? get _currentState {
    final Result<RadiologyWorkspaceState>? currentResult = state.asData?.value;
    return switch (currentResult) {
      ResultSuccess<RadiologyWorkspaceState>(value: final value) => value,
      _ => null,
    };
  }

  void _emit(RadiologyWorkspaceState nextState) {
    state = AsyncData<Result<RadiologyWorkspaceState>>(
      Result<RadiologyWorkspaceState>.success(nextState),
    );
  }

  List<RadiologyCatalogTest> _mergeCatalogOfferingUpdate(
    List<RadiologyCatalogTest> items,
    RadiologyCatalogTest updated,
    String requestId,
  ) {
    final String normalizedRequestId = requestId.trim();
    var replaced = false;
    final List<RadiologyCatalogTest> merged = <RadiologyCatalogTest>[];
    for (final RadiologyCatalogTest item in items) {
      if (_catalogItemMatchesRequest(item, updated, normalizedRequestId)) {
        replaced = true;
        merged.add(updated.copyWith(isOfferedAtFacility: true));
      } else {
        merged.add(item);
      }
    }
    if (!replaced) {
      merged.add(updated.copyWith(isOfferedAtFacility: true));
    }
    return merged;
  }

  bool _catalogItemMatchesRequest(
    RadiologyCatalogTest item,
    RadiologyCatalogTest updated,
    String requestId,
  ) {
    return item.id == updated.id ||
        item.apiId == updated.apiId ||
        item.apiId == requestId ||
        item.id == requestId;
  }
}
