import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/shared/data/data.dart';

/// Lifecycle of a payment method row
/// (`billing-accounts-finance.md` §§9.3 / 10.3).
enum AccountsPaymentMethodStatus {
  draft('DRAFT'),
  active('ACTIVE'),
  inactive('INACTIVE'),
  archived('ARCHIVED');

  const AccountsPaymentMethodStatus(this.wireValue);

  final String wireValue;

  static AccountsPaymentMethodStatus? fromWire(String? value) {
    final String normalized = (value ?? '').trim().toUpperCase();
    for (final AccountsPaymentMethodStatus status
        in AccountsPaymentMethodStatus.values) {
      if (status.wireValue == normalized) {
        return status;
      }
    }
    return null;
  }

  /// Transitions the backend accepts; the UI hides everything else.
  Set<AccountsPaymentMethodStatus> get allowedTransitions {
    return switch (this) {
      AccountsPaymentMethodStatus.draft => <AccountsPaymentMethodStatus>{
        AccountsPaymentMethodStatus.active,
        AccountsPaymentMethodStatus.archived,
      },
      AccountsPaymentMethodStatus.active => <AccountsPaymentMethodStatus>{
        AccountsPaymentMethodStatus.inactive,
        AccountsPaymentMethodStatus.archived,
      },
      AccountsPaymentMethodStatus.inactive => <AccountsPaymentMethodStatus>{
        AccountsPaymentMethodStatus.active,
        AccountsPaymentMethodStatus.archived,
      },
      AccountsPaymentMethodStatus.archived => <AccountsPaymentMethodStatus>{
        AccountsPaymentMethodStatus.active,
      },
    };
  }
}

/// Canonical tender taxonomy, shared with the payment record.
///
/// This mirrors the backend `PaymentMethodType` enum that `payment.method`
/// already stores; the Payment Methods tab configures these types rather than
/// defining a second taxonomy.
enum AccountsPaymentMethodType {
  cash('CASH'),
  creditCard('CREDIT_CARD'),
  debitCard('DEBIT_CARD'),
  prepaidCard('PREPAID_CARD'),
  giftCard('GIFT_CARD'),
  voucher('VOUCHER'),
  bankCheck('BANK_CHECK'),
  mobileMoney('MOBILE_MONEY'),
  bankTransfer('BANK_TRANSFER'),
  insurance('INSURANCE'),
  other('OTHER');

  const AccountsPaymentMethodType(this.wireValue);

  final String wireValue;

  static AccountsPaymentMethodType? fromWire(String? value) {
    final String normalized = (value ?? '').trim().toUpperCase();
    for (final AccountsPaymentMethodType type
        in AccountsPaymentMethodType.values) {
      if (type.wireValue == normalized) {
        return type;
      }
    }
    return null;
  }
}

/// Whether a method takes money in, pays money out, or both.
enum AccountsPaymentMethodDirection {
  incoming('INCOMING'),
  outgoing('OUTGOING'),
  both('BOTH');

  const AccountsPaymentMethodDirection(this.wireValue);

  final String wireValue;

  static AccountsPaymentMethodDirection? fromWire(String? value) {
    final String normalized = (value ?? '').trim().toUpperCase();
    for (final AccountsPaymentMethodDirection direction
        in AccountsPaymentMethodDirection.values) {
      if (direction.wireValue == normalized) {
        return direction;
      }
    }
    return null;
  }
}

/// Workflow action posted to
/// `POST /accounts/payment-methods/{id}/{action}`.
enum AccountsPaymentMethodAction {
  activate('activate'),
  deactivate('deactivate'),
  archive('archive'),
  restore('restore');

  const AccountsPaymentMethodAction(this.wireValue);

  final String wireValue;
}

/// One row of `Accounts & Finance → Setup & Controls → Payment Methods`.
///
/// Records are addressed only by [humanFriendlyId]; the API never returns a
/// raw database identifier for this resource.
@immutable
final class AccountsPaymentMethod {
  const AccountsPaymentMethod({
    required this.humanFriendlyId,
    required this.methodCode,
    required this.methodName,
    required this.methodType,
    required this.direction,
    required this.status,
    required this.version,
    this.provider,
    this.settlementAccount,
    this.settlementAccountHumanFriendlyId,
    this.clearingAccount,
    this.clearingAccountHumanFriendlyId,
    this.requiresExternalReference = false,
    this.requiresApproval = false,
    this.feeRule,
    this.facilityScope,
    this.facilityHumanFriendlyId,
    this.effectiveFrom,
    this.effectiveTo,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.archivedAt,
  });

  final String humanFriendlyId;
  final String methodCode;
  final String methodName;
  final AccountsPaymentMethodType methodType;
  final AccountsPaymentMethodDirection direction;
  final String? provider;
  final String? settlementAccount;
  final String? settlementAccountHumanFriendlyId;
  final String? clearingAccount;
  final String? clearingAccountHumanFriendlyId;
  final bool requiresExternalReference;
  final bool requiresApproval;
  final String? feeRule;
  final String? facilityScope;
  final String? facilityHumanFriendlyId;
  final DateTime? effectiveFrom;
  final DateTime? effectiveTo;
  final AccountsPaymentMethodStatus status;
  final String? notes;
  final int version;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? archivedAt;

