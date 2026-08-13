import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

typedef AccountsJsonMap = Map<String, Object?>;

AccountsJsonMap _expectMap(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return <String, Object?>{
      for (final MapEntry<dynamic, dynamic> entry in value.entries)
        entry.key.toString(): entry.value,
    };
  }
  return const <String, Object?>{};
}

AccountsJsonMap _map(Object? value) => _expectMap(value);

AccountsJsonMap _dataMap(Object? responseData) {
  final AccountsJsonMap response = _map(responseData);
  final AccountsJsonMap data = _map(response['data']);
  return data.isNotEmpty ? data : response;
}

List<AccountsJsonMap> _list(Object? value) {
  if (value is! List) {
    return const <AccountsJsonMap>[];
  }
  return value
      .map(_map)
      .where((AccountsJsonMap item) => item.isNotEmpty)
      .toList(growable: false);
}

String? _string(Object? value) {
  if (value == null) {
    return null;
  }
  final String text = value.toString().trim();
  return text.isEmpty ? null : text;
}

num? _num(Object? value) {
  if (value is num) {
    return value;
  }
  if (value is String) {
    return num.tryParse(value.replaceAll(',', '').trim());
  }
  return null;
}

int? _int(Object? value) {
  final num? number = _num(value);
  return number?.toInt();
}

DateTime? _date(Object? value) {
  if (value is DateTime) {
    return value;
  }
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value.trim());
  }
  return null;
}

bool? _boolOrNull(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final String normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
      return false;
    }
  }
  return null;
}

bool _bool(Object? value, {bool fallback = false}) {
  return _boolOrNull(value) ?? fallback;
}

AccountsJsonMap _withoutEmpty(Map<String, Object?> source) {
  final AccountsJsonMap result = <String, Object?>{};
  source.forEach((String key, Object? value) {
    if (value == null) {
      return;
    }
    if (value is String && value.trim().isEmpty) {
      return;
    }
    if (value is List && value.isEmpty) {
      return;
    }
    result[key] = value;
  });
  return result;
}

AccountsWorkItemKind _kind(String? raw) {
  final String normalized = (raw ?? '').trim().toLowerCase();
  return switch (normalized) {
    'journal' || 'journal_entry' || 'entry' => AccountsWorkItemKind.journal,
    'approval' || 'approval_request' => AccountsWorkItemKind.approval,
    'period' || 'fiscal_period' => AccountsWorkItemKind.period,
    'account' || 'gl_account' => AccountsWorkItemKind.account,
    'patient' || 'patient_ledger' => AccountsWorkItemKind.patient,
    _ => AccountsWorkItemKind.other,
  };
}

final class AccountsWorkspaceOverviewDto {
  const AccountsWorkspaceOverviewDto(this.json);

  final AccountsJsonMap json;

  factory AccountsWorkspaceOverviewDto.fromResponse(Object? responseData) {
    return AccountsWorkspaceOverviewDto(_dataMap(responseData));
  }

  AccountsWorkspaceOverview toEntity() {
    final AccountsJsonMap summary = _map(json['summary']);
    return AccountsWorkspaceOverview(
      summary: AccountsSummary(
        openWork:
            _int(summary['open_work']) ??
            _int(summary['open_work_count']) ??
            _int(summary['openWork']) ??
            0,
        toPost:
            _int(summary['to_post']) ??
            _int(summary['drafts_count']) ??
            _int(summary['toPost']) ??
            0,
        needApproval:
            _int(summary['need_approval']) ??
            _int(summary['pending_approvals_count']) ??
            _int(summary['needApproval']) ??
            0,
        glActivity:
            _int(summary['gl_activity']) ??
            _int(summary['gl_with_activity_count']) ??
            0,
        ledgersWithBalance:
            _int(summary['ledgers_with_balance']) ??
            _int(summary['patient_ledgers_count']) ??
            0,
        chartActive:
            _int(summary['chart_active']) ??
            _int(summary['chart_active_count']) ??
            0,
        invoices:
            _int(summary['invoices']) ??
            _int(summary['invoices_count']) ??
            _int(summary['open_periods']) ??
            _int(summary['open_periods_count']) ??
            0,
        fiscalPeriodsActive:
            _int(summary['fiscal_years_and_periods']) ??
            _int(summary['fiscal_periods_active_count']) ??
            0,
        currencyRatesActive:
            _int(summary['currencies_and_exchange_rates']) ??
            _int(summary['currency_rates_active_count']) ??
            0,
      ),
      generatedAt: _date(json['generated_at']),
    );
  }
}

