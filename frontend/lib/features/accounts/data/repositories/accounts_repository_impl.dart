import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/features/accounts/data/dtos/accounts_dtos.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/features/accounts/domain/repositories/accounts_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final accountsRepositoryProvider = Provider<AccountsRepository>((Ref ref) {
  return AccountsRepositoryImpl(apiClient: ref.watch(apiClientProvider));
});

final class AccountsRepositoryImpl implements AccountsRepository {
  const AccountsRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<Result<AccountsWorkspaceOverview>> getWorkspace(
    AccountsWorkspaceQuery query,
  ) {
    return _apiClient.get<AccountsWorkspaceOverview>(
      ApiEndpoints.nested(
        HmsApiResource.accounts,
        'workspace',
        const <String>[],
      ),
      queryParameters: _withoutEmpty(<String, Object?>{
        'search': query.search.trim().isEmpty ? null : query.search.trim(),
      }),
      decoder: (Object? data) {
        return AccountsWorkspaceOverviewDto.fromResponse(data).toEntity();
      },
    );
  }

  @override
  Future<Result<AppPage<AccountsWorkItem>>> listWorkItems(
    AccountsWorkspaceQuery query,
  ) {
    final AppPageRequest request = query.pageRequest;
    return _apiClient.get<AppPage<AccountsWorkItem>>(
      ApiEndpoints.nested(
        HmsApiResource.accounts,
        'work-items',
        const <String>[],
      ),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'section': query.section.sectionQueryValue,
        'search': query.search.trim().isEmpty ? null : query.search.trim(),
        'source': query.source.trim().isEmpty ? null : query.source.trim(),
        'status': query.status.trim().isEmpty ? null : query.status.trim(),
        'accountId':
            query.accountId.trim().isEmpty ? null : query.accountId.trim(),
        'periodId':
            query.periodId.trim().isEmpty ? null : query.periodId.trim(),
        'id': query.id.trim().isEmpty ? null : query.id.trim(),
        'from': query.from?.toIso8601String(),
        'to': query.to?.toIso8601String(),
      }),
      decoder: (Object? data) {
        return AccountsWorkItemPageDto.fromResponse(data, request).page;
      },
    );
  }

  @override
  Future<Result<AccountsMutationResult>> createJournal(
    AccountsJournalDraft draft,
  ) {
    return _apiClient.post<AccountsMutationResult>(
      ApiEndpoints.nested(HmsApiResource.accounts, 'journals', const <String>[]),
      data: accountsJournalDraftPayload(draft),
      decoder: (Object? data) {
        return AccountsMutationResultDto.fromResponse(data).toEntity();
      },
    );
  }

  @override
  Future<Result<AccountsMutationResult>> updateJournal(
    String journalId,
    AccountsJournalDraft draft,
  ) {
    return _apiClient.put<AccountsMutationResult>(
      ApiEndpoints.nested(HmsApiResource.accounts, 'journals', <String>[
        journalId,
      ]),
      data: accountsJournalDraftPayload(draft),
      decoder: (Object? data) {
        return AccountsMutationResultDto.fromResponse(data).toEntity();
      },
    );
  }

  @override
  Future<Result<AccountsMutationResult>> postJournal(
    String journalId, {
    String? notes,
  }) {
    return _mutate('journals', journalId, 'post', notes: notes);
  }

  @override
  Future<Result<AccountsMutationResult>> approveRequest(
    String approvalId, {
    String? notes,
  }) {
    return _mutate('approvals', approvalId, 'approve', notes: notes);
  }

  @override
  Future<Result<AccountsMutationResult>> rejectRequest(
    String approvalId, {
    required String reason,
    String? notes,
  }) {
    return _mutate(
      'approvals',
      approvalId,
      'reject',
      notes: notes,
      reason: reason,
    );
  }

  @override
  Future<Result<AccountsMutationResult>> reverseJournal(
    String journalId, {
    required String reason,
    String? notes,
  }) {
    return _mutate(
      'journals',
      journalId,
      'reverse',
      notes: notes,
      reason: reason,
    );
  }

  @override
  Future<Result<AccountsMutationResult>> voidJournal(
    String journalId, {
    required String reason,
    String? notes,
  }) {
    return _mutate('journals', journalId, 'void', notes: notes, reason: reason);
  }

  @override
  Future<Result<AccountsMutationResult>> closePeriod(
    String periodId, {
    String? notes,
  }) {
    return _mutate('periods', periodId, 'close', notes: notes);
  }

  @override
  Future<Result<AppPage<AccountsFiscalPeriod>>> listPeriods(
    AccountsPeriodQuery query, {
    String? facilityId,
  }) {
    final AppPageRequest request = query.pageRequest;
    return _apiClient.get<AppPage<AccountsFiscalPeriod>>(
      ApiEndpoints.nested(
        HmsApiResource.accounts,
        'periods',
        const <String>[],
      ),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'facility_id': facilityId,
        'search': query.search.trim().isEmpty ? null : query.search.trim(),
        'period_id': query.periodId.trim().isEmpty ? null : query.periodId.trim(),
        if (query.openOnly) 'open_only': 'true',
        if (query.overdueOnly) 'overdue_only': 'true',
      }),
      decoder: (Object? data) =>
          AccountsFiscalPeriodPageDto.fromResponse(data, request).page,
    );
  }

  @override
  Future<Result<AccountsFiscalPeriod>> getPeriod(
    String periodId, {
    String? facilityId,
  }) {
    return _apiClient.get<AccountsFiscalPeriod>(
      ApiEndpoints.nested(HmsApiResource.accounts, 'periods', <String>[
        periodId,
      ]),
      queryParameters: _withoutEmpty(<String, Object?>{
        'facility_id': facilityId,
      }),
      decoder: (Object? data) {
        return AccountsFiscalPeriodDto.fromResponse(data).toEntity();
      },
    );
  }

  @override
  Future<Result<AccountsMutationResult>> openPeriod(
    AccountsOpenPeriodDraft draft,
  ) {
    return _apiClient.post<AccountsMutationResult>(
      ApiEndpoints.nested(
        HmsApiResource.accounts,
        'periods',
        const <String>[],
      ),
      data: accountsOpenPeriodDraftPayload(draft),
      decoder: (Object? data) {
        return AccountsMutationResultDto.fromResponse(data).toEntity();
      },
    );
  }

  @override
  Future<Result<AppPage<AccountsGlAccount>>> listGlAccounts(
    AccountsGlQuery query, {
    String? facilityId,
  }) {
    final AppPageRequest request = query.pageRequest;
    return _apiClient.get<AppPage<AccountsGlAccount>>(
      ApiEndpoints.nested(
        HmsApiResource.accounts,
        'gl-accounts',
        const <String>[],
      ),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'facility_id': facilityId,
        'search': query.search.trim().isEmpty ? null : query.search.trim(),
        'account_type': query.accountType.trim().isEmpty
            ? null
            : query.accountType.trim(),
        'period': query.period.trim().isEmpty ? null : query.period.trim(),
        if (query.hasActivity != null)
          'has_activity': query.hasActivity! ? 'true' : 'false',
        'account_id': query.accountId.trim().isEmpty
            ? null
            : query.accountId.trim(),
      }),
      decoder: (Object? data) =>
          AccountsGlAccountPageDto.fromResponse(data, request).page,
    );
  }

  @override
  Future<Result<AccountsGlLedger>> getAccountLedger(
    String accountId, {
    String? facilityId,
  }) {
    return _apiClient.get<AccountsGlLedger>(
      ApiEndpoints.nested(HmsApiResource.accounts, 'gl-accounts', <String>[
        accountId,
        'ledger',
      ]),
      queryParameters: _withoutEmpty(<String, Object?>{
        'facility_id': facilityId,
      }),
      decoder: (Object? data) {
        return AccountsGlLedgerDto.fromResponse(data).toEntity();
      },
    );
  }

  @override
  Future<Result<AppPage<AccountsPatientBalance>>> listPatientLedgers(
    AccountsPatientLedgerQuery query, {
    String? facilityId,
  }) {
    final AppPageRequest request = query.pageRequest;
    return _apiClient.get<AppPage<AccountsPatientBalance>>(
      ApiEndpoints.nested(
        HmsApiResource.accounts,
        'patient-ledgers',
        const <String>[],
      ),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'facility_id': facilityId,
        'search': query.search.trim().isEmpty ? null : query.search.trim(),
        'patient_id': query.patientId.trim().isEmpty
            ? null
            : query.patientId.trim(),
        'clearance': query.clearance?.serverValue,
      }),
      decoder: (Object? data) =>
          AccountsPatientBalancePageDto.fromResponse(data, request).page,
    );
  }

  @override
  Future<Result<AccountsPatientLedger>> getPatientLedger(
    String patientIdentifier, {
    String? facilityId,
  }) {
    return _apiClient.get<AccountsPatientLedger>(
      ApiEndpoints.nested(HmsApiResource.accounts, 'patients', <String>[
        patientIdentifier,
        'ledger',
      ]),
      queryParameters: _withoutEmpty(<String, Object?>{
        'facility_id': facilityId,
      }),
      decoder: (Object? data) {
        return AccountsPatientLedgerDto.fromResponse(data).toEntity();
      },
    );
  }

  Future<Result<AccountsMutationResult>> _mutate(
    String collection,
    String id,
    String action, {
    String? notes,
    String? reason,
  }) {
    return _apiClient.post<AccountsMutationResult>(
      ApiEndpoints.nested(HmsApiResource.accounts, collection, <String>[
        id,
        action,
      ]),
      data: _withoutEmpty(<String, Object?>{'notes': notes, 'reason': reason}),
      decoder: (Object? data) {
        return AccountsMutationResultDto.fromResponse(data).toEntity();
      },
    );
  }

  Map<String, Object?> _withoutEmpty(Map<String, Object?> source) {
    return <String, Object?>{
      for (final MapEntry<String, Object?> entry in source.entries)
        if (entry.value != null &&
            !(entry.value is String && (entry.value! as String).trim().isEmpty))
          entry.key: entry.value,
    };
  }
}