  /// Editable only while draft or active and holding a current version.
  bool get canEdit =>
      status == AccountsPaymentMethodStatus.draft ||
      status == AccountsPaymentMethodStatus.active;

  /// Clone copies the shape of a method into a new unsaved draft.
  bool get canClone => status != AccountsPaymentMethodStatus.archived;

  bool get canActivate =>
      status.allowedTransitions.contains(AccountsPaymentMethodStatus.active);

  bool get canDeactivate =>
      status.allowedTransitions.contains(AccountsPaymentMethodStatus.inactive);

  /// The backend additionally refuses to archive while recorded payments
  /// already used this tender.
  bool get canArchive =>
      status.allowedTransitions.contains(AccountsPaymentMethodStatus.archived);

  bool get canRestore => status == AccountsPaymentMethodStatus.archived;

  AccountsPaymentMethodAction? get toggleAction {
    if (canRestore) {
      return AccountsPaymentMethodAction.restore;
    }
    if (status == AccountsPaymentMethodStatus.active) {
      return AccountsPaymentMethodAction.deactivate;
    }
    if (canActivate) {
      return AccountsPaymentMethodAction.activate;
    }
    return null;
  }
}

/// Committed query shared by the tab count, table rows, advanced filters,
/// export, print, and URL restoration.
@immutable
final class AccountsPaymentMethodQuery {
  const AccountsPaymentMethodQuery({
    this.search = '',
    this.statuses = const <AccountsPaymentMethodStatus>{},
    this.methodTypes = const <AccountsPaymentMethodType>{},
    this.directions = const <AccountsPaymentMethodDirection>{},
    this.methodCode = '',
    this.methodName = '',
    this.facilityId = '',
    this.settlementAccountId = '',
    this.clearingAccountId = '',
    this.requiresExternalReference,
    this.requiresApproval,
    this.from,
    this.to,
    this.sortBy = 'effective_from',
    this.ascending = false,
    this.pageRequest = const AppPageRequest(),
  });

  final String search;
  final Set<AccountsPaymentMethodStatus> statuses;
  final Set<AccountsPaymentMethodType> methodTypes;
  final Set<AccountsPaymentMethodDirection> directions;
  final String methodCode;
  final String methodName;
  final String facilityId;
  final String settlementAccountId;
  final String clearingAccountId;
  final bool? requiresExternalReference;
  final bool? requiresApproval;
  final DateTime? from;
  final DateTime? to;
  final String sortBy;
  final bool ascending;
  final AppPageRequest pageRequest;

  bool get hasActiveFilters =>
      statuses.isNotEmpty ||
      methodTypes.isNotEmpty ||
      directions.isNotEmpty ||
      methodCode.trim().isNotEmpty ||
      methodName.trim().isNotEmpty ||
      facilityId.trim().isNotEmpty ||
      settlementAccountId.trim().isNotEmpty ||
      clearingAccountId.trim().isNotEmpty ||
      requiresExternalReference != null ||
      requiresApproval != null ||
      from != null ||
      to != null;

  bool get isNarrowed => hasActiveFilters || search.trim().isNotEmpty;

  AccountsPaymentMethodQuery copyWith({
    String? search,
    Set<AccountsPaymentMethodStatus>? statuses,
    Set<AccountsPaymentMethodType>? methodTypes,
    Set<AccountsPaymentMethodDirection>? directions,
    String? methodCode,
    String? methodName,
    String? facilityId,
    String? settlementAccountId,
    String? clearingAccountId,
    bool? requiresExternalReference,
    bool? requiresApproval,
    DateTime? from,
    DateTime? to,
    String? sortBy,
    bool? ascending,
    AppPageRequest? pageRequest,
    bool clearFrom = false,
    bool clearTo = false,
    bool clearRequiresExternalReference = false,
    bool clearRequiresApproval = false,
  }) {
    return AccountsPaymentMethodQuery(
      search: search ?? this.search,
      statuses: statuses ?? this.statuses,
      methodTypes: methodTypes ?? this.methodTypes,
      directions: directions ?? this.directions,
      methodCode: methodCode ?? this.methodCode,
      methodName: methodName ?? this.methodName,
      facilityId: facilityId ?? this.facilityId,
      settlementAccountId: settlementAccountId ?? this.settlementAccountId,
      clearingAccountId: clearingAccountId ?? this.clearingAccountId,
      requiresExternalReference: clearRequiresExternalReference
          ? null
          : requiresExternalReference ?? this.requiresExternalReference,
      requiresApproval: clearRequiresApproval
          ? null
          : requiresApproval ?? this.requiresApproval,
      from: clearFrom ? null : from ?? this.from,
      to: clearTo ? null : to ?? this.to,
      sortBy: sortBy ?? this.sortBy,
      ascending: ascending ?? this.ascending,
      pageRequest: pageRequest ?? this.pageRequest,
    );
  }
}
