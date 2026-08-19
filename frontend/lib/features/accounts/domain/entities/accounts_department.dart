import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/shared/data/data.dart';

/// Lifecycle of a department / cost centre row
/// (`billing-accounts-finance.md` §§9.3 / 10.3).
enum AccountsDepartmentStatus {
  draft('DRAFT'),
  active('ACTIVE'),
  inactive('INACTIVE'),
  archived('ARCHIVED');

  const AccountsDepartmentStatus(this.wireValue);

  final String wireValue;

  static AccountsDepartmentStatus? fromWire(String? value) {
    final String normalized = (value ?? '').trim().toUpperCase();
    for (final AccountsDepartmentStatus status
        in AccountsDepartmentStatus.values) {
      if (status.wireValue == normalized) {
        return status;
      }
    }
    return null;
  }

  /// Transitions the backend accepts; the UI hides everything else.
  Set<AccountsDepartmentStatus> get allowedTransitions {
    return switch (this) {
      AccountsDepartmentStatus.draft => <AccountsDepartmentStatus>{
        AccountsDepartmentStatus.active,
        AccountsDepartmentStatus.archived,
      },
      AccountsDepartmentStatus.active => <AccountsDepartmentStatus>{
        AccountsDepartmentStatus.inactive,
        AccountsDepartmentStatus.archived,
      },
      AccountsDepartmentStatus.inactive => <AccountsDepartmentStatus>{
        AccountsDepartmentStatus.active,
        AccountsDepartmentStatus.archived,
      },
      AccountsDepartmentStatus.archived => <AccountsDepartmentStatus>{
        AccountsDepartmentStatus.active,
      },
    };
  }
}

/// Workflow action posted to
/// `POST /accounts/departments-and-cost-centres/{id}/{action}`.
enum AccountsDepartmentAction {
  activate('activate'),
  deactivate('deactivate'),
  archive('archive'),
  restore('restore');

  const AccountsDepartmentAction(this.wireValue);

  final String wireValue;
}

/// One row of
/// `Accounts & Finance → Setup & Controls → Departments & Cost Centres`.
///
/// The department record itself is owned by tenant/facility setup; this entity
/// carries its finance projection. Records are addressed only by
/// [humanFriendlyId]; the API never returns a raw database identifier.
@immutable
final class AccountsDepartment {
  const AccountsDepartment({
    required this.humanFriendlyId,
    required this.departmentCode,
    required this.departmentName,
    required this.costCentreCode,
    required this.costCentreName,
    required this.status,
    required this.version,
    this.parent,
    this.parentHumanFriendlyId,
    this.facility,
    this.facilityHumanFriendlyId,
    this.manager,
    this.managerHumanFriendlyId,
    this.defaultRevenueAccount,
    this.defaultRevenueAccountHumanFriendlyId,
    this.defaultExpenseAccount,
    this.defaultExpenseAccountHumanFriendlyId,
    this.budgetOwner,
    this.budgetOwnerHumanFriendlyId,
    this.effectiveFrom,
    this.effectiveTo,
    this.createdAt,
    this.updatedAt,
    this.archivedAt,
  });

  final String humanFriendlyId;
  final String departmentCode;
  final String departmentName;
  final String costCentreCode;
  final String costCentreName;
  final String? parent;
  final String? parentHumanFriendlyId;
  final String? facility;
  final String? facilityHumanFriendlyId;
  final String? manager;
  final String? managerHumanFriendlyId;
  final String? defaultRevenueAccount;
  final String? defaultRevenueAccountHumanFriendlyId;
  final String? defaultExpenseAccount;
  final String? defaultExpenseAccountHumanFriendlyId;
  final String? budgetOwner;
  final String? budgetOwnerHumanFriendlyId;
  final DateTime? effectiveFrom;
  final DateTime? effectiveTo;
  final AccountsDepartmentStatus status;
  final int version;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? archivedAt;

  /// Editable only while draft or active and holding a current version.
  bool get canEdit =>
      status == AccountsDepartmentStatus.draft ||
      status == AccountsDepartmentStatus.active;

  /// Clone copies the shape of a department into a new unsaved draft.
  bool get canClone => status != AccountsDepartmentStatus.archived;

