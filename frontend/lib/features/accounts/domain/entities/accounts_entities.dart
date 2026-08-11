import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/shared/data/data.dart';

/// Accounts workspace desk sections (`accounts.md` §2).
enum AccountsDeskSection {
  work,
  journals,
  approvals,
  gl,
  ledgers,
  chart,
  books;

  /// Stable `?section=` slug.
  String get sectionQueryValue => name;

  /// Alias for [sectionQueryValue] (table settings keys / URL writers).
  String get routeQueryValue => sectionQueryValue;

  /// Alias for [sectionQueryValue].
  String get slug => sectionQueryValue;

  /// Fallback when other sections are unauthorized.
  static const AccountsDeskSection fallback = AccountsDeskSection.work;

  /// Resolves `section` / `tab` / legacy aliases (`accounts.md` §2).
  static AccountsDeskSection? resolveDeskSlug(String? raw) {
    final String normalized = (raw ?? '').trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    return switch (normalized) {
      'work' || 'all' || 'inbox' => AccountsDeskSection.work,
      'journals' ||
      'journal-entries' ||
      'unposted' ||
      'ready-to-post' =>
        AccountsDeskSection.journals,
      'approvals' || 'approval-required' => AccountsDeskSection.approvals,
      'gl' || 'general-ledger' || 'ledger' => AccountsDeskSection.gl,
      'ledgers' || 'patient-ledgers' => AccountsDeskSection.ledgers,
      'chart' || 'chart-of-accounts' || 'coa' => AccountsDeskSection.chart,
      'books' || 'periods' || 'period-close' || 'close' =>
        AccountsDeskSection.books,
      _ => null,
    };
  }

  static AccountsDeskSection? resolveSlug(String? raw) => resolveDeskSlug(raw);

  static AccountsDeskSection? tryParse(String? raw) => resolveDeskSlug(raw);

  bool get isWorkQueue {
    return this == AccountsDeskSection.work ||
        this == AccountsDeskSection.journals ||
        this == AccountsDeskSection.approvals;
  }
}

enum AccountsWorkItemKind {
  journal,
  approval,
  period,
  account,
  patient,
  other,
}

@immutable
final class AccountsWorkspaceQuery {
  const AccountsWorkspaceQuery({
    this.search = '',
    this.section = AccountsDeskSection.work,
    this.pageRequest = const AppPageRequest(pageSize: 12),
    this.source = '',
    this.status = '',
    this.accountId = '',
    this.patientId = '',
    this.periodId = '',
    this.id = '',
    this.action = '',
    this.from,
    this.to,
  });

  factory AccountsWorkspaceQuery.fromUri(Uri uri) {
    final Map<String, String> params = uri.queryParameters;
    String pick(List<String> keys) {
      for (final String key in keys) {
        final String value = (params[key] ?? '').trim();
        if (value.isNotEmpty) {
          return value;
        }
      }
      return '';
    }

    final String sectionRaw = pick(<String>['section', 'tab', 'queue']);
    final AccountsDeskSection section =
        AccountsDeskSection.resolveDeskSlug(sectionRaw) ??
        AccountsDeskSection.work;

    return AccountsWorkspaceQuery(
      search: pick(<String>['search', 'q']),
      section: section,
      source: pick(<String>['source', 'sourceModule', 'source_module']),
      status: pick(<String>['status']),
      accountId: pick(<String>['accountId', 'account_id', 'account']),
      patientId: pick(<String>['patientId', 'patient_id', 'patient']),
      periodId: pick(<String>['periodId', 'period_id', 'period']),
      id: pick(<String>['id']),
      action: pick(<String>['action']),
      from: DateTime.tryParse(pick(<String>['from'])),
      to: DateTime.tryParse(pick(<String>['to'])),
    );
  }

  final String search;
  final AccountsDeskSection section;
  final AppPageRequest pageRequest;
  final String source;
  final String status;
  final String accountId;
  final String patientId;
  final String periodId;
  final String id;
  final String action;
  final DateTime? from;
  final DateTime? to;

