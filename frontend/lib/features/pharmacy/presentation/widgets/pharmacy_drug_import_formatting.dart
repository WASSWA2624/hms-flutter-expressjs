import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_drug_import.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pharmacy_drug_import_review.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

String pharmacyDrugImportSourceLabel(
  AppLocalizations l10n,
  PharmacyDrugImportSource source,
) {
  return switch (source) {
    PharmacyDrugImportSource.medicErp => l10n.pharmacyDrugImportSourceMedicErp,
  };
}

String pharmacyDrugImportStatusLabel(
  AppLocalizations l10n,
  PharmacyDrugImportStatus status,
) {
  return switch (status) {
    PharmacyDrugImportStatus.newProduct => l10n.pharmacyDrugImportStatusNew,
    PharmacyDrugImportStatus.existing => l10n.pharmacyDrugImportStatusExisting,
    PharmacyDrugImportStatus.similar => l10n.pharmacyDrugImportStatusSimilar,
  };
}

AppWorkspaceStatusTone pharmacyDrugImportStatusTone(
  PharmacyDrugImportStatus status,
) {
  return switch (status) {
    PharmacyDrugImportStatus.newProduct => AppWorkspaceStatusTone.success,
    PharmacyDrugImportStatus.existing => AppWorkspaceStatusTone.info,
    PharmacyDrugImportStatus.similar => AppWorkspaceStatusTone.warning,
  };
}

IconData pharmacyDrugImportStatusIcon(PharmacyDrugImportStatus status) {
  return switch (status) {
    PharmacyDrugImportStatus.newProduct => Icons.add_circle_outline_rounded,
    PharmacyDrugImportStatus.existing => Icons.link_rounded,
    PharmacyDrugImportStatus.similar => Icons.rule_rounded,
  };
}

String pharmacyDrugImportActionLabel(
  AppLocalizations l10n,
  PharmacyDrugImportAction action,
) {
  return switch (action) {
    PharmacyDrugImportAction.create => l10n.pharmacyDrugImportActionCreate,
    PharmacyDrugImportAction.merge => l10n.pharmacyDrugImportActionMerge,
    PharmacyDrugImportAction.update => l10n.pharmacyDrugImportActionUpdate,
    PharmacyDrugImportAction.skip => l10n.pharmacyDrugImportActionSkip,
  };
}

String pharmacyDrugImportActionDescription(
  AppLocalizations l10n,
  PharmacyDrugImportAction action,
) {
  return switch (action) {
    PharmacyDrugImportAction.create =>
      l10n.pharmacyDrugImportActionCreateDescription,
    PharmacyDrugImportAction.merge =>
      l10n.pharmacyDrugImportActionMergeDescription,
    PharmacyDrugImportAction.update =>
      l10n.pharmacyDrugImportActionUpdateDescription,
    PharmacyDrugImportAction.skip =>
      l10n.pharmacyDrugImportActionSkipDescription,
  };
}

IconData pharmacyDrugImportActionIcon(PharmacyDrugImportAction action) {
  return switch (action) {
    PharmacyDrugImportAction.create => Icons.add_circle_outline_rounded,
    PharmacyDrugImportAction.merge => Icons.link_rounded,
    PharmacyDrugImportAction.update => Icons.published_with_changes_rounded,
    PharmacyDrugImportAction.skip => Icons.block_rounded,
  };
}

String pharmacyDrugImportFieldLabel(
  AppLocalizations l10n,
  PharmacyDrugImportField field,
) {
  return switch (field) {
    PharmacyDrugImportField.name => l10n.pharmacyDrugImportFieldProductName,
    PharmacyDrugImportField.brandName => l10n.pharmacyDrugImportFieldBrand,
    PharmacyDrugImportField.form => l10n.pharmacyDrugFormLabel,
    PharmacyDrugImportField.strength => l10n.pharmacyDrugStrengthLabel,
    PharmacyDrugImportField.unitPrice =>
      l10n.pharmacyDrugImportFieldSellingPrice,
    PharmacyDrugImportField.buyUnitPrice =>
      l10n.pharmacyDrugImportFieldSupplierPrice,
    PharmacyDrugImportField.supplierName => l10n.pharmacyDrugImportFieldSupplier,
  };
}

/// Where a catalog field's value comes from in the source file.
String pharmacyDrugImportFieldSourceLabel(
  AppLocalizations l10n,
  PharmacyDrugImportSource source,
  PharmacyDrugImportField field,
) {
  final String? column = source.fieldColumns[field];
  return column == null
      ? l10n.pharmacyDrugImportFieldFromProductName
      : l10n.pharmacyDrugImportFieldFromColumn(column);
}

