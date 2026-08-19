import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/shared/data/data.dart';

/// Lifecycle of a document numbering policy
/// (`billing-accounts-finance.md` §§9.3 / 10.3).
enum AccountsDocumentSequenceStatus {
  draft('DRAFT'),
  active('ACTIVE'),
  inactive('INACTIVE'),
  archived('ARCHIVED');

  const AccountsDocumentSequenceStatus(this.wireValue);

  final String wireValue;

  static AccountsDocumentSequenceStatus? fromWire(String? value) {
    final String normalized = (value ?? '').trim().toUpperCase();
    for (final AccountsDocumentSequenceStatus status
        in AccountsDocumentSequenceStatus.values) {
      if (status.wireValue == normalized) {
        return status;
      }
    }
    return null;
  }

  /// Transitions the backend accepts; the UI hides everything else.
  Set<AccountsDocumentSequenceStatus> get allowedTransitions {
    return switch (this) {
      AccountsDocumentSequenceStatus.draft =>
        <AccountsDocumentSequenceStatus>{
          AccountsDocumentSequenceStatus.active,
          AccountsDocumentSequenceStatus.archived,
        },
      AccountsDocumentSequenceStatus.active =>
        <AccountsDocumentSequenceStatus>{
          AccountsDocumentSequenceStatus.inactive,
          AccountsDocumentSequenceStatus.archived,
        },
      AccountsDocumentSequenceStatus.inactive =>
        <AccountsDocumentSequenceStatus>{
          AccountsDocumentSequenceStatus.active,
          AccountsDocumentSequenceStatus.archived,
        },
      AccountsDocumentSequenceStatus.archived =>
        <AccountsDocumentSequenceStatus>{
          AccountsDocumentSequenceStatus.active,
        },
    };
  }
}

/// Documents a sequence can issue references for.
///
/// Every value maps to a model that already reserves friendly ids through the
/// backend `human_id_counter`, so this tab configures existing numbering rather
/// than defining a second taxonomy of numbered documents.
enum AccountsDocumentType {
  invoice('INVOICE'),
  accountsInvoice('ACCOUNTS_INVOICE'),
  receipt('RECEIPT'),
  payment('PAYMENT'),
  refund('REFUND'),
  creditNote('CREDIT_NOTE'),
  debitNote('DEBIT_NOTE'),
  purchaseOrder('PURCHASE_ORDER'),
  goodsReceipt('GOODS_RECEIPT'),
  claim('CLAIM');

  const AccountsDocumentType(this.wireValue);

  final String wireValue;

  static AccountsDocumentType? fromWire(String? value) {
    final String normalized = (value ?? '').trim().toUpperCase();
    for (final AccountsDocumentType type in AccountsDocumentType.values) {
      if (type.wireValue == normalized) {
        return type;
      }
    }
    return null;
  }
}

/// How often the underlying counter restarts at one.
enum AccountsDocumentSequenceResetFrequency {
  never('NEVER'),
  daily('DAILY'),
  monthly('MONTHLY'),
  quarterly('QUARTERLY'),
  yearly('YEARLY');

  const AccountsDocumentSequenceResetFrequency(this.wireValue);

  final String wireValue;

  static AccountsDocumentSequenceResetFrequency? fromWire(String? value) {
    final String normalized = (value ?? '').trim().toUpperCase();
    for (final AccountsDocumentSequenceResetFrequency frequency
        in AccountsDocumentSequenceResetFrequency.values) {
      if (frequency.wireValue == normalized) {
        return frequency;
      }
    }
    return null;
  }
}

/// What the sequence does with numbers reserved but never committed.
enum AccountsDocumentSequenceGapPolicy {
  allowGaps('ALLOW_GAPS'),
  noGaps('NO_GAPS'),
  reserveAndVoid('RESERVE_AND_VOID');

  const AccountsDocumentSequenceGapPolicy(this.wireValue);

  final String wireValue;

  static AccountsDocumentSequenceGapPolicy? fromWire(String? value) {
    final String normalized = (value ?? '').trim().toUpperCase();
    for (final AccountsDocumentSequenceGapPolicy policy
        in AccountsDocumentSequenceGapPolicy.values) {
      if (policy.wireValue == normalized) {
        return policy;
      }
    }
    return null;
  }
}

/// Workflow action posted to
/// `POST /accounts/document-numbering/{id}/{action}`.
enum AccountsDocumentSequenceAction {
  activate('activate'),
  deactivate('deactivate'),
  archive('archive'),
  restore('restore');

  const AccountsDocumentSequenceAction(this.wireValue);

  final String wireValue;
}

/// One row of `Accounts & Finance → Setup & Controls → Document Numbering`.
///
/// The row is numbering *policy*. [nextNumber], [lastIssuedNumber], and
/// [lastIssuedAt] are read back from the counter the backend already
/// increments for every document, so this surface never holds a second copy of
/// the running number. Records are addressed only by [humanFriendlyId].
@immutable
final class AccountsDocumentSequence {
  const AccountsDocumentSequence({
    required this.humanFriendlyId,
    required this.sequenceCode,
    required this.documentType,
    required this.module,
    required this.prefix,
    required this.minimumLength,
    required this.resetFrequency,
    required this.gapPolicy,
    required this.status,
    required this.version,
    this.facility,
    this.facilityHumanFriendlyId,
    this.suffix,
    this.datePattern,
    this.nextNumber,
    this.lastIssuedNumber,
    this.lastIssuedAt,
    this.nextReferencePreview,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.archivedAt,
  });