  bool get hasRouteTargeting {
    return section != AccountsDeskSection.work ||
        search.trim().isNotEmpty ||
        source.trim().isNotEmpty ||
        status.trim().isNotEmpty ||
        accountId.trim().isNotEmpty ||
        patientId.trim().isNotEmpty ||
        periodId.trim().isNotEmpty ||
        id.trim().isNotEmpty ||
        action.trim().isNotEmpty ||
        from != null ||
        to != null;
  }

  String get signature =>
      '$search|${section.name}|$source|$status|$accountId|$patientId|$periodId|$id|$action';

  bool get hasActiveFilters {
    return source.trim().isNotEmpty ||
        status.trim().isNotEmpty ||
        accountId.trim().isNotEmpty ||
        patientId.trim().isNotEmpty ||
        periodId.trim().isNotEmpty ||
        from != null ||
        to != null;
  }

  AccountsWorkspaceQuery copyWith({
    String? search,
    AccountsDeskSection? section,
    AppPageRequest? pageRequest,
    String? source,
    String? status,
    String? accountId,
    String? patientId,
    String? periodId,
    String? id,
    String? action,
    DateTime? from,
    DateTime? to,
    bool clearFrom = false,
    bool clearTo = false,
    bool clearStatus = false,
    bool clearSource = false,
    bool clearAccountId = false,
    bool clearPatientId = false,
    bool clearPeriodId = false,
    bool clearId = false,
  }) {
    return AccountsWorkspaceQuery(
      search: search ?? this.search,
      section: section ?? this.section,
      pageRequest: pageRequest ?? this.pageRequest,
      source: clearSource ? '' : source ?? this.source,
      status: clearStatus ? '' : status ?? this.status,
      accountId: clearAccountId ? '' : accountId ?? this.accountId,
      patientId: clearPatientId ? '' : patientId ?? this.patientId,
      periodId: clearPeriodId ? '' : periodId ?? this.periodId,
      id: clearId ? '' : id ?? this.id,
      action: action ?? this.action,
      from: clearFrom ? null : from ?? this.from,
      to: clearTo ? null : to ?? this.to,
    );
  }
}

@immutable
final class AccountsSummary {
  const AccountsSummary({
    this.openWork = 0,
    this.toPost = 0,
    this.needApproval = 0,
    this.glActivity = 0,
    this.ledgersWithBalance = 0,
    this.chartActive = 0,
    this.openPeriods = 0,
  });

  final int openWork;
  final int toPost;
  final int needApproval;
  final int glActivity;
  final int ledgersWithBalance;
  final int chartActive;
  final int openPeriods;

  /// Alias used by mutation applier / legacy callers.
  int get approvals => needApproval;

  int get openWorkCount => openWork;
  int get draftsCount => toPost;
  int get pendingApprovalsCount => needApproval;
  int get glWithActivityCount => glActivity;
  int get patientLedgersCount => ledgersWithBalance;
  int get chartActiveCount => chartActive;
  int get openPeriodsCount => openPeriods;

  int get workloadCount => openWork;

  int countFor(AccountsDeskSection section) {
    return switch (section) {
      AccountsDeskSection.work => openWork,
      AccountsDeskSection.journals => toPost,
      AccountsDeskSection.approvals => needApproval,
      AccountsDeskSection.gl => glActivity,
      AccountsDeskSection.ledgers => ledgersWithBalance,
      AccountsDeskSection.chart => chartActive,
      AccountsDeskSection.books => openPeriods,
    };
  }