String pharmacyDrugImportValueProblemMessage(
  AppLocalizations l10n,
  Locale locale,
  PharmacyDrugImportValueProblem problem, {
  int? maxLength,
}) {
  return switch (problem) {
    PharmacyDrugImportValueProblem.required =>
      l10n.pharmacyDrugImportValueRequired,
    PharmacyDrugImportValueProblem.tooLong =>
      l10n.pharmacyDrugImportValueTooLong(
        AppFormatters.decimal(maxLength ?? 0, locale),
      ),
    PharmacyDrugImportValueProblem.invalidNumber =>
      l10n.pharmacyDrugImportValueInvalidNumber,
    PharmacyDrugImportValueProblem.negative =>
      l10n.pharmacyDrugImportValueNegative,
    PharmacyDrugImportValueProblem.tooLarge =>
      l10n.pharmacyDrugImportValueTooLarge,
    PharmacyDrugImportValueProblem.invalidQuantity =>
      l10n.pharmacyDrugImportValueInvalidQuantity,
    PharmacyDrugImportValueProblem.duplicateBatch =>
      l10n.pharmacyDrugImportValueDuplicateBatch,
    PharmacyDrugImportValueProblem.duplicateProduct =>
      l10n.pharmacyDrugImportValueDuplicateProduct,
  };
}

String pharmacyDrugImportOutcomeLabel(
  AppLocalizations l10n,
  PharmacyDrugImportFieldOutcome outcome,
) {
  return switch (outcome) {
    PharmacyDrugImportFieldOutcome.noChange =>
      l10n.pharmacyDrugImportOutcomeNoChange,
    PharmacyDrugImportFieldOutcome.fillsBlank =>
      l10n.pharmacyDrugImportOutcomeFillsBlank,
    PharmacyDrugImportFieldOutcome.replaces =>
      l10n.pharmacyDrugImportOutcomeReplaces,
    PharmacyDrugImportFieldOutcome.clears => l10n.pharmacyDrugImportOutcomeClears,
  };
}

AppWorkspaceStatusTone pharmacyDrugImportOutcomeTone(
  PharmacyDrugImportFieldOutcome outcome,
) {
  return switch (outcome) {
    PharmacyDrugImportFieldOutcome.noChange => AppWorkspaceStatusTone.neutral,
    PharmacyDrugImportFieldOutcome.fillsBlank => AppWorkspaceStatusTone.success,
    PharmacyDrugImportFieldOutcome.replaces => AppWorkspaceStatusTone.warning,
    PharmacyDrugImportFieldOutcome.clears => AppWorkspaceStatusTone.error,
  };
}

AppWorkspaceStatusTone pharmacyDrugImportIssueTone(
  PharmacyDrugImportIssueSeverity severity,
) {
  return switch (severity) {
    PharmacyDrugImportIssueSeverity.error => AppWorkspaceStatusTone.error,
    PharmacyDrugImportIssueSeverity.warning => AppWorkspaceStatusTone.warning,
    PharmacyDrugImportIssueSeverity.info => AppWorkspaceStatusTone.info,
  };
}

/// Tone of the most severe issue.
AppWorkspaceStatusTone pharmacyDrugImportIssuesTone(
  Iterable<PharmacyDrugImportIssue> issues,
) {
  final Set<PharmacyDrugImportIssueSeverity> severities = issues
      .map((PharmacyDrugImportIssue issue) => issue.severity)
      .toSet();
  if (severities.contains(PharmacyDrugImportIssueSeverity.error)) {
    return AppWorkspaceStatusTone.error;
  }
  if (severities.contains(PharmacyDrugImportIssueSeverity.warning)) {
    return AppWorkspaceStatusTone.warning;
  }
  return AppWorkspaceStatusTone.info;
}

String pharmacyDrugImportFileSize(
  AppLocalizations l10n,
  Locale locale,
  int bytes,
) {
  String rounded(double value) =>
      AppFormatters.decimal((value * 10).round() / 10, locale);
  if (bytes < 1024) {
    return l10n.pharmacyDrugImportFileSizeBytes(
      AppFormatters.decimal(bytes, locale),
    );
  }
  if (bytes < 1024 * 1024) {
    return l10n.pharmacyDrugImportFileSizeKb(rounded(bytes / 1024));
  }
  return l10n.pharmacyDrugImportFileSizeMb(rounded(bytes / (1024 * 1024)));
}