  final String humanFriendlyId;
  final String sequenceCode;
  final AccountsDocumentType documentType;
  final String module;
  final String? facility;
  final String? facilityHumanFriendlyId;
  final String prefix;
  final String? suffix;
  final String? datePattern;
  final int? nextNumber;
  final int minimumLength;
  final AccountsDocumentSequenceResetFrequency resetFrequency;
  final int? lastIssuedNumber;
  final DateTime? lastIssuedAt;
  final AccountsDocumentSequenceGapPolicy gapPolicy;
  final AccountsDocumentSequenceStatus status;

  /// Server-rendered preview of the reference this policy issues next.
  final String? nextReferencePreview;
  final String? notes;
  final int version;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? archivedAt;

  /// True once the counter behind this policy has issued at least one number.
  ///
  /// The reference shape freezes at that point: changing it would make old and
  /// new references indistinguishable.
  bool get hasIssued => (lastIssuedNumber ?? 0) > 0;

  /// Editable only while draft or active and holding a current version.
  bool get canEdit =>
      status == AccountsDocumentSequenceStatus.draft ||
      status == AccountsDocumentSequenceStatus.active;

  /// Clone copies the shape of a sequence into a new unsaved draft.
  bool get canClone => status != AccountsDocumentSequenceStatus.archived;

  bool get canActivate =>
      status.allowedTransitions.contains(AccountsDocumentSequenceStatus.active);

  bool get canDeactivate => status.allowedTransitions.contains(
    AccountsDocumentSequenceStatus.inactive,
  );

  /// The backend additionally refuses to activate a second sequence for the
  /// same document family, since both would race for one counter.
  bool get canArchive => status.allowedTransitions.contains(
    AccountsDocumentSequenceStatus.archived,
  );

  bool get canRestore => status == AccountsDocumentSequenceStatus.archived;

  AccountsDocumentSequenceAction? get toggleAction {
    if (canRestore) {
      return AccountsDocumentSequenceAction.restore;
    }
    if (status == AccountsDocumentSequenceStatus.active) {
      return AccountsDocumentSequenceAction.deactivate;
    }
    if (canActivate) {
      return AccountsDocumentSequenceAction.activate;
    }
    return null;
  }
}

/// Committed query shared by the tab count, table rows, advanced filters,
/// export, print, and URL restoration.
@immutable
final class AccountsDocumentSequenceQuery {
  const AccountsDocumentSequenceQuery({
    this.search = '',
    this.statuses = const <AccountsDocumentSequenceStatus>{},
    this.documentTypes = const <AccountsDocumentType>{},
    this.resetFrequencies = const <AccountsDocumentSequenceResetFrequency>{},
    this.gapPolicies = const <AccountsDocumentSequenceGapPolicy>{},
    this.module = '',
    this.sequenceCode = '',
    this.prefix = '',
    this.facilityId = '',
    this.from,
    this.to,
    this.sortBy = 'sequence_code',
    this.ascending = true,
    this.pageRequest = const AppPageRequest(),
  });

  final String search;
  final Set<AccountsDocumentSequenceStatus> statuses;
  final Set<AccountsDocumentType> documentTypes;
  final Set<AccountsDocumentSequenceResetFrequency> resetFrequencies;
  final Set<AccountsDocumentSequenceGapPolicy> gapPolicies;
  final String module;
  final String sequenceCode;
  final String prefix;
  final String facilityId;
  final DateTime? from;
  final DateTime? to;
  final String sortBy;
  final bool ascending;
  final AppPageRequest pageRequest;

  bool get hasActiveFilters =>
      statuses.isNotEmpty ||
      documentTypes.isNotEmpty ||
      resetFrequencies.isNotEmpty ||
      gapPolicies.isNotEmpty ||
      module.trim().isNotEmpty ||
      sequenceCode.trim().isNotEmpty ||
      prefix.trim().isNotEmpty ||
      facilityId.trim().isNotEmpty ||
      from != null ||
      to != null;

  bool get isNarrowed => hasActiveFilters || search.trim().isNotEmpty;

  AccountsDocumentSequenceQuery copyWith({
    String? search,
    Set<AccountsDocumentSequenceStatus>? statuses,
    Set<AccountsDocumentType>? documentTypes,
    Set<AccountsDocumentSequenceResetFrequency>? resetFrequencies,
    Set<AccountsDocumentSequenceGapPolicy>? gapPolicies,
    String? module,
    String? sequenceCode,
    String? prefix,
    String? facilityId,
    DateTime? from,
    DateTime? to,
    String? sortBy,
    bool? ascending,
    AppPageRequest? pageRequest,
    bool clearFrom = false,
    bool clearTo = false,
  }) {
    return AccountsDocumentSequenceQuery(
      search: search ?? this.search,
      statuses: statuses ?? this.statuses,
      documentTypes: documentTypes ?? this.documentTypes,
      resetFrequencies: resetFrequencies ?? this.resetFrequencies,
      gapPolicies: gapPolicies ?? this.gapPolicies,
      module: module ?? this.module,
      sequenceCode: sequenceCode ?? this.sequenceCode,
      prefix: prefix ?? this.prefix,
      facilityId: facilityId ?? this.facilityId,
      from: clearFrom ? null : from ?? this.from,
      to: clearTo ? null : to ?? this.to,
      sortBy: sortBy ?? this.sortBy,
      ascending: ascending ?? this.ascending,
      pageRequest: pageRequest ?? this.pageRequest,
    );
  }
}