  AccountsSummary copyWith({
    int? openWork,
    int? toPost,
    int? needApproval,
    int? glActivity,
    int? ledgersWithBalance,
    int? chartActive,
    int? openPeriods,
    int? approvals,
  }) {
    return AccountsSummary(
      openWork: openWork ?? this.openWork,
      toPost: toPost ?? this.toPost,
      needApproval: approvals ?? needApproval ?? this.needApproval,
      glActivity: glActivity ?? this.glActivity,
      ledgersWithBalance: ledgersWithBalance ?? this.ledgersWithBalance,
      chartActive: chartActive ?? this.chartActive,
      openPeriods: openPeriods ?? this.openPeriods,
    );
  }
}

/// Compatibility alias for [AccountsSummary].
typedef AccountsWorkspaceSummary = AccountsSummary;

@immutable
final class AccountsWorkItem {
  const AccountsWorkItem({
    required this.id,
    required this.kind,
    this.displayId,
    this.journalDisplayId,
    this.accountDisplayId,
    this.patientDisplayId,
    this.patientDisplayName,
    this.sourceLabel,
    this.sourceModule,
    this.periodLabel,
    this.status,
    this.amount = 0,
    this.currency,
    this.timelineAt,
    this.accountId,
    this.patientId,
    this.periodId,
    this.requestType,
    this.reference,
    this.requestReason,
    this.requestedByDisplayId,
    this.canApproveFlag,
    this.canPostFlag,
    this.canReverseFlag,
    this.canVoidFlag,
    this.canCloseFlag,
    this.canOpenGlFlag,
    this.canOpenLedgerFlag,
    this.lines = const <AccountsJournalLineDraft>[],
  });

  final String id;
  final AccountsWorkItemKind kind;
  final String? displayId;
  final String? journalDisplayId;
  final String? accountDisplayId;
  final String? patientDisplayId;
  final String? patientDisplayName;
  final String? sourceLabel;
  final String? sourceModule;
  final String? periodLabel;
  final String? status;
  final num amount;
  final String? currency;
  final DateTime? timelineAt;
  final String? accountId;
  final String? patientId;
  final String? periodId;
  final String? requestType;
  final String? reference;
  final String? requestReason;
  final String? requestedByDisplayId;
  final bool? canApproveFlag;
  final bool? canPostFlag;
  final bool? canReverseFlag;
  final bool? canVoidFlag;
  final bool? canCloseFlag;
  final bool? canOpenGlFlag;
  final bool? canOpenLedgerFlag;
  final List<AccountsJournalLineDraft> lines;

  String get _normalizedStatus => (status ?? '').trim().toUpperCase();

  String get effectiveDisplayId =>
      _accountsPublicDisplayId(displayId) ??
      _accountsPublicDisplayId(journalDisplayId) ??
      _accountsPublicDisplayId(accountDisplayId) ??
      '—';

  String get journalNumber =>
      _accountsPublicDisplayId(journalDisplayId) ??
      _accountsPublicDisplayId(displayId) ??
      '—';

  String get source => sourceLabel ?? sourceModule ?? '';

  String get accountLabel => _accountsPublicDisplayId(accountDisplayId) ?? '—';

  /// Alias used by Need approval optional columns.
  String? get approvalType => requestType;

  bool get isJournal => kind == AccountsWorkItemKind.journal;

  bool get isApproval => kind == AccountsWorkItemKind.approval;

  bool get isPeriod => kind == AccountsWorkItemKind.period;

  bool get canApprove {
    if (canApproveFlag != null) {
      return canApproveFlag!;
    }
    return isApproval && _normalizedStatus == 'PENDING';
  }

  bool get canApproveOrReject => canApprove;

  bool get canPost {
    if (canPostFlag != null) {
      return canPostFlag!;
    }
    return isJournal &&
        (_normalizedStatus == 'DRAFT' ||
            _normalizedStatus == 'READY' ||
            _normalizedStatus == 'UNPOSTED');
  }

  bool get canReverse {
    if (canReverseFlag != null) {
      return canReverseFlag!;
    }
    return isJournal && _normalizedStatus == 'POSTED';
  }

