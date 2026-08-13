import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/shared/data/data.dart';

/// Lifecycle of a currency & exchange rate row
/// (`billing-accounts-finance.md` §§9.3 / 10.3).
enum AccountsCurrencyStatus {
  draft('DRAFT'),
  active('ACTIVE'),
  inactive('INACTIVE'),
  archived('ARCHIVED');

  const AccountsCurrencyStatus(this.wireValue);

  final String wireValue;

  static AccountsCurrencyStatus? fromWire(String? value) {
    final String normalized = (value ?? '').trim().toUpperCase();
    for (final AccountsCurrencyStatus status in AccountsCurrencyStatus.values) {
      if (status.wireValue == normalized) {
        return status;
      }
    }
    return null;
  }

  /// Transitions the backend accepts; the UI hides everything else.
  Set<AccountsCurrencyStatus> get allowedTransitions {
    return switch (this) {
      AccountsCurrencyStatus.draft => <AccountsCurrencyStatus>{
        AccountsCurrencyStatus.active,
        AccountsCurrencyStatus.archived,
      },
      AccountsCurrencyStatus.active => <AccountsCurrencyStatus>{
        AccountsCurrencyStatus.inactive,
        AccountsCurrencyStatus.archived,
      },
      AccountsCurrencyStatus.inactive => <AccountsCurrencyStatus>{
        AccountsCurrencyStatus.active,
        AccountsCurrencyStatus.archived,
      },
      AccountsCurrencyStatus.archived => <AccountsCurrencyStatus>{
        AccountsCurrencyStatus.active,
      },
    };
  }
}

/// Quotation basis of a rate row.
enum AccountsCurrencyRateType {
  spot('SPOT'),
  daily('DAILY'),
  monthly('MONTHLY'),
  budget('BUDGET'),
  contract('CONTRACT');

  const AccountsCurrencyRateType(this.wireValue);

  final String wireValue;

  static AccountsCurrencyRateType? fromWire(String? value) {
    final String normalized = (value ?? '').trim().toUpperCase();
    for (final AccountsCurrencyRateType type
        in AccountsCurrencyRateType.values) {
      if (type.wireValue == normalized) {
        return type;
      }
    }
    return null;
  }
}

/// Workflow action posted to
/// `POST /accounts/currencies-and-exchange-rates/{id}/{action}`.
enum AccountsCurrencyRateAction {
  activate('activate'),
  deactivate('deactivate'),
  archive('archive'),
  restore('restore');

  const AccountsCurrencyRateAction(this.wireValue);

  final String wireValue;
}

/// One row of
/// `Accounts & Finance → Setup & Controls → Currencies & Exchange Rates`.
///
/// Records are addressed only by [humanFriendlyId]; the API never returns a
/// raw database identifier for this resource.
@immutable
final class AccountsCurrencyRate {
  const AccountsCurrencyRate({
    required this.humanFriendlyId,
    required this.currencyCode,
    required this.currencyName,
    required this.symbol,
    required this.decimalPlaces,
    required this.baseCurrency,
    required this.rateType,
    required this.exchangeRate,
    required this.effectiveDate,
    required this.status,
    required this.version,
    this.source,
    this.buyRate,
    this.sellRate,
    this.lastUpdatedAt,
    this.updatedBy,
    this.entityAndFacility,
    this.facilityHumanFriendlyId,
    this.notes,
    this.createdAt,
    this.archivedAt,
  });

  final String humanFriendlyId;
  final String currencyCode;
  final String currencyName;
  final String symbol;
  final int decimalPlaces;
  final bool baseCurrency;
  final AccountsCurrencyRateType rateType;
  final double exchangeRate;
  final DateTime effectiveDate;
  final String? source;
  final double? buyRate;
  final double? sellRate;
  final DateTime? lastUpdatedAt;
  final String? updatedBy;
  final AccountsCurrencyStatus status;
  final String? entityAndFacility;
  final String? facilityHumanFriendlyId;
  final String? notes;
  final int version;
  final DateTime? createdAt;
  final DateTime? archivedAt;