final class AccountsWorkItemDto {
  const AccountsWorkItemDto(this.json);

  final AccountsJsonMap json;

  AccountsWorkItem toEntity() {
    return AccountsWorkItem(
      id: _string(json['id']) ?? '',
      kind: _kind(_string(json['kind'])),
      displayId: _string(json['display_id']) ?? _string(json['displayId']),
      journalDisplayId:
          _string(json['journal_display_id']) ??
          _string(json['journalDisplayId']) ??
          _string(json['journal_number']),
      accountDisplayId:
          _string(json['account_display_id']) ??
          _string(json['accountDisplayId']),
      patientDisplayId:
          _string(json['patient_display_id']) ??
          _string(json['patientDisplayId']),
      patientDisplayName:
          _string(json['patient_display_name']) ??
          _string(json['patientDisplayName']),
      sourceLabel: _string(json['source_label']) ?? _string(json['sourceLabel']),
      sourceModule:
          _string(json['source_module']) ??
          _string(json['sourceModule']) ??
          _string(json['source']),
      periodLabel: _string(json['period_label']) ?? _string(json['periodLabel']),
      status: _string(json['status']),
      amount: _num(json['amount']) ?? 0,
      currency: _string(json['currency']),
      timelineAt: _date(json['timeline_at']) ?? _date(json['timelineAt']),
      accountId: _string(json['account_id']) ?? _string(json['accountId']),
      patientId: _string(json['patient_id']) ?? _string(json['patientId']),
      periodId: _string(json['period_id']) ?? _string(json['periodId']),
      requestType: _string(json['request_type']) ?? _string(json['requestType']),
      reference: _string(json['reference']),
      requestReason:
          _string(json['request_reason']) ??
          _string(json['requestReason']) ??
          _string(json['reason']),
      requestedByDisplayId:
          _string(json['requested_by_display_id']) ??
          _string(json['requestedByDisplayId']) ??
          _string(json['requested_by']) ??
          _string(json['requestedBy']),
      canApproveFlag: _boolOrNull(json['can_approve']) ??
          _boolOrNull(json['canApprove']),
      canPostFlag: _boolOrNull(json['can_post']) ?? _boolOrNull(json['canPost']),
      canReverseFlag:
          _boolOrNull(json['can_reverse']) ?? _boolOrNull(json['canReverse']),
      canVoidFlag: _boolOrNull(json['can_void']) ?? _boolOrNull(json['canVoid']),
      canCloseFlag:
          _boolOrNull(json['can_close']) ?? _boolOrNull(json['canClose']),
      canOpenGlFlag:
          _boolOrNull(json['can_open_gl']) ?? _boolOrNull(json['canOpenGl']),
      canOpenLedgerFlag: _boolOrNull(json['can_open_ledger']) ??
          _boolOrNull(json['canOpenLedger']),
      lines: _list(json['lines'])
          .map((AccountsJsonMap row) {
            final String accountId =
                _string(row['account_id']) ??
                _string(row['accountId']) ??
                _string(row['account_code']) ??
                _string(row['accountCode']) ??
                '';
            if (accountId.isEmpty) {
              return null;
            }
            return AccountsJournalLineDraft(
              accountId: accountId,
              debit: _num(row['debit']) ?? 0,
              credit: _num(row['credit']) ?? 0,
              memo: _string(row['memo']),
            );
          })
          .whereType<AccountsJournalLineDraft>()
          .toList(growable: false),
    );
  }
}

final class AccountsWorkItemPageDto {
  const AccountsWorkItemPageDto({required this.page});

  final AppPage<AccountsWorkItem> page;

  factory AccountsWorkItemPageDto.fromResponse(
    Object? responseData,
    AppPageRequest request,
  ) {
    final AccountsJsonMap response = _expectMap(responseData);
    final Object? rawData = response['data'];
    final List<AccountsWorkItem> items;
    if (rawData is List) {
      items = _list(rawData)
          .map(AccountsWorkItemDto.new)
          .map((AccountsWorkItemDto dto) => dto.toEntity())
          .where((AccountsWorkItem item) => item.id.isNotEmpty)
          .toList(growable: false);
    } else {
      final AccountsJsonMap data = _dataMap(responseData);
      items = _list(data['items'])
          .map(AccountsWorkItemDto.new)
          .map((AccountsWorkItemDto dto) => dto.toEntity())
          .where((AccountsWorkItem item) => item.id.isNotEmpty)
          .toList(growable: false);
    }

    return AccountsWorkItemPageDto(
      page: AppPage<AccountsWorkItem>(
        items: items,
        request: request,
        totalItemCount:
            _int(_map(response['pagination'])['total']) ??
            _int(_map(_dataMap(responseData)['pagination'])['total']) ??
            items.length,
      ),
    );
  }
}