  bool get canVoid {
    if (canVoidFlag != null) {
      return canVoidFlag!;
    }
    return isJournal &&
        (_normalizedStatus == 'DRAFT' || _normalizedStatus == 'POSTED');
  }

  bool get canClose {
    if (canCloseFlag != null) {
      return canCloseFlag!;
    }
    return isPeriod &&
        (_normalizedStatus == 'OPEN' || _normalizedStatus == 'OVERDUE');
  }

  bool get canOpenGl {
    if (canOpenGlFlag != null) {
      return canOpenGlFlag!;
    }
    return (accountId ?? '').trim().isNotEmpty ||
        kind == AccountsWorkItemKind.account;
  }

  bool get canOpenLedger {
    if (canOpenLedgerFlag != null) {
      return canOpenLedgerFlag!;
    }
    return (patientId ?? '').trim().isNotEmpty ||
        kind == AccountsWorkItemKind.patient;
  }
}

@immutable
final class AccountsWorkspaceOverview {
  const AccountsWorkspaceOverview({
    this.summary = const AccountsSummary(),
    this.generatedAt,
  });

  final AccountsSummary summary;
  final DateTime? generatedAt;

  AccountsWorkspaceOverview copyWith({
    AccountsSummary? summary,
    DateTime? generatedAt,
  }) {
    return AccountsWorkspaceOverview(
      summary: summary ?? this.summary,
      generatedAt: generatedAt ?? this.generatedAt,
    );
  }
}

@immutable
final class AccountsWorkspaceState {
  const AccountsWorkspaceState({
    required this.query,
    required this.overview,
    required this.workItems,
    this.selectedItem,
    this.lastFailure,
    this.isRefreshing = false,
    this.isSaving = false,
    this.lastActionPendingApproval = false,
  });

  final AccountsWorkspaceQuery query;
  final AccountsWorkspaceOverview overview;
  final AppPage<AccountsWorkItem> workItems;
  final AccountsWorkItem? selectedItem;
  final Object? lastFailure;
  final bool isRefreshing;
  final bool isSaving;
  final bool lastActionPendingApproval;

  int get workloadCount => overview.summary.workloadCount;

  AccountsWorkspaceState copyWith({
    AccountsWorkspaceQuery? query,
    AccountsWorkspaceOverview? overview,
    AppPage<AccountsWorkItem>? workItems,
    AccountsWorkItem? selectedItem,
    Object? lastFailure,
    bool? isRefreshing,
    bool? isSaving,
    bool? lastActionPendingApproval,
    bool clearSelectedItem = false,
    bool clearLastFailure = false,
  }) {
    return AccountsWorkspaceState(
      query: query ?? this.query,
      overview: overview ?? this.overview,
      workItems: workItems ?? this.workItems,
      selectedItem: clearSelectedItem
          ? null
          : selectedItem ?? this.selectedItem,
      lastFailure: clearLastFailure ? null : lastFailure ?? this.lastFailure,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isSaving: isSaving ?? this.isSaving,
      lastActionPendingApproval:
          lastActionPendingApproval ?? this.lastActionPendingApproval,
    );
  }
}

@immutable
final class AccountsJournalLineDraft {
  const AccountsJournalLineDraft({
    required this.accountId,
    this.debit = 0,
    this.credit = 0,
    this.memo,
  });

  final String accountId;
  final num debit;
  final num credit;
  final String? memo;
}

@immutable
final class AccountsJournalDraft {
  const AccountsJournalDraft({
    required this.date,
    this.periodId,
    this.periodLabel,
    this.source,
    this.lines = const <AccountsJournalLineDraft>[],
    this.notes,
  });

  final DateTime date;
  final String? periodId;
  final String? periodLabel;
  final String? source;
  final List<AccountsJournalLineDraft> lines;
  final String? notes;
}

@immutable
final class AccountsNotesDraft {
  const AccountsNotesDraft({this.notes});

  final String? notes;
}

