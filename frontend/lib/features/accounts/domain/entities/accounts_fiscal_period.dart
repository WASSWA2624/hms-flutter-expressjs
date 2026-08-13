import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/shared/data/data.dart';

/// Lifecycle of a fiscal period row
/// (`billing-accounts-finance.md` §§9.3 / 10.3.11).
enum AccountsFiscalPeriodStatus {
  draft('DRAFT'),
  active('ACTIVE'),
  inactive('INACTIVE'),
  archived('ARCHIVED');

  const AccountsFiscalPeriodStatus(this.wireValue);

  final String wireValue;

  static AccountsFiscalPeriodStatus? fromWire(String? value) {
    final String normalized = (value ?? '').trim().toUpperCase();
    for (final AccountsFiscalPeriodStatus status
        in AccountsFiscalPeriodStatus.values) {
      if (status.wireValue == normalized) {
        return status;
      }
    }
    return null;
  }

  /// Transitions the backend accepts; the UI hides everything else.
  Set<AccountsFiscalPeriodStatus> get allowedTransitions {
    return switch (this) {
      AccountsFiscalPeriodStatus.draft => <AccountsFiscalPeriodStatus>{
        AccountsFiscalPeriodStatus.active,
        AccountsFiscalPeriodStatus.archived,
      },
      AccountsFiscalPeriodStatus.active => <AccountsFiscalPeriodStatus>{
        AccountsFiscalPeriodStatus.inactive,
        AccountsFiscalPeriodStatus.archived,
      },
      AccountsFiscalPeriodStatus.inactive => <AccountsFiscalPeriodStatus>{
        AccountsFiscalPeriodStatus.active,
        AccountsFiscalPeriodStatus.archived,
      },
      AccountsFiscalPeriodStatus.archived => <AccountsFiscalPeriodStatus>{
        AccountsFiscalPeriodStatus.active,
      },
    };
  }
}

/// Workflow action posted to
/// `POST /accounts/fiscal-years-and-periods/{id}/{action}`.
enum AccountsFiscalPeriodAction {
  activate('activate'),
  deactivate('deactivate'),
  archive('archive'),
  restore('restore');

  const AccountsFiscalPeriodAction(this.wireValue);

  final String wireValue;
}

/// One row of `Accounts & Finance → Setup & Controls → Fiscal Years & Periods`.
///
/// Records are addressed only by [humanFriendlyId]; the API never returns a
/// raw database identifier for this resource.
@immutable
final class AccountsFiscalPeriod {
  const AccountsFiscalPeriod({
    required this.humanFriendlyId,
    required this.fiscalYear,
    required this.periodNo,
    required this.periodName,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.version,
    this.entityAndFacility,
    this.module,
    this.openDate,
    this.softCloseDate,
    this.closeDate,
    this.lockDate,
    this.reopenedAt,
    this.reopenedBy,
    this.facilityHumanFriendlyId,
    this.notes,
    this.isLocked = false,
    this.createdAt,
    this.updatedAt,
    this.archivedAt,
  });

  final String humanFriendlyId;
  final String fiscalYear;
  final int periodNo;
  final String periodName;
  final DateTime startDate;
  final DateTime endDate;
  final String? entityAndFacility;
  final String? module;
  final DateTime? openDate;
  final DateTime? softCloseDate;
  final DateTime? closeDate;
  final DateTime? lockDate;
  final DateTime? reopenedAt;
  final String? reopenedBy;
  final AccountsFiscalPeriodStatus status;
  final String? facilityHumanFriendlyId;
  final String? notes;
  final bool isLocked;
  final int version;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? archivedAt;

  /// Editable only while draft/active, unlocked, and holding a current version.
  bool get canEdit =>
      !isLocked &&
      (status == AccountsFiscalPeriodStatus.draft ||
          status == AccountsFiscalPeriodStatus.active);

  /// Clone copies the shape of a period into a new unsaved draft.
  bool get canClone => status != AccountsFiscalPeriodStatus.archived;

  bool get canActivate =>
      status.allowedTransitions.contains(AccountsFiscalPeriodStatus.active);

  bool get canDeactivate =>
      status.allowedTransitions.contains(AccountsFiscalPeriodStatus.inactive);

  /// Archiving a locked period would strand posted history behind a soft delete.
  bool get canArchive =>
      !isLocked &&
      status.allowedTransitions.contains(AccountsFiscalPeriodStatus.archived);

  bool get canRestore => status == AccountsFiscalPeriodStatus.archived;

  AccountsFiscalPeriodAction? get toggleAction {
    if (canRestore) {
      return AccountsFiscalPeriodAction.restore;
    }
    if (status == AccountsFiscalPeriodStatus.active) {
      return AccountsFiscalPeriodAction.deactivate;
    }
    if (canActivate) {
      return AccountsFiscalPeriodAction.activate;
    }
    return null;
  }
}

/// Committed query shared by the tab count, table rows, advanced filters,
/// export, print, and URL restoration.
@immutable
final class AccountsFiscalPeriodQuery {
  const AccountsFiscalPeriodQuery({
    this.search = '',
    this.statuses = const <AccountsFiscalPeriodStatus>{},
    this.fiscalYear = '',
    this.module = '',
    this.periodName = '',
    this.facilityId = '',
    this.from,
    this.to,
    this.sortBy = 'start_date',
    this.ascending = false,
    this.pageRequest = const AppPageRequest(),
  });

  final String search;
  final Set<AccountsFiscalPeriodStatus> statuses;
  final String fiscalYear;
  final String module;
  final String periodName;
  final String facilityId;
  final DateTime? from;
  final DateTime? to;
  final String sortBy;
  final bool ascending;
  final AppPageRequest pageRequest;

  bool get hasActiveFilters =>
      statuses.isNotEmpty ||
      fiscalYear.trim().isNotEmpty ||
      module.trim().isNotEmpty ||
      periodName.trim().isNotEmpty ||
      facilityId.trim().isNotEmpty ||
      from != null ||
      to != null;

  bool get isNarrowed => hasActiveFilters || search.trim().isNotEmpty;

  AccountsFiscalPeriodQuery copyWith({
    String? search,
    Set<AccountsFiscalPeriodStatus>? statuses,
    String? fiscalYear,
    String? module,
    String? periodName,
    String? facilityId,
    DateTime? from,
    DateTime? to,
    String? sortBy,
    bool? ascending,
    AppPageRequest? pageRequest,
    bool clearFrom = false,
    bool clearTo = false,
  }) {
    return AccountsFiscalPeriodQuery(
      search: search ?? this.search,
      statuses: statuses ?? this.statuses,
      fiscalYear: fiscalYear ?? this.fiscalYear,
      module: module ?? this.module,
      periodName: periodName ?? this.periodName,
      facilityId: facilityId ?? this.facilityId,
      from: clearFrom ? null : from ?? this.from,
      to: clearTo ? null : to ?? this.to,
      sortBy: sortBy ?? this.sortBy,
      ascending: ascending ?? this.ascending,
      pageRequest: pageRequest ?? this.pageRequest,
    );
  }
}