  /// Editable only while draft/active and holding a current version.
  bool get canEdit =>
      status == AccountsCurrencyStatus.draft ||
      status == AccountsCurrencyStatus.active;

  /// Clone copies the shape of a rate into a new unsaved draft.
  bool get canClone => status != AccountsCurrencyStatus.archived;

  bool get canActivate =>
      status.allowedTransitions.contains(AccountsCurrencyStatus.active);

  /// The base currency anchors every conversion in scope, so it may not be
  /// retired while it still holds the flag.
  bool get canDeactivate =>
      !baseCurrency &&
      status.allowedTransitions.contains(AccountsCurrencyStatus.inactive);

  bool get canArchive =>
      !baseCurrency &&
      status.allowedTransitions.contains(AccountsCurrencyStatus.archived);

  bool get canRestore => status == AccountsCurrencyStatus.archived;

  AccountsCurrencyRateAction? get toggleAction {
    if (canRestore) {
      return AccountsCurrencyRateAction.restore;
    }
    if (status == AccountsCurrencyStatus.active) {
      return canDeactivate ? AccountsCurrencyRateAction.deactivate : null;
    }
    if (canActivate) {
      return AccountsCurrencyRateAction.activate;
    }
    return null;
  }
}

/// Committed query shared by the tab count, table rows, advanced filters,
/// export, print, and URL restoration.
@immutable
final class AccountsCurrencyRateQuery {
  const AccountsCurrencyRateQuery({
    this.search = '',
    this.statuses = const <AccountsCurrencyStatus>{},
    this.currencyCode = '',
    this.rateTypes = const <AccountsCurrencyRateType>{},
    this.baseCurrencyOnly,
    this.source = '',
    this.facilityId = '',
    this.from,
    this.to,
    this.sortBy = 'effective_date',
    this.ascending = false,
    this.pageRequest = const AppPageRequest(),
  });

  final String search;
  final Set<AccountsCurrencyStatus> statuses;
  final String currencyCode;
  final Set<AccountsCurrencyRateType> rateTypes;
  final bool? baseCurrencyOnly;
  final String source;
  final String facilityId;
  final DateTime? from;
  final DateTime? to;
  final String sortBy;
  final bool ascending;
  final AppPageRequest pageRequest;

  bool get hasActiveFilters =>
      statuses.isNotEmpty ||
      currencyCode.trim().isNotEmpty ||
      rateTypes.isNotEmpty ||
      baseCurrencyOnly != null ||
      source.trim().isNotEmpty ||
      facilityId.trim().isNotEmpty ||
      from != null ||
      to != null;

  bool get isNarrowed => hasActiveFilters || search.trim().isNotEmpty;

  AccountsCurrencyRateQuery copyWith({
    String? search,
    Set<AccountsCurrencyStatus>? statuses,
    String? currencyCode,
    Set<AccountsCurrencyRateType>? rateTypes,
    bool? baseCurrencyOnly,
    String? source,
    String? facilityId,
    DateTime? from,
    DateTime? to,
    String? sortBy,
    bool? ascending,
    AppPageRequest? pageRequest,
    bool clearBaseCurrencyOnly = false,
    bool clearFrom = false,
    bool clearTo = false,
  }) {
    return AccountsCurrencyRateQuery(
      search: search ?? this.search,
      statuses: statuses ?? this.statuses,
      currencyCode: currencyCode ?? this.currencyCode,
      rateTypes: rateTypes ?? this.rateTypes,
      baseCurrencyOnly: clearBaseCurrencyOnly
          ? null
          : baseCurrencyOnly ?? this.baseCurrencyOnly,
      source: source ?? this.source,
      facilityId: facilityId ?? this.facilityId,
      from: clearFrom ? null : from ?? this.from,
      to: clearTo ? null : to ?? this.to,
      sortBy: sortBy ?? this.sortBy,
      ascending: ascending ?? this.ascending,
      pageRequest: pageRequest ?? this.pageRequest,
    );
  }
}