@immutable
final class AccountsReasonDraft {
  const AccountsReasonDraft({required this.reason, this.notes});

  final String reason;
  final String? notes;
}

@immutable
final class AccountsApprovalDecisionDraft {
  const AccountsApprovalDecisionDraft({this.notes, this.reason});

  final String? notes;
  final String? reason;
}

@immutable
final class AccountsMutationResult {
  const AccountsMutationResult({
    this.item,
    this.message,
    this.approvalRequired = false,
  });

  final AccountsWorkItem? item;
  final String? message;
  final bool approvalRequired;
}

// --- Patient ledgers (accounts.md §4.5) ---

enum AccountsClearanceState {
  cleared,
  partial,
  outstanding;

  static AccountsClearanceState fromBalance({
    required num invoiced,
    required num paid,
    required num balance,
  }) {
    if (balance <= 0) {
      return AccountsClearanceState.cleared;
    }
    if (paid > 0 && balance > 0) {
      return AccountsClearanceState.partial;
    }
    return AccountsClearanceState.outstanding;
  }

  static AccountsClearanceState? fromServer(String? value) {
    final String normalized = (value ?? '').trim().toUpperCase();
    return switch (normalized) {
      'CLEARED' => AccountsClearanceState.cleared,
      'PARTIAL' || 'PARTIALLY_PAID' => AccountsClearanceState.partial,
      'OUTSTANDING' || 'BALANCE' || 'AWAITING_PAYMENT' =>
        AccountsClearanceState.outstanding,
      _ => null,
    };
  }

  String get serverValue {
    return switch (this) {
      AccountsClearanceState.cleared => 'CLEARED',
      AccountsClearanceState.partial => 'PARTIAL',
      AccountsClearanceState.outstanding => 'OUTSTANDING',
    };
  }
}

@immutable
final class AccountsPatientBalance {
  const AccountsPatientBalance({
    required this.patientId,
    this.patientDisplayId,
    this.patientDisplayName,
    this.invoiced = 0,
    this.paid = 0,
    this.balance = 0,
    this.currency,
    this.clearance = AccountsClearanceState.outstanding,
    this.updatedAt,
  });

  final String patientId;
  final String? patientDisplayId;
  final String? patientDisplayName;
  final num invoiced;
  final num paid;
  final num balance;
  final String? currency;
  final AccountsClearanceState clearance;
  final DateTime? updatedAt;

  bool get hasBalance => balance > 0;

  String get displayLabel {
    return accountsPatientBalancePublicLabel(this);
  }
}

/// Friendly patient label — never raw UUID (accounts.md §19).
String accountsPatientBalancePublicLabel(AccountsPatientBalance row) {
  final String? name = _accountsPublicDisplayId(row.patientDisplayName);
  final String? mrn =
      _accountsPublicDisplayId(row.patientDisplayId) ??
      _accountsPublicDisplayId(row.patientId);
  if (name != null && mrn != null && name != mrn) {
    return '$name ($mrn)';
  }
  return name ?? mrn ?? '—';
}

@immutable
final class AccountsPatientLedgerQuery {
  const AccountsPatientLedgerQuery({
    this.search = '',
    this.patientId = '',
    this.clearance,
    this.pageRequest = const AppPageRequest(
      pageSize: AppPageRequest.maxPageSize,
    ),
  });

  final String search;
  final String patientId;
  final AccountsClearanceState? clearance;
  final AppPageRequest pageRequest;
}

@immutable
final class AccountsPatientLedgerSummary {
  const AccountsPatientLedgerSummary({
    this.totalInvoiced = 0,
    this.netPaid = 0,
    this.balanceDue = 0,
  });

  final num totalInvoiced;
  final num netPaid;
  final num balanceDue;
}

@immutable
final class AccountsPatientLedgerEntry {
  const AccountsPatientLedgerEntry({
    required this.id,
    this.kind = '',
    this.action,
    this.status,
    this.displayId,
    this.amount = 0,
    this.currency,
    this.timelineAt,
  });