final class AccountsMutationResultDto {
  const AccountsMutationResultDto(this.json);

  final AccountsJsonMap json;

  factory AccountsMutationResultDto.fromResponse(Object? responseData) {
    return AccountsMutationResultDto(_dataMap(responseData));
  }

  AccountsMutationResult toEntity() {
    final AccountsJsonMap itemJson = _map(json['item']);
    final AccountsJsonMap workItemJson = itemJson.isNotEmpty
        ? itemJson
        : _map(json['work_item']);
    return AccountsMutationResult(
      item: workItemJson.isEmpty
          ? null
          : AccountsWorkItemDto(workItemJson).toEntity(),
      message: _string(json['message']),
      approvalRequired:
          _bool(json['approval_required']) || _bool(json['approvalRequired']),
    );
  }
}

AccountsJsonMap accountsJournalDraftPayload(AccountsJournalDraft draft) {
  return _withoutEmpty(<String, Object?>{
    'date': draft.date.toUtc().toIso8601String(),
    'period_id': draft.periodId,
    'period_label': draft.periodLabel,
    'source': draft.source,
    'notes': draft.notes,
    'lines': <AccountsJsonMap>[
      for (final AccountsJournalLineDraft line in draft.lines)
        _withoutEmpty(<String, Object?>{
          'account_id': line.accountId,
          'debit': line.debit,
          'credit': line.credit,
          'memo': line.memo,
        }),
    ],
  });
}

final class AccountsGlAccountDto {
  const AccountsGlAccountDto(this.json);

  final AccountsJsonMap json;

  AccountsGlAccount toEntity() {
    return AccountsGlAccount(
      id: _string(json['id']) ?? '',
      displayId:
          _string(json['display_id']) ?? _string(json['human_friendly_id']),
      code: _string(json['code']) ?? '',
      name: _string(json['name']) ?? '',
      type: _string(json['type']) ?? _string(json['account_type']) ?? '',
      period: _string(json['period']) ?? '',
      debit: _num(json['debit']) ?? 0,
      credit: _num(json['credit']) ?? 0,
      balance: _num(json['balance']) ?? 0,
      currency: (_string(json['currency']) ?? 'UGX').toUpperCase(),
      hasActivity: _bool(json['has_activity']),
      updatedAt: _date(json['updated_at']),
    );
  }
}

final class AccountsGlAccountPageDto {
  const AccountsGlAccountPageDto({required this.page});

  final AppPage<AccountsGlAccount> page;

  factory AccountsGlAccountPageDto.fromResponse(
    Object? responseData,
    AppPageRequest request,
  ) {
    final AccountsJsonMap response = _expectMap(responseData);
    final List<AccountsGlAccount> items = _list(response['data'])
        .map(AccountsGlAccountDto.new)
        .map((AccountsGlAccountDto dto) => dto.toEntity())
        .where((AccountsGlAccount item) => item.id.isNotEmpty)
        .toList(growable: false);

    return AccountsGlAccountPageDto(
      page: AppPage<AccountsGlAccount>(
        items: items,
        request: request,
        totalItemCount: _int(_map(response['pagination'])['total']),
      ),
    );
  }
}

final class AccountsGlLedgerDto {
  const AccountsGlLedgerDto(this.json);

  final AccountsJsonMap json;

  factory AccountsGlLedgerDto.fromResponse(Object? responseData) {
    return AccountsGlLedgerDto(_dataMap(responseData));
  }

  AccountsGlLedger toEntity() {
    final AccountsGlAccount account = AccountsGlAccountDto(
      _map(json['account']),
    ).toEntity();
    final AccountsJsonMap summary = _map(json['summary']);
    final List<AccountsGlLedgerEntry> entries = _list(json['entries'])
        .map((AccountsJsonMap row) {
          return AccountsGlLedgerEntry(
            id: _string(row['id']) ?? '',
            journal: _string(row['journal']) ?? '',
            reference: _string(row['reference']) ?? '',
            memo: _string(row['memo']) ?? '',
            debit: _num(row['debit']) ?? 0,
            credit: _num(row['credit']) ?? 0,
            postedAt: _date(row['posted_at']),
          );
        })
        .where((AccountsGlLedgerEntry entry) => entry.id.isNotEmpty)
        .toList(growable: false);

    return AccountsGlLedger(
      account: account.id.isEmpty
          ? const AccountsGlAccount(id: 'unknown', name: 'Account')
          : account,
      summary: AccountsGlLedgerSummary(
        debit: _num(summary['debit']) ?? account.debit,
        credit: _num(summary['credit']) ?? account.credit,
        balance: _num(summary['balance']) ?? account.balance,
      ),
      entries: entries,
    );
  }
}

