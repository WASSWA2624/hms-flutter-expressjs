import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/patients/data/repositories/patient_repository_impl.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/domain/repositories/patient_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final patientRegistryControllerProvider =
    AsyncNotifierProvider<
      PatientRegistryController,
      Result<PatientRegistryState>
    >(PatientRegistryController.new);

final class PatientRegistryController
    extends AsyncNotifier<Result<PatientRegistryState>> {
  PatientRepository get _repository => ref.read(patientRepositoryProvider);

  static const Duration _syncInterval = Duration(seconds: 8);

  Timer? _syncTimer;
  bool _isSyncing = false;

  @override
  Future<Result<PatientRegistryState>> build() async {
    ref.onDispose(() {
      _syncTimer?.cancel();
    });
    final Result<PatientRegistryState> result = await _loadInitialState();
    _startVisibleDataSync();
    return result;
  }

  Future<AppFailure?> refresh() async {
    final PatientRegistryState? current = _currentState;
    if (current == null) {
      final Result<PatientRegistryState> result = await _loadInitialState();
      state = AsyncData<Result<PatientRegistryState>>(result);
      return _failureOrNull(result);
    }

    return _syncVisibleData(
      showLoading: true,
      refreshReferenceData: true,
      allowWhileSaving: true,
    );
  }

  Future<AppFailure?> applyQuery(PatientListQuery query) async {
    final PatientRegistryState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        query: query,
        isRefreshingList: true,
        clearLastFailure: true,
      ),
    );

    final Result<AppPage<Patient>> result = await _repository.listPatients(
      query,
    );
    return result.when(
      success: (AppPage<Patient> page) {
        final PatientDetail? selectedDetail = _selectedDetailAfterListRefresh(
          page,
          current.selectedDetail,
        );
        _emit(
          _currentState!.copyWith(
            page: page,
            selectedDetail: selectedDetail,
            isRefreshingList: false,
            clearSelectedDetail: selectedDetail == null,
          ),
        );
        return null;
      },
      failure: (AppFailure failure) {
        _emit(
          _currentState!.copyWith(
            lastFailure: failure,
            isRefreshingList: false,
          ),
        );
        return failure;
      },
    );
  }

  Future<Result<AppPage<Patient>>> loadPatientPage(PatientListQuery query) {
    return _repository.listPatients(query);
  }

  Future<AppFailure?> selectPatient(String patientId) async {
    final PatientRegistryState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(current.copyWith(isRefreshingDetail: true, clearLastFailure: true));

    final Result<PatientDetail> result = await _repository.loadPatientDetail(
      patientId,
    );
    return result.when(
      success: (PatientDetail detail) {
        final PatientRegistryState next = _currentState!.copyWith(
          selectedDetail: detail,
          page: _replacePatientInPage(_currentState!.page, detail.patient),
          isRefreshingDetail: false,
        );
        _emit(next);
        return null;
      },
      failure: (AppFailure failure) {
        _emit(
          _currentState!.copyWith(
            lastFailure: failure,
            isRefreshingDetail: false,
          ),
        );
        return failure;
      },
    );
  }

  void clearSelection() {
    final PatientRegistryState? current = _currentState;
    if (current != null) {
      _emit(current.copyWith(clearSelectedDetail: true));
    }
  }

  Future<AppFailure?> createPatient(Map<String, Object?> payload) async {
    final PatientRegistryState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    final Result<Patient> result = await _repository.createPatient(payload);
    return result.when(
      success: (Patient patient) async {
        final PatientRegistryState latest = _currentState!;
        final bool shouldInsert =
            latest.query.pageRequest.pageIndex == 0 &&
            _patientMatchesQuery(patient, latest.query);
        _emit(
          latest.copyWith(
            page: shouldInsert
                ? _upsertPatientInPage(latest.page, patient, insertOnTop: true)
                : latest.page,
          ),
        );
        await _refreshOverviewOnly();
        _emit(_currentState!.copyWith(isSaving: false));
        return null;
      },
      failure: (AppFailure failure) {
        _emit(_currentState!.copyWith(isSaving: false, lastFailure: failure));
        return failure;
      },
    );
  }

  Future<AppFailure?> updatePatient(
    String patientId,
    Map<String, Object?> payload,
  ) async {
    final PatientRegistryState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    final Result<Patient> result = await _repository.updatePatient(
      patientId,
      payload,
    );
    return result.when(
      success: (Patient patient) async {
        final PatientDetail? selectedDetail = _currentState!.selectedDetail;
        _emit(
          _currentState!.copyWith(
            page: _replacePatientInPage(_currentState!.page, patient),
            selectedDetail: selectedDetail?.copyWith(patient: patient),
          ),
        );
        final AppFailure? detailFailure = selectedDetail == null
            ? null
            : await selectPatient(patient.id);
        _emit(_currentState!.copyWith(isSaving: false));
        return detailFailure;
      },
      failure: (AppFailure failure) {
        _emit(_currentState!.copyWith(isSaving: false, lastFailure: failure));
        return failure;
      },
    );
  }

  Future<AppFailure?> deletePatient(String patientId) async {
    final PatientRegistryState? current = _currentState;
    if (current == null) {
      return refresh();
    }
    final Patient? patient = _findPatientInState(current, patientId);

    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    final Result<PatientMutationResult> result = await _repository
        .deletePatient(patientId);
    return result.when(
      success: (_) async {
        final AppPage<Patient> page = _removePatientFromPage(
          _currentState!.page,
          patientId,
        );
        _emit(
          _currentState!.copyWith(
            page: page,
            overview: _removePatientFromOverview(
              _currentState!.overview,
              patientId,
              patient,
            ),
            isSaving: false,
            clearSelectedDetail: true,
          ),
        );
        await _refreshOverviewOnly();
        return null;
      },
      failure: (AppFailure failure) {
        _emit(_currentState!.copyWith(isSaving: false, lastFailure: failure));
        return failure;
      },
    );
  }

  Future<AppFailure?> createRelatedRecord(
    PatientRelatedResource resource,
    Map<String, Object?> payload,
  ) async {
    return _mutateRelated(
      () => _repository.createRelatedRecord(resource, payload),
    );
  }

  Future<AppFailure?> updateRelatedRecord(
    PatientRelatedResource resource,
    String recordId,
    Map<String, Object?> payload,
  ) async {
    return _mutateRelated(
      () => _repository.updateRelatedRecord(resource, recordId, payload),
    );
  }

  Future<AppFailure?> deleteRelatedRecord(
    PatientRelatedResource resource,
    String recordId,
  ) async {
    return _mutateRelated(
      () => _repository.deleteRelatedRecord(resource, recordId),
    );
  }

  Future<AppFailure?> _mutateRelated(
    Future<Result<void>> Function() action,
  ) async {
    final PatientRegistryState? current = _currentState;
    final PatientDetail? selectedDetail = current?.selectedDetail;
    if (current == null || selectedDetail == null) {
      return null;
    }

    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    final Result<void> result = await action();
    return result.when(
      success: (_) async {
        final AppFailure? detailFailure = await selectPatient(
          selectedDetail.patient.id,
        );
        await _refreshOverviewOnly();
        _emit(_currentState!.copyWith(isSaving: false));
        return detailFailure;
      },
      failure: (AppFailure failure) {
        _emit(_currentState!.copyWith(isSaving: false, lastFailure: failure));
        return failure;
      },
    );
  }

  Future<Result<PatientRegistryState>> _loadInitialState() async {
    final Result<PatientRegistryOverview> overviewResult = await _repository
        .loadOverview();
    final PatientRegistryOverview? overview = _successOrNull(overviewResult);
    if (overview == null) {
      return Result<PatientRegistryState>.failure(
        _failureOrNull(overviewResult)!,
      );
    }

    final Result<PatientReferenceData> referenceResult = await _repository
        .loadReferenceData();
    final PatientReferenceData? referenceData = _successOrNull(referenceResult);
    if (referenceData == null) {
      return Result<PatientRegistryState>.failure(
        _failureOrNull(referenceResult)!,
      );
    }

    const PatientListQuery query = PatientListQuery();
    final Result<AppPage<Patient>> pageResult = await _repository.listPatients(
      query,
    );
    final AppPage<Patient>? page = _successOrNull(pageResult);
    if (page == null) {
      return Result<PatientRegistryState>.failure(_failureOrNull(pageResult)!);
    }

    return Result<PatientRegistryState>.success(
      PatientRegistryState(
        query: query,
        page: page,
        overview: overview,
        referenceData: referenceData,
      ),
    );
  }

  Future<void> _refreshOverviewOnly() async {
    final PatientRegistryState? current = _currentState;
    if (current == null) {
      return;
    }

    final Result<PatientRegistryOverview> result = await _repository
        .loadOverview();
    result.when(
      success: (PatientRegistryOverview overview) {
        final PatientRegistryState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(overview: overview));
        }
      },
      failure: (_) {},
    );
  }

  void _startVisibleDataSync() {
    _syncTimer ??= Timer.periodic(_syncInterval, (_) {
      unawaited(_syncVisibleData());
    });
  }

  Future<AppFailure?> _syncVisibleData({
    bool showLoading = false,
    bool refreshReferenceData = false,
    bool allowWhileSaving = false,
  }) async {
    final PatientRegistryState? current = _currentState;
    if (current == null || _isSyncing) {
      return null;
    }
    if (!allowWhileSaving && current.isSaving) {
      return null;
    }

    _isSyncing = true;
    AppFailure? firstFailure;
    if (showLoading) {
      _emit(
        current.copyWith(
          isRefreshingList: true,
          isRefreshingDetail: current.selectedDetail != null,
          clearLastFailure: true,
        ),
      );
    }

    try {
      final Result<PatientRegistryOverview> overviewResult = await _repository
          .loadOverview();
      overviewResult.when(
        success: (PatientRegistryOverview overview) {
          final PatientRegistryState? latest = _currentState;
          if (latest != null) {
            _emit(latest.copyWith(overview: overview));
          }
        },
        failure: (AppFailure failure) {
          firstFailure ??= failure;
          final PatientRegistryState? latest = _currentState;
          if (showLoading && latest != null) {
            _emit(latest.copyWith(lastFailure: failure));
          }
        },
      );

      if (refreshReferenceData) {
        final Result<PatientReferenceData> referenceResult = await _repository
            .loadReferenceData();
        referenceResult.when(
          success: (PatientReferenceData referenceData) {
            final PatientRegistryState? latest = _currentState;
            if (latest != null) {
              _emit(latest.copyWith(referenceData: referenceData));
            }
          },
          failure: (AppFailure failure) {
            firstFailure ??= failure;
            final PatientRegistryState? latest = _currentState;
            if (showLoading && latest != null) {
              _emit(latest.copyWith(lastFailure: failure));
            }
          },
        );
      }

      final PatientRegistryState? beforeList = _currentState;
      if (beforeList == null) {
        return firstFailure;
      }
      final Result<AppPage<Patient>> pageResult = await _repository
          .listPatients(beforeList.query);
      pageResult.when(
        success: (AppPage<Patient> page) {
          final PatientRegistryState? latest = _currentState;
          if (latest != null) {
            final PatientDetail? selectedDetail =
                _selectedDetailAfterListRefresh(page, latest.selectedDetail);
            _emit(
              latest.copyWith(
                page: page,
                selectedDetail: selectedDetail,
                clearSelectedDetail: selectedDetail == null,
              ),
            );
          }
        },
        failure: (AppFailure failure) {
          firstFailure ??= failure;
          final PatientRegistryState? latest = _currentState;
          if (showLoading && latest != null) {
            _emit(latest.copyWith(lastFailure: failure));
          }
        },
      );

      final PatientDetail? selectedDetail = _currentState?.selectedDetail;
      if (selectedDetail != null) {
        final Result<PatientDetail> detailResult = await _repository
            .loadPatientDetail(selectedDetail.patient.id);
        detailResult.when(
          success: (PatientDetail detail) {
            final PatientRegistryState? latest = _currentState;
            if (latest != null) {
              _emit(
                latest.copyWith(
                  selectedDetail: detail,
                  page: _replacePatientInPage(latest.page, detail.patient),
                ),
              );
            }
          },
          failure: (AppFailure failure) {
            firstFailure ??= failure;
            final PatientRegistryState? latest = _currentState;
            if (showLoading && latest != null) {
              _emit(latest.copyWith(lastFailure: failure));
            }
          },
        );
      }
    } finally {
      final PatientRegistryState? latest = _currentState;
      if (showLoading && latest != null) {
        _emit(
          latest.copyWith(isRefreshingList: false, isRefreshingDetail: false),
        );
      }
      _isSyncing = false;
    }

    return firstFailure;
  }

  PatientDetail? _selectedDetailAfterListRefresh(
    AppPage<Patient> page,
    PatientDetail? selectedDetail,
  ) {
    if (selectedDetail == null) {
      return null;
    }
    final Iterable<Patient> matching = page.items.where(
      (Patient patient) => patient.id == selectedDetail.patient.id,
    );
    if (matching.isEmpty) {
      return selectedDetail;
    }

    return selectedDetail.copyWith(patient: matching.first);
  }

  AppPage<Patient> _replacePatientInPage(
    AppPage<Patient> page,
    Patient patient,
  ) {
    return AppPage<Patient>(
      items: <Patient>[
        for (final Patient item in page.items)
          if (item.id == patient.id) patient else item,
      ],
      request: page.request,
      totalItemCount: page.totalItemCount,
    );
  }

  AppPage<Patient> _upsertPatientInPage(
    AppPage<Patient> page,
    Patient patient, {
    bool insertOnTop = false,
  }) {
    final List<Patient> withoutExisting = page.items
        .where((Patient item) => item.id != patient.id)
        .toList(growable: true);
    final int previousLength = withoutExisting.length;
    if (insertOnTop) {
      withoutExisting.insert(0, patient);
    } else {
      withoutExisting.add(patient);
    }
    final int maxItems = page.request.pageSize;
    final List<Patient> items = withoutExisting.length > maxItems
        ? withoutExisting.take(maxItems).toList(growable: false)
        : withoutExisting.toList(growable: false);
    final bool wasInserted = previousLength == page.items.length;
    final int? total = page.totalItemCount == null
        ? null
        : page.totalItemCount! + (wasInserted ? 1 : 0);

    return AppPage<Patient>(
      items: items,
      request: page.request,
      totalItemCount: total,
    );
  }

  AppPage<Patient> _removePatientFromPage(
    AppPage<Patient> page,
    String patientId,
  ) {
    final List<Patient> items = page.items
        .where((Patient item) => item.id != patientId)
        .toList(growable: false);
    final int? total = page.totalItemCount == null
        ? null
        : (page.totalItemCount! - (page.items.length - items.length)).clamp(
            0,
            page.totalItemCount!,
          );

    return AppPage<Patient>(
      items: items,
      request: page.request,
      totalItemCount: total,
    );
  }

  PatientRegistryOverview _removePatientFromOverview(
    PatientRegistryOverview overview,
    String patientId,
    Patient? patient,
  ) {
    final List<Patient> recentPatients = overview.recentPatients
        .where((Patient item) => item.id != patientId)
        .toList(growable: false);
    final List<Patient> waitingQueuePatients = overview.waitingQueuePatients
        .where((Patient item) => item.id != patientId)
        .toList(growable: false);
    final bool wasInRecent =
        recentPatients.length != overview.recentPatients.length;
    final bool wasInWaitingQueue =
        waitingQueuePatients.length != overview.waitingQueuePatients.length;

    return overview.copyWith(
      totalPatients: wasInRecent
          ? (overview.totalPatients - 1).clamp(0, overview.totalPatients)
          : overview.totalPatients,
      activePatients: wasInRecent && (patient?.isActive ?? false)
          ? (overview.activePatients - 1).clamp(0, overview.activePatients)
          : overview.activePatients,
      waitingQueue: wasInWaitingQueue
          ? (overview.waitingQueue - 1).clamp(0, overview.waitingQueue)
          : overview.waitingQueue,
      recentPatients: recentPatients,
      waitingQueuePatients: waitingQueuePatients,
      duplicates: overview.duplicates
          .where(
            (PatientDuplicateCandidate candidate) =>
                candidate.primaryPatient?.id != patientId &&
                candidate.secondaryPatient?.id != patientId &&
                candidate.candidatePatient?.id != patientId,
          )
          .toList(growable: false),
    );
  }

  Patient? _findPatientInState(PatientRegistryState state, String patientId) {
    final List<Patient> candidates = <Patient>[
      ...state.page.items,
      ...state.overview.recentPatients,
      ...state.overview.waitingQueuePatients,
      if (state.selectedDetail != null) state.selectedDetail!.patient,
    ];

    for (final Patient patient in candidates) {
      if (patient.id == patientId) {
        return patient;
      }
    }

    return null;
  }

  PatientRegistryState? get _currentState {
    final Result<PatientRegistryState>? currentResult = state.asData?.value;
    return switch (currentResult) {
      ResultSuccess<PatientRegistryState>(value: final value) => value,
      _ => null,
    };
  }

  bool _patientMatchesQuery(Patient patient, PatientListQuery query) {
    if (query.isActive != null && patient.isActive != query.isActive) {
      return false;
    }
    if (query.gender != null &&
        patient.gender?.toUpperCase() != query.gender!.toUpperCase()) {
      return false;
    }
    final String patientId = query.patientId.trim().toLowerCase();
    if (patientId.isNotEmpty &&
        !(patient.id.toLowerCase().contains(patientId) ||
            (patient.publicId ?? '').toLowerCase().contains(patientId) ||
            (patient.effectiveIdentifier ?? '').toLowerCase().contains(
              patientId,
            ))) {
      return false;
    }
    final String search = query.search.trim().toLowerCase();
    if (search.isEmpty) {
      return true;
    }

    return <String?>[
      patient.effectiveDisplayName,
      patient.effectiveIdentifier,
      patient.primaryPhone,
      patient.primaryEmail,
      patient.facilityLabel,
      patient.tenantLabel,
    ].any((String? value) {
      return (value ?? '').toLowerCase().contains(search);
    });
  }

  void _emit(PatientRegistryState nextState) {
    state = AsyncData<Result<PatientRegistryState>>(
      Result<PatientRegistryState>.success(nextState),
    );
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
}