  final String id;
  final String kind;
  final String? action;
  final String? status;
  final String? displayId;
  final num amount;
  final String? currency;
  final DateTime? timelineAt;
}

@immutable
final class AccountsPatientLedger {
  const AccountsPatientLedger({
    required this.patientId,
    this.patientDisplayId,
    this.patientDisplayName,
    this.summary = const AccountsPatientLedgerSummary(),
    this.entries = const <AccountsPatientLedgerEntry>[],
  });

  final String patientId;
  final String? patientDisplayId;
  final String? patientDisplayName;
  final AccountsPatientLedgerSummary summary;
  final List<AccountsPatientLedgerEntry> entries;
}

// --- General ledger types (stub panels / later prompts) ---

@immutable
final class AccountsGlAccount {
  const AccountsGlAccount({
    required this.id,
    required this.name,
    this.displayId,
    this.code = '',
    this.type = '',
    this.period = '',
    this.debit = 0,
    this.credit = 0,
    this.balance = 0,
    this.currency = 'UGX',
    this.hasActivity = false,
    this.updatedAt,
  });

  final String id;
  final String? displayId;
  final String code;
  final String name;
  final String type;
  final String period;
  final num debit;
  final num credit;
  final num balance;
  final String currency;
  final bool hasActivity;
  final DateTime? updatedAt;

  String get effectiveId {
    return _accountsPublicDisplayId(displayId) ??
        _accountsPublicDisplayId(code) ??
        _accountsPublicDisplayId(name) ??
        '—';
  }

  String get accountLabel {
    final String? codePart = _accountsPublicDisplayId(code);
    final String? namePart = _accountsPublicDisplayId(name);
    if (codePart == null && namePart == null) {
      return _accountsPublicDisplayId(displayId) ?? '—';
    }
    if (codePart == null) {
      return namePart!;
    }
    if (namePart == null) {
      return codePart;
    }
    return '$codePart · $namePart';
  }
}

@immutable
final class AccountsGlQuery {
  const AccountsGlQuery({
    this.search = '',
    this.accountType = '',
    this.period = '',
    this.hasActivity,
    this.accountId = '',
    this.pageRequest = const AppPageRequest(pageSize: AppPageRequest.maxPageSize),
  });

  final String search;
  final String accountType;
  final String period;
  final bool? hasActivity;
  final String accountId;
  final AppPageRequest pageRequest;

  AccountsGlQuery copyWith({
    String? search,
    String? accountType,
    String? period,
    bool? hasActivity,
    String? accountId,
    AppPageRequest? pageRequest,
    bool clearHasActivity = false,
  }) {
    return AccountsGlQuery(
      search: search ?? this.search,
      accountType: accountType ?? this.accountType,
      period: period ?? this.period,
      hasActivity: clearHasActivity ? null : hasActivity ?? this.hasActivity,
      accountId: accountId ?? this.accountId,
      pageRequest: pageRequest ?? this.pageRequest,
    );
  }
}

@immutable
final class AccountsGlLedgerSummary {
  const AccountsGlLedgerSummary({
    this.debit = 0,
    this.credit = 0,
    this.balance = 0,
  });

  final num debit;
  final num credit;
  final num balance;
}

@immutable
final class AccountsGlLedgerEntry {
  const AccountsGlLedgerEntry({
    required this.id,
    this.journal = '',
    this.reference = '',
    this.memo = '',
    this.debit = 0,
    this.credit = 0,
    this.postedAt,
  });

  final String id;
  final String journal;
  final String reference;
  final String memo;
  final num debit;
  final num credit;
  final DateTime? postedAt;
}

@immutable
final class AccountsGlLedger {
  const AccountsGlLedger({
    required this.account,
    this.summary = const AccountsGlLedgerSummary(),
    this.entries = const <AccountsGlLedgerEntry>[],
  });