  bool get canActivate =>
      status.allowedTransitions.contains(AccountsDepartmentStatus.active);

  bool get canDeactivate =>
      status.allowedTransitions.contains(AccountsDepartmentStatus.inactive);

  /// The backend additionally refuses to archive while live children, units,
  /// or wards still reference the department.
  bool get canArchive =>
      status.allowedTransitions.contains(AccountsDepartmentStatus.archived);

  bool get canRestore => status == AccountsDepartmentStatus.archived;

  AccountsDepartmentAction? get toggleAction {
    if (canRestore) {
      return AccountsDepartmentAction.restore;
    }
    if (status == AccountsDepartmentStatus.active) {
      return AccountsDepartmentAction.deactivate;
    }
    if (canActivate) {
      return AccountsDepartmentAction.activate;
    }
    return null;
  }
}

/// Committed query shared by the tab count, table rows, advanced filters,
/// export, print, and URL restoration.
@immutable
final class AccountsDepartmentQuery {
  const AccountsDepartmentQuery({
    this.search = '',
    this.statuses = const <AccountsDepartmentStatus>{},
    this.departmentCode = '',
    this.departmentName = '',
    this.costCentreCodes = const <String>{},
    this.costCentreName = '',
    this.facilityId = '',
    this.ownerId = '',
    this.revenueAccountId = '',
    this.expenseAccountId = '',
    this.from,
    this.to,
    this.sortBy = 'effective_from',
    this.ascending = false,
    this.pageRequest = const AppPageRequest(),
  });

  final String search;
  final Set<AccountsDepartmentStatus> statuses;
  final String departmentCode;
  final String departmentName;

  /// Hierarchical department / cost centre picker: zero or more cost centres.
  final Set<String> costCentreCodes;
  final String costCentreName;
  final String facilityId;

  /// Owner / assigned user: matched against manager or budget owner.
  final String ownerId;
  final String revenueAccountId;
  final String expenseAccountId;
  final DateTime? from;
  final DateTime? to;
  final String sortBy;
  final bool ascending;
  final AppPageRequest pageRequest;

  bool get hasActiveFilters =>
      statuses.isNotEmpty ||
      departmentCode.trim().isNotEmpty ||
      departmentName.trim().isNotEmpty ||
      costCentreCodes.isNotEmpty ||
      costCentreName.trim().isNotEmpty ||
      facilityId.trim().isNotEmpty ||
      ownerId.trim().isNotEmpty ||
      revenueAccountId.trim().isNotEmpty ||
      expenseAccountId.trim().isNotEmpty ||
      from != null ||
      to != null;

  bool get isNarrowed => hasActiveFilters || search.trim().isNotEmpty;

  AccountsDepartmentQuery copyWith({
    String? search,
    Set<AccountsDepartmentStatus>? statuses,
    String? departmentCode,
    String? departmentName,
    Set<String>? costCentreCodes,
    String? costCentreName,
    String? facilityId,
    String? ownerId,
    String? revenueAccountId,
    String? expenseAccountId,
    DateTime? from,
    DateTime? to,
    String? sortBy,
    bool? ascending,
    AppPageRequest? pageRequest,
    bool clearFrom = false,
    bool clearTo = false,
  }) {
    return AccountsDepartmentQuery(
      search: search ?? this.search,
      statuses: statuses ?? this.statuses,
      departmentCode: departmentCode ?? this.departmentCode,
      departmentName: departmentName ?? this.departmentName,
      costCentreCodes: costCentreCodes ?? this.costCentreCodes,
      costCentreName: costCentreName ?? this.costCentreName,
      facilityId: facilityId ?? this.facilityId,
      ownerId: ownerId ?? this.ownerId,
      revenueAccountId: revenueAccountId ?? this.revenueAccountId,
      expenseAccountId: expenseAccountId ?? this.expenseAccountId,
      from: clearFrom ? null : from ?? this.from,
      to: clearTo ? null : to ?? this.to,
      sortBy: sortBy ?? this.sortBy,
      ascending: ascending ?? this.ascending,
      pageRequest: pageRequest ?? this.pageRequest,
    );
  }
}