/// Localized, human-readable message for a drug import issue.
String pharmacyDrugImportIssueMessage(
  AppLocalizations l10n,
  Locale locale,
  PharmacyDrugImportIssue issue,
) {
  final Map<String, Object?> params = issue.params;
  String text(String key) => params[key]?.toString() ?? '';
  String number(String raw) {
    final num? parsed = num.tryParse(raw);
    return parsed == null ? raw : AppFormatters.decimal(parsed, locale);
  }

  String date(String raw) {
    final DateTime? parsed = DateTime.tryParse(raw);
    return parsed == null ? raw : AppFormatters.mediumDate(parsed, locale);
  }

  String each(String key, String Function(String raw) format) => text(
    key,
  ).split(', ').where((String raw) => raw.isNotEmpty).map(format).join(', ');

  final String field = _sourceFieldLabel(l10n, issue.field);
  return switch (issue.code) {
    'MISSING_PRODUCT_NAME' => l10n.pharmacyDrugImportIssueMissingProductName,
    'VALUE_TOO_LONG' => l10n.pharmacyDrugImportIssueValueTooLong(
      field,
      text('max'),
    ),
    'VALUE_TRUNCATED' => l10n.pharmacyDrugImportIssueValueTruncated(
      field,
      text('max'),
    ),
    'INVALID_NUMBER' => l10n.pharmacyDrugImportIssueInvalidNumber(
      field,
      text('value'),
    ),
    'MISSING_QUANTITY' => l10n.pharmacyDrugImportIssueMissingQuantity,
    'NEGATIVE_QUANTITY' => l10n.pharmacyDrugImportIssueNegativeQuantity(
      number(text('value')),
    ),
    'FRACTIONAL_QUANTITY' => l10n.pharmacyDrugImportIssueFractionalQuantity(
      number(text('value')),
    ),
    'QUANTITY_EXCEEDS_RECEIVED' =>
      l10n.pharmacyDrugImportIssueQuantityExceedsReceived(
        number(text('available_quantity')),
        number(text('quantity')),
      ),
    'NEGATIVE_PRICE' => l10n.pharmacyDrugImportIssueNegativePrice(
      field,
      number(text('value')),
    ),
    'PRICE_BELOW_COST' => l10n.pharmacyDrugImportIssuePriceBelowCost(
      number(text('retail_price')),
      number(text('cost')),
    ),
    'MISSING_BATCH_NUMBER' => l10n.pharmacyDrugImportIssueMissingBatchNumber,
    'MISSING_EXPIRY_DATE' => l10n.pharmacyDrugImportIssueMissingExpiryDate,
    'INVALID_DATE' => l10n.pharmacyDrugImportIssueInvalidDate(text('value')),
    'EXPIRED_BATCH' => l10n.pharmacyDrugImportIssueExpiredBatch(
      date(text('expiry_date')),
    ),
    'DUPLICATE_ROW' => l10n.pharmacyDrugImportIssueDuplicateRow(
      text('duplicate_of_row'),
    ),
    'CONFLICTING_RETAIL_PRICE' =>
      l10n.pharmacyDrugImportIssueConflictingRetailPrice(
        each('values', number),
        number(text('chosen')),
      ),
    'CONFLICTING_COST' => l10n.pharmacyDrugImportIssueConflictingCost(
      each('values', number),
      number(text('chosen')),
    ),
    'CONFLICTING_SUPPLIER' => l10n.pharmacyDrugImportIssueConflictingSupplier(
      text('values'),
      text('chosen'),
    ),
    'CONFLICTING_BATCH_EXPIRY' =>
      l10n.pharmacyDrugImportIssueConflictingBatchExpiry(
        text('batch_number'),
        each('values', date),
        date(text('chosen')),
      ),
    'BATCH_ROWS_MERGED' => l10n.pharmacyDrugImportIssueBatchRowsMerged(
      number(text('rows')),
      text('batch_number'),
    ),
    'AMBIGUOUS_EXISTING_MATCH' =>
      l10n.pharmacyDrugImportIssueAmbiguousExistingMatch(number(text('count'))),
    'SIMILAR_PRODUCT_IN_FILE' =>
      l10n.pharmacyDrugImportIssueSimilarProductInFile(
        <String>[
          text('name'),
          text('brand_name'),
        ].where((String part) => part.isNotEmpty).join(' · '),
        text('rows'),
      ),
    _ => l10n.pharmacyDrugImportIssueUnknown(issue.code),
  };
}

String _sourceFieldLabel(AppLocalizations l10n, String? field) {
  return switch (field) {
    'product_name' => l10n.pharmacyDrugImportFieldProductName,
    'product_brand' => l10n.pharmacyDrugImportFieldBrand,
    'available_quantity' => l10n.pharmacyDrugImportFieldAvailableQuantity,
    'quantity' => l10n.pharmacyDrugImportFieldReceivedQuantity,
    'retail_price' => l10n.pharmacyDrugImportFieldSellingPrice,
    'cost' => l10n.pharmacyDrugImportFieldSupplierPrice,
    'batch_number' => l10n.pharmacyDrugImportFieldBatchNumber,
    'expiry_date' => l10n.pharmacyDrugImportFieldExpiryDate,
    'supplier' => l10n.pharmacyDrugImportFieldSupplier,
    _ => field ?? '',
  };
}