  final AccountsGlAccount account;
  final AccountsGlLedgerSummary summary;
  final List<AccountsGlLedgerEntry> entries;
}

// --- Close books / fiscal periods ---

@immutable
final class AccountsPeriodQuery {
  const AccountsPeriodQuery({
    this.search = '',
    this.openOnly = false,
    this.overdueOnly = false,
    this.periodId = '',
    this.pageRequest = const AppPageRequest(pageSize: AppPageRequest.maxPageSize),
  });

  final String search;
  final bool openOnly;
  final bool overdueOnly;
  final String periodId;
  final AppPageRequest pageRequest;

  AccountsPeriodQuery copyWith({
    String? search,
    bool? openOnly,
    bool? overdueOnly,
    String? periodId,
    AppPageRequest? pageRequest,
  }) {
    return AccountsPeriodQuery(
      search: search ?? this.search,
      openOnly: openOnly ?? this.openOnly,
      overdueOnly: overdueOnly ?? this.overdueOnly,
      periodId: periodId ?? this.periodId,
      pageRequest: pageRequest ?? this.pageRequest,
    );
  }
}

@immutable
final class AccountsOpenPeriodDraft {
  const AccountsOpenPeriodDraft({
    required this.label,
    required this.startDate,
    required this.endDate,
    this.notes,
  });

  final String label;
  final DateTime startDate;
  final DateTime endDate;
  final String? notes;
}

@immutable
final class AccountsFiscalPeriod {
  const AccountsFiscalPeriod({
    required this.id,
    required this.label,
    this.displayId,
    this.status = 'OPEN',
    this.openedAt,
    this.closedAt,
    this.startDate,
    this.endDate,
    this.facilityLabel,
    this.openedBy,
    this.closedBy,
    this.unpostedJournalCount = 0,
    this.pendingApprovalsCount = 0,
    this.pendingApprovalId,
    this.notes,
    this.isOverdue = false,
  });

  final String id;
  final String label;
  final String? displayId;
  final String status;
  final DateTime? openedAt;
  final DateTime? closedAt;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? facilityLabel;
  final String? openedBy;
  final String? closedBy;
  final int unpostedJournalCount;
  final int pendingApprovalsCount;
  final String? pendingApprovalId;
  final String? notes;
  final bool isOverdue;

  String get effectiveLabel {
    final String? display = _accountsPublicDisplayId(displayId);
    if (display != null) {
      return display;
    }
    final String? name = _accountsPublicDisplayId(label);
    if (name != null) {
      return name;
    }
    return '—';
  }

  String get _normalizedStatus => status.trim().toUpperCase();

  bool get isOpen =>
      _normalizedStatus == 'OPEN' || _normalizedStatus == 'OVERDUE';

  bool get isPendingApproval =>
      _normalizedStatus == 'PENDING' ||
      _normalizedStatus == 'PENDING_APPROVAL' ||
      _normalizedStatus == 'AWAITING_APPROVAL';

  bool get isClosed =>
      _normalizedStatus == 'CLOSED' || _normalizedStatus == 'COMPLETE';

  bool get canClose => isOpen && !isPendingApproval;

  bool get canApproveClose =>
      isPendingApproval && (pendingApprovalId ?? '').trim().isNotEmpty;

  String get byLabel {
    final String? closed = _accountsPublicDisplayId(closedBy);
    if (closed != null) {
      return closed;
    }
    return _accountsPublicDisplayId(openedBy) ?? '';
  }

  String get publicFacilityLabel =>
      _accountsPublicDisplayId(facilityLabel) ?? '';
}

final RegExp _accountsUuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// Presentation helper — never returns raw UUIDs (accounts.md §19).
String? _accountsPublicDisplayId(String? value) {
  final String normalized = value?.trim() ?? '';
  if (normalized.isEmpty || _accountsUuidPattern.hasMatch(normalized)) {
    return null;
  }
  return normalized;
}