final class AccountsPatientBalanceDto {
  const AccountsPatientBalanceDto(this.json);

  final AccountsJsonMap json;

  AccountsPatientBalance toEntity() {
    final AccountsJsonMap patient = _map(json['patient']);
    final num invoiced = _num(json['invoiced'] ?? json['total_invoiced']) ?? 0;
    final num paid = _num(json['paid'] ?? json['net_paid']) ?? 0;
    final num balance = _num(json['balance'] ?? json['balance_due']) ?? 0;
    return AccountsPatientBalance(
      patientId:
          _string(patient['id']) ??
          _string(json['patient_id']) ??
          '',
      patientDisplayId:
          _string(patient['display_id']) ??
          _string(json['patient_display_id']),
      patientDisplayName:
          _string(patient['display_name']) ??
          _string(json['patient_display_name']),
      invoiced: invoiced,
      paid: paid,
      balance: balance,
      currency: _string(json['currency']),
      clearance:
          AccountsClearanceState.fromServer(_string(json['clearance'])) ??
          AccountsClearanceState.fromBalance(
            invoiced: invoiced,
            paid: paid,
            balance: balance,
          ),
      updatedAt: _date(json['updated_at']),
    );
  }
}

final class AccountsPatientBalancePageDto {
  const AccountsPatientBalancePageDto(this.json, {required this.request});

  final AccountsJsonMap json;
  final AppPageRequest request;

  factory AccountsPatientBalancePageDto.fromResponse(
    Object? responseData,
    AppPageRequest request,
  ) {
    return AccountsPatientBalancePageDto(
      _dataMap(responseData),
      request: request,
    );
  }

  AppPage<AccountsPatientBalance> get page {
    final List<AccountsPatientBalance> items = _list(
      json['items'] ?? json['patient_ledgers'],
    )
        .map(AccountsPatientBalanceDto.new)
        .map((AccountsPatientBalanceDto dto) => dto.toEntity())
        .where((AccountsPatientBalance row) => row.patientId.isNotEmpty)
        .toList(growable: false);
    final AccountsJsonMap pagination = _map(json['pagination']);
    return AppPage<AccountsPatientBalance>(
      items: items,
      request: request,
      totalItemCount: _int(pagination['total']) ?? items.length,
    );
  }
}

final class AccountsPatientLedgerDto {
  const AccountsPatientLedgerDto(this.json);

  final AccountsJsonMap json;

  factory AccountsPatientLedgerDto.fromResponse(Object? responseData) {
    return AccountsPatientLedgerDto(_dataMap(responseData));
  }

  AccountsPatientLedger toEntity() {
    final AccountsJsonMap patient = _map(json['patient']);
    final AccountsJsonMap summary = _map(json['summary']);
    final AccountsJsonMap ledger = _map(json['ledger']);
    final List<AccountsPatientLedgerEntry> entries =
        _list(ledger['items'] ?? json['entries'])
            .map((AccountsJsonMap row) {
              return AccountsPatientLedgerEntry(
                id:
                    _string(row['id']) ??
                    _string(row['display_id']) ??
                    '',
                kind: _string(row['kind'] ?? row['type']) ?? '',
                action: _string(row['action']),
                status: _string(row['status']),
                displayId: _string(row['display_id']),
                amount: _num(row['amount']) ?? 0,
                currency: _string(row['currency']),
                timelineAt: _date(row['timeline_at'] ?? row['posted_at']),
              );
            })
            .where((AccountsPatientLedgerEntry entry) => entry.id.isNotEmpty)
            .toList(growable: false);

    return AccountsPatientLedger(
      patientId:
          _string(patient['id']) ??
          _string(json['patient_id']) ??
          '',
      patientDisplayId: _string(patient['display_id']),
      patientDisplayName: _string(patient['display_name']),
      summary: AccountsPatientLedgerSummary(
        totalInvoiced: _num(summary['total_invoiced']) ?? 0,
        netPaid: _num(summary['net_paid'] ?? summary['total_paid']) ?? 0,
        balanceDue: _num(summary['balance_due']) ?? 0,
      ),
      entries: entries,
    );
  }
}

