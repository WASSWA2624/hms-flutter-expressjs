import 'dart:async';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_drug_import.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

typedef PharmacyDrugImportFilePicker = Future<PharmacyDrugImportFile?> Function();

typedef PharmacyDrugImportPreviewLoader =
    Future<Result<PharmacyDrugImportPreview>> Function({
      required PharmacyDrugImportSource source,
      required PharmacyDrugImportFile file,
    });

typedef PharmacyDrugImportCommitter =
    Future<Result<PharmacyDrugImportResult>> Function(
      PharmacyDrugImportCommitInput input,
    );

/// Opens the platform picker restricted to Excel workbooks.
Future<PharmacyDrugImportFile?> pickPharmacyDrugImportFile({
  required String typeGroupLabel,
}) async {
  final XFile? file = await openFile(
    acceptedTypeGroups: <XTypeGroup>[
      XTypeGroup(
        label: typeGroupLabel,
        extensions: const <String>['xlsx'],
        mimeTypes: const <String>[
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ],
        uniformTypeIdentifiers: const <String>[
          'org.openxmlformats.spreadsheetml.sheet',
        ],
      ),
    ],
  );
  if (file == null) {
    return null;
  }
  return PharmacyDrugImportFile(
    name: file.name,
    bytes: await file.readAsBytes(),
  );
}

enum _ImportStep { setup, review, result }

enum _ProductFilter { all, newProducts, existing, review, issues, skipped }

const int _productPageSize = 25;
const int _issuePageSize = 50;
const int _namePreviewCount = 5;
const int _batchPreviewCount = 3;
const int _rowPreviewCount = 8;

/// Imports drugs and facility stock from another system's Excel export.
///
/// Setup picks the source and file; review shows the server analysis with a
/// decision per product; nothing is saved until the user confirms the import.
/// Pops with the [PharmacyDrugImportResult] when the user closes the result.
class PharmacyDrugImportDialog extends StatefulWidget {
  const PharmacyDrugImportDialog({
    required this.onPreview,
    required this.onCommit,
    this.facilityName,
    this.pickFile,
    super.key,
  });

  /// Analyzes the chosen file without saving anything.
  final PharmacyDrugImportPreviewLoader onPreview;

  /// Applies the reviewed import.
  final PharmacyDrugImportCommitter onCommit;

  /// Facility that receives the stock, shown until the server confirms it.
  final String? facilityName;

  /// Replaces the platform file picker (tests).
  final PharmacyDrugImportFilePicker? pickFile;

  @override
  State<PharmacyDrugImportDialog> createState() =>
      _PharmacyDrugImportDialogState();
}

class _PharmacyDrugImportDialogState extends State<PharmacyDrugImportDialog> {
  final Map<String, PharmacyDrugImportAction> _actions =
      <String, PharmacyDrugImportAction>{};
  final Map<String, String> _targets = <String, String>{};

  _ImportStep _step = _ImportStep.setup;
  PharmacyDrugImportSource _source = PharmacyDrugImportSource.medicErp;
  PharmacyDrugImportFile? _file;
  PharmacyDrugImportPreview? _preview;
  Map<String, PharmacyDrugImportProduct> _productsByKey =
      const <String, PharmacyDrugImportProduct>{};
  Map<String, List<PharmacyDrugImportIssue>> _rowIssuesByProduct =
      const <String, List<PharmacyDrugImportIssue>>{};
  PharmacyDrugImportResult? _result;
  AppFailure? _failure;
  bool _fileReadFailed = false;
  bool _isPickingFile = false;
  bool _isAnalyzing = false;
  bool _isImporting = false;
  PharmacyDrugImportStockMode _stockMode = PharmacyDrugImportStockMode.replace;
  bool _clearMissingStock = false;
  bool _reviewConfirmed = false;
  _ProductFilter _filter = _ProductFilter.all;
  int _visibleProductCount = _productPageSize;
  int _visibleIssueCount = _issuePageSize;

  bool get _isBusy => _isPickingFile || _isAnalyzing || _isImporting;

  PharmacyDrugImportAction _actionFor(PharmacyDrugImportProduct product) {
    return _actions[product.key] ?? product.defaultAction;
  }

  String? _targetFor(PharmacyDrugImportProduct product) {
    final String? chosen = _targets[product.key] ?? product.defaultTargetDrugId;
    if (chosen != null) {
      return chosen;
    }
    return product.linkOptions.isEmpty ? null : product.linkOptions.first.drug.id;
  }

  void _clearAnalysis({bool clearDecisions = true}) {
    _preview = null;
    _failure = null;
    _productsByKey = const <String, PharmacyDrugImportProduct>{};
    _rowIssuesByProduct = const <String, List<PharmacyDrugImportIssue>>{};
    if (clearDecisions) {
      _actions.clear();
      _targets.clear();
    }
  }

  Future<void> _chooseFile() async {
    final String typeGroupLabel = context.l10n.pharmacyDrugImportFileTypeLabel;
    final PharmacyDrugImportFilePicker picker =
        widget.pickFile ??
        () => pickPharmacyDrugImportFile(typeGroupLabel: typeGroupLabel);
    setState(() {
      _isPickingFile = true;
      _fileReadFailed = false;
    });

    PharmacyDrugImportFile? picked;
    bool failed = false;
    try {
      picked = await picker();
    } on Exception {
      failed = true;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _isPickingFile = false;
      _fileReadFailed = failed;
      if (picked != null) {
        _file = picked;
        _clearAnalysis();
      }
    });
  }

  Future<void> _analyze() async {
    final PharmacyDrugImportFile? file = _file;
    if (file == null || _isBusy) {
      return;
    }
    setState(() {
      _isAnalyzing = true;
      _failure = null;
      _fileReadFailed = false;
    });

    final Result<PharmacyDrugImportPreview> result = await widget.onPreview(
      source: _source,
      file: file,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _isAnalyzing = false;
      switch (result) {
        case ResultSuccess<PharmacyDrugImportPreview>(:final value):
          _applyPreview(value);
        case ResultFailure<PharmacyDrugImportPreview>(:final failure):
          _failure = failure;
      }
    });
  }

  void _applyPreview(PharmacyDrugImportPreview preview) {
    // Re-analysis (e.g. after a stale-plan conflict) keeps earlier choices
    // that the fresh plan still allows.
    final Map<String, PharmacyDrugImportProduct> productsByKey =
        <String, PharmacyDrugImportProduct>{
          for (final PharmacyDrugImportProduct product in preview.products)
            product.key: product,
        };
    _actions.removeWhere(
      (String key, PharmacyDrugImportAction action) =>
          !(productsByKey[key]?.allowedActions.contains(action) ?? false),
    );
    _targets.removeWhere(
      (String key, String drugId) =>
          productsByKey[key]?.linkOptionFor(drugId) == null,
    );

    final Map<String, List<PharmacyDrugImportIssue>> rowIssues =
        <String, List<PharmacyDrugImportIssue>>{};
    for (final PharmacyDrugImportIssue issue in preview.issues) {
      final String? key = issue.productKey;
      if (key != null) {
        (rowIssues[key] ??= <PharmacyDrugImportIssue>[]).add(issue);
      }
    }

    _preview = preview;
    _productsByKey = productsByKey;
    _rowIssuesByProduct = rowIssues;
    _reviewConfirmed = false;
    _visibleProductCount = _productPageSize;
    _visibleIssueCount = _issuePageSize;
    _step = preview.template.isValid && preview.canCommit
        ? _ImportStep.review
        : _ImportStep.setup;
  }

  Future<void> _import() async {
    final PharmacyDrugImportPreview? preview = _preview;
    final PharmacyDrugImportFile? file = _file;
    final String? planHash = preview?.planHash;
    if (preview == null ||
        file == null ||
        planHash == null ||
        !_canImport(preview)) {
      return;
    }
    setState(() {
      _isImporting = true;
      _failure = null;
    });

    final Result<PharmacyDrugImportResult> result = await widget.onCommit(
          PharmacyDrugImportCommitInput(
            source: _source,
            file: file,
            planHash: planHash,
            decisions: <PharmacyDrugImportDecision>[
              for (final PharmacyDrugImportProduct product in preview.products)
                PharmacyDrugImportDecision(
                  key: product.key,
                  action: _actionFor(product),
                  targetDrugId: _actionFor(product).linksExistingDrug
                      ? _targetFor(product)
                      : null,
                ),
            ],
            stockMode: _stockMode,
            clearMissingStock: _clearsMissingStock(preview),
            confirmReview: _reviewConfirmed,
            currency: appDefaultCurrencyCode,
          ),
        );
    if (!mounted) {
      return;
    }
    setState(() {
      _isImporting = false;
      switch (result) {
        case ResultSuccess<PharmacyDrugImportResult>(:final value):
          _result = value;
          _step = _ImportStep.result;
        case ResultFailure<PharmacyDrugImportResult>(:final failure):
          _failure = failure;
      }
    });
  }

  int _importCount(PharmacyDrugImportPreview preview) {
    return preview.products
        .where(
          (PharmacyDrugImportProduct product) =>
              _actionFor(product) != PharmacyDrugImportAction.skip,
        )
        .length;
  }

  List<PharmacyDrugImportDrug> _missingStockDrugs(
    PharmacyDrugImportPreview preview,
  ) {
    final Set<String> linkedDrugIds = preview.products
        .where(
          (PharmacyDrugImportProduct product) =>
              _actionFor(product).linksExistingDrug,
        )
        .map(_targetFor)
        .whereType<String>()
        .toSet();
    return preview.stockedDrugs
        .where((PharmacyDrugImportDrug drug) => !linkedDrugIds.contains(drug.id))
        .toList(growable: false);
  }

  bool _clearsMissingStock(PharmacyDrugImportPreview preview) {
    return _stockMode == PharmacyDrugImportStockMode.replace &&
        _clearMissingStock &&
        _missingStockDrugs(preview).isNotEmpty;
  }

  int _reviewCount(PharmacyDrugImportPreview preview) {
    return preview.products
        .where((PharmacyDrugImportProduct product) => product.requiresReview)
        .length;
  }

  bool _canImport(PharmacyDrugImportPreview preview) {
    return !_isBusy &&
        preview.planHash != null &&
        (_importCount(preview) > 0 || _clearsMissingStock(preview)) &&
        (_reviewCount(preview) == 0 || _reviewConfirmed);
  }

  List<PharmacyDrugImportProduct> _productsFor(
    PharmacyDrugImportPreview preview,
    _ProductFilter filter,
  ) {
    return preview.products
        .where(
          (PharmacyDrugImportProduct product) => switch (filter) {
            _ProductFilter.all => true,
            _ProductFilter.newProducts =>
              product.status == PharmacyDrugImportStatus.newProduct,
            _ProductFilter.existing =>
              product.status == PharmacyDrugImportStatus.existing,
            _ProductFilter.review => product.requiresReview,
            _ProductFilter.issues =>
              product.issues.isNotEmpty ||
                  (_rowIssuesByProduct[product.key]?.isNotEmpty ?? false),
            _ProductFilter.skipped =>
              _actionFor(product) == PharmacyDrugImportAction.skip,
          },
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final (Widget content, List<Widget> actions) = switch ((
      _step,
      _preview,
      _result,
    )) {
      (_ImportStep.review, final PharmacyDrugImportPreview preview?, _) => (
        _buildReview(context, preview),
        _reviewActions(context, preview),
      ),
      (_ImportStep.result, _, final PharmacyDrugImportResult result?) => (
        _buildResult(context, result),
        <Widget>[
          AppButton.primary(
            label: l10n.pharmacyDrugImportDoneAction,
            leadingIcon: Icons.check,
            onPressed: () => Navigator.of(context).pop(result),
          ),
        ],
      ),
      _ => (_buildSetup(context), _setupActions(context)),
    };

    return AppDialog(
      title: Text(l10n.pharmacyDrugImportDialogTitle),
      icon: const Icon(Icons.upload_file_outlined),
      scrollable: true,
      maxWidth: 960,
      closeEnabled: !_isBusy,
      content: content,
      actions: actions,
    );
  }

  Widget _buildSetup(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final PharmacyDrugImportPreview? preview = _preview;
    final PharmacyDrugImportFile? file = _file;
    final String sourceLabel = _sourceLabel(l10n, _source);
    final String? facilityName = preview?.facilityName ?? widget.facilityName;
    final Set<String> missingColumns =
        preview?.template.missingColumns.toSet() ?? const <String>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AppFormInformationBanner(
          title: facilityName == null
              ? l10n.pharmacyDrugImportFacilityFallbackTitle
              : l10n.pharmacyDrugImportFacilityTitle(facilityName),
          message: l10n.pharmacyDrugImportFacilityBody,
        ),
        SizedBox(height: theme.spacing.md),
        AppSelectField<PharmacyDrugImportSource>(
          labelText: l10n.pharmacyDrugImportSourceLabel,
          helperText: l10n.pharmacyDrugImportSourceHelper,
          isRequired: true,
          allowClear: false,
          enabled: !_isBusy,
          value: _source,
          options: <AppSelectOption<PharmacyDrugImportSource>>[
            for (final PharmacyDrugImportSource source
                in PharmacyDrugImportSource.values)
              AppSelectOption<PharmacyDrugImportSource>(
                value: source,
                label: _sourceLabel(l10n, source),
              ),
          ],
          onChanged: (PharmacyDrugImportSource? value) {
            if (value == null || value == _source) {
              return;
            }
            setState(() {
              _source = value;
              _clearAnalysis();
            });
          },
        ),
        SizedBox(height: theme.spacing.md),
        AppSectionPanel(
          title: l10n.pharmacyDrugImportTemplateTitle(sourceLabel),
          description: l10n.pharmacyDrugImportTemplateBody,
          leadingIcon: Icons.table_chart_outlined,
          density: AppContentPanelDensity.compact,
          initiallyExpanded: false,
          children: <Widget>[
            Wrap(
              spacing: theme.spacing.xs,
              runSpacing: theme.spacing.xs,
              children: <Widget>[
                for (final String column in _source.templateColumns)
                  AppStatusBadge(
                    label: column,
                    tone: missingColumns.contains(column)
                        ? AppWorkspaceStatusTone.error
                        : AppWorkspaceStatusTone.neutral,
                  ),
              ],
            ),
          ],
        ),
        SizedBox(height: theme.spacing.md),
        AppFileUploadPanel(
          title: l10n.pharmacyDrugImportFileTitle,
          emptyDescription: l10n.pharmacyDrugImportFileEmpty,
          chooseLabel: file == null
              ? l10n.pharmacyDrugImportChooseFileAction
              : l10n.pharmacyDrugImportReplaceFileAction,
          clearLabel: l10n.commonClearActionLabel,
          fileNames: <String>[?file?.name],
          enabled: !_isAnalyzing && !_isImporting,
          isLoading: _isPickingFile,
          onChoose: () => unawaited(_chooseFile()),
          onClear: () => setState(() {
            _file = null;
            _clearAnalysis();
          }),
        ),
        if (_fileReadFailed) ...<Widget>[
          SizedBox(height: theme.spacing.md),
          AppFormInformationBanner(
            title: l10n.pharmacyDrugImportFileReadFailedTitle,
            message: l10n.pharmacyDrugImportFileReadFailedBody,
            variant: AppFormInformationVariant.error,
          ),
        ],
        if (_isAnalyzing) ...<Widget>[
          SizedBox(height: theme.spacing.md),
          AppLoadingIndicator.compact(
            title: l10n.pharmacyDrugImportAnalyzingTitle,
            body: l10n.pharmacyDrugImportAnalyzingBody,
          ),
        ],
        if (preview != null && !preview.template.isValid) ...<Widget>[
          SizedBox(height: theme.spacing.md),
          AppFormInformationBanner(
            title: l10n.pharmacyDrugImportTemplateMismatchTitle(sourceLabel),
            message: l10n.pharmacyDrugImportTemplateMismatchBody(
              preview.template.missingColumns.join(', '),
            ),
            variant: AppFormInformationVariant.error,
          ),
        ] else if (preview != null && !preview.canCommit) ...<Widget>[
          SizedBox(height: theme.spacing.md),
          AppFormInformationBanner(
            title: l10n.pharmacyDrugImportEmptyPlanTitle,
            message: l10n.pharmacyDrugImportEmptyPlanBody,
            variant: AppFormInformationVariant.warning,
          ),
        ],
        if (_failure case final AppFailure failure) ...<Widget>[
          SizedBox(height: theme.spacing.md),
          AppFormInformationBanner.failure(
            context: context,
            failure: failure,
            onRetry: file == null ? null : () => unawaited(_analyze()),
          ),
        ],
      ],
    );
  }

  List<Widget> _setupActions(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return <Widget>[
      AppButton.close(
        label: l10n.commonCancelActionLabel,
        enabled: !_isBusy,
        onPressed: () => Navigator.of(context).pop(),
      ),
      AppButton.primary(
        label: l10n.pharmacyDrugImportAnalyzeAction,
        leadingIcon: Icons.fact_check_outlined,
        isLoading: _isAnalyzing,
        enabled: _file != null && !_isBusy,
        onPressed: () => unawaited(_analyze()),
      ),
    ];
  }

  Widget _buildReview(BuildContext context, PharmacyDrugImportPreview preview) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final Locale locale = Localizations.localeOf(context);
    final PharmacyDrugImportSummary summary = preview.summary;
    final List<PharmacyDrugImportProduct> filtered = _productsFor(
      preview,
      _filter,
    );
    final List<PharmacyDrugImportProduct> visible = filtered
        .take(_visibleProductCount)
        .toList(growable: false);
    final List<PharmacyDrugImportDrug> missingStock = _missingStockDrugs(
      preview,
    );
    final bool replacesStock =
        _stockMode == PharmacyDrugImportStockMode.replace;
    final int reviewCount = _reviewCount(preview);
    String count(num value) => AppFormatters.decimal(value, locale);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AppFormInformationBanner(
          title: l10n.pharmacyDrugImportReviewTitle(
            preview.fileName ?? _file?.name ?? '',
          ),
          message: l10n.pharmacyDrugImportReviewBody,
        ),
        SizedBox(height: theme.spacing.md),
        Wrap(
          spacing: theme.spacing.xs,
          runSpacing: theme.spacing.xs,
          children: <Widget>[
            AppStatusBadge(
              label: l10n.pharmacyDrugImportSummaryRows(count(summary.totalRows)),
            ),
            AppStatusBadge(
              label: l10n.pharmacyDrugImportSummaryProducts(
                count(summary.products),
              ),
            ),
            AppStatusBadge(
              label: l10n.pharmacyDrugImportSummaryNew(
                count(summary.newProducts),
              ),
              tone: AppWorkspaceStatusTone.success,
            ),
            AppStatusBadge(
              label: l10n.pharmacyDrugImportSummaryExisting(
                count(summary.existingProducts),
              ),
              tone: AppWorkspaceStatusTone.info,
            ),
            AppStatusBadge(
              label: l10n.pharmacyDrugImportSummaryReview(count(reviewCount)),
              tone: reviewCount > 0
                  ? AppWorkspaceStatusTone.warning
                  : AppWorkspaceStatusTone.neutral,
            ),
            if (summary.duplicateRows > 0)
              AppStatusBadge(
                label: l10n.pharmacyDrugImportSummaryDuplicates(
                  count(summary.duplicateRows),
                ),
                tone: AppWorkspaceStatusTone.warning,
              ),
            if (summary.errorRows > 0)
              AppStatusBadge(
                label: l10n.pharmacyDrugImportSummaryErrors(
                  count(summary.errorRows),
                ),
                tone: AppWorkspaceStatusTone.error,
              ),
            if (summary.warnings > 0)
              AppStatusBadge(
                label: l10n.pharmacyDrugImportSummaryWarnings(
                  count(summary.warnings),
                ),
                tone: AppWorkspaceStatusTone.warning,
              ),
            AppStatusBadge(
              label: l10n.pharmacyDrugImportSummaryQuantity(
                count(summary.totalQuantity),
                count(summary.batches),
              ),
            ),
          ],
        ),
        if (!preview.canWritePricing) ...<Widget>[
          SizedBox(height: theme.spacing.md),
          AppFormInformationBanner(
            title: l10n.pharmacyDrugImportPricingTitle,
            message: l10n.pharmacyDrugImportPricingBody,
            variant: AppFormInformationVariant.warning,
          ),
        ],
        SizedBox(height: theme.spacing.md),
        AppRadioGroup<PharmacyDrugImportStockMode>(
          labelText: l10n.pharmacyDrugImportStockModeLabel,
          value: _stockMode,
          enabled: !_isBusy,
          options: <AppRadioOption<PharmacyDrugImportStockMode>>[
            AppRadioOption<PharmacyDrugImportStockMode>(
              value: PharmacyDrugImportStockMode.replace,
              label: l10n.pharmacyDrugImportStockModeReplace,
              description: l10n.pharmacyDrugImportStockModeReplaceDescription,
            ),
            AppRadioOption<PharmacyDrugImportStockMode>(
              value: PharmacyDrugImportStockMode.add,
              label: l10n.pharmacyDrugImportStockModeAdd,
              description: l10n.pharmacyDrugImportStockModeAddDescription,
            ),
          ],
          onChanged: (PharmacyDrugImportStockMode? value) {
            if (value != null) {
              setState(() => _stockMode = value);
            }
          },
        ),
        if (missingStock.isNotEmpty) ...<Widget>[
          SizedBox(height: theme.spacing.sm),
          AppCheckboxField(
            title: l10n.pharmacyDrugImportClearMissingLabel(
              count(missingStock.length),
            ),
            subtitle: replacesStock
                ? l10n.pharmacyDrugImportClearMissingSubtitle(
                    _drugNameList(l10n, missingStock),
                  )
                : l10n.pharmacyDrugImportClearMissingReplaceOnly,
            value: replacesStock && _clearMissingStock,
            enabled: replacesStock && !_isBusy,
            onChanged: (bool value) =>
                setState(() => _clearMissingStock = value),
          ),
        ],
        SizedBox(height: theme.spacing.md),
        AppSelectField<_ProductFilter>(
          labelText: l10n.pharmacyDrugImportFilterLabel,
          value: _filter,
          allowClear: false,
          enabled: !_isBusy,
          options: <AppSelectOption<_ProductFilter>>[
            for (final _ProductFilter filter in _ProductFilter.values)
              AppSelectOption<_ProductFilter>(
                value: filter,
                label: l10n.pharmacyDrugImportFilterOption(
                  _filterLabel(l10n, filter),
                  count(_productsFor(preview, filter).length),
                ),
              ),
          ],
          onChanged: (_ProductFilter? value) {
            if (value == null) {
              return;
            }
            setState(() {
              _filter = value;
              _visibleProductCount = _productPageSize;
            });
          },
        ),
        SizedBox(height: theme.spacing.sm),
        if (visible.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: theme.spacing.md),
            child: Text(
              l10n.pharmacyDrugImportNoProductsInFilter,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        for (final PharmacyDrugImportProduct product in visible) ...<Widget>[
          _PharmacyDrugImportProductCard(
            key: ValueKey<String>('pharmacy-drug-import-${product.key}'),
            product: product,
            rowIssues:
                _rowIssuesByProduct[product.key] ??
                const <PharmacyDrugImportIssue>[],
            action: _actionFor(product),
            targetDrugId: _targetFor(product),
            canWritePricing: preview.canWritePricing,
            enabled: !_isBusy,
            onActionChanged: (PharmacyDrugImportAction action) =>
                setState(() => _actions[product.key] = action),
            onTargetChanged: (String drugId) =>
                setState(() => _targets[product.key] = drugId),
          ),
          SizedBox(height: theme.spacing.sm),
        ],
        if (filtered.length > visible.length)
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton.tertiary(
              label: l10n.pharmacyDrugImportShowMoreAction(
                count(
                  math.min(_productPageSize, filtered.length - visible.length),
                ),
              ),
              leadingIcon: Icons.expand_more,
              enabled: !_isBusy,
              onPressed: () =>
                  setState(() => _visibleProductCount += _productPageSize),
            ),
          ),
        if (preview.issues.isNotEmpty) ...<Widget>[
          SizedBox(height: theme.spacing.md),
          _buildRowIssues(context, preview),
        ],
        if (reviewCount > 0) ...<Widget>[
          SizedBox(height: theme.spacing.md),
          AppCheckboxField(
            title: l10n.pharmacyDrugImportReviewConfirm(count(reviewCount)),
            value: _reviewConfirmed,
            enabled: !_isBusy,
            onChanged: (bool value) => setState(() => _reviewConfirmed = value),
          ),
        ],
        if (_isImporting) ...<Widget>[
          SizedBox(height: theme.spacing.md),
          AppLoadingIndicator.compact(
            title: l10n.pharmacyDrugImportImportingTitle,
            body: l10n.pharmacyDrugImportImportingBody,
          ),
        ],
        if (_failure case final AppFailure failure) ...<Widget>[
          SizedBox(height: theme.spacing.md),
          AppFormInformationBanner.failure(
            context: context,
            failure: failure,
            children: <Widget>[
              if (failure.category == AppFailureCategory.conflict)
                AppButton.secondary(
                  label: l10n.pharmacyDrugImportReanalyzeAction,
                  leadingIcon: Icons.refresh,
                  enabled: !_isBusy,
                  onPressed: () => unawaited(_analyze()),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildRowIssues(
    BuildContext context,
    PharmacyDrugImportPreview preview,
  ) {
    final AppLocalizations l10n = context.l10n;
    final Locale locale = Localizations.localeOf(context);
    final List<PharmacyDrugImportIssue> visible = preview.issues
        .take(_visibleIssueCount)
        .toList(growable: false);
    final int remaining = preview.issues.length - visible.length;

    return AppSectionPanel(
      title: l10n.pharmacyDrugImportRowIssuesTitle(
        AppFormatters.decimal(preview.issues.length, locale),
      ),
      leadingIcon: Icons.rule_outlined,
      density: AppContentPanelDensity.compact,
      initiallyExpanded: false,
      children: <Widget>[
        for (final PharmacyDrugImportIssue issue in visible)
          _PharmacyDrugImportIssueLine(
            issue: issue,
            productName: _productsByKey[issue.productKey]?.displayName,
          ),
        if (remaining > 0)
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton.tertiary(
              label: l10n.pharmacyDrugImportShowMoreAction(
                AppFormatters.decimal(
                  math.min(_issuePageSize, remaining),
                  locale,
                ),
              ),
              leadingIcon: Icons.expand_more,
              onPressed: () =>
                  setState(() => _visibleIssueCount += _issuePageSize),
            ),
          ),
      ],
    );
  }

  List<Widget> _reviewActions(
    BuildContext context,
    PharmacyDrugImportPreview preview,
  ) {
    final AppLocalizations l10n = context.l10n;
    final Locale locale = Localizations.localeOf(context);
    return <Widget>[
      AppButton.tertiary(
        label: l10n.commonBackActionLabel,
        leadingIcon: Icons.arrow_back,
        enabled: !_isBusy,
        onPressed: () => setState(() {
          _step = _ImportStep.setup;
          _failure = null;
        }),
      ),
      AppButton.close(
        label: l10n.commonCancelActionLabel,
        enabled: !_isBusy,
        onPressed: () => Navigator.of(context).pop(),
      ),
      AppButton.primary(
        label: l10n.pharmacyDrugImportSubmitAction(
          AppFormatters.decimal(_importCount(preview), locale),
        ),
        leadingIcon: Icons.cloud_upload_outlined,
        isLoading: _isImporting,
        enabled: _canImport(preview),
        onPressed: () => unawaited(_import()),
      ),
    ];
  }

  Widget _buildResult(BuildContext context, PharmacyDrugImportResult result) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final Locale locale = Localizations.localeOf(context);
    final String? facilityName = result.facilityName ?? _preview?.facilityName;
    String count(num value) => AppFormatters.decimal(value, locale);
    final List<String> lines = <String>[
      l10n.pharmacyDrugImportResultCreated(count(result.created)),
      l10n.pharmacyDrugImportResultMerged(count(result.merged)),
      l10n.pharmacyDrugImportResultUpdated(count(result.updated)),
      l10n.pharmacyDrugImportResultSkipped(count(result.skipped)),
      if (result.suppliersCreated > 0)
        l10n.pharmacyDrugImportResultSuppliers(count(result.suppliersCreated)),
      l10n.pharmacyDrugImportResultBatches(
        count(result.batchesCreated),
        count(result.batchesUpdated),
        count(result.batchesCleared),
      ),
      l10n.pharmacyDrugImportResultStock(
        count(result.stockRowsCreated),
        count(result.stockRowsAdjusted),
        count(result.stockCleared),
      ),
      l10n.pharmacyDrugImportResultQuantity(count(result.quantityImported)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AppFormInformationBanner(
          title: l10n.pharmacyDrugImportResultTitle,
          message: facilityName == null
              ? l10n.pharmacyDrugImportResultBodyFallback
              : l10n.pharmacyDrugImportResultBody(facilityName),
          variant: AppFormInformationVariant.success,
        ),
        SizedBox(height: theme.spacing.md),
        for (final String line in lines)
          Padding(
            padding: EdgeInsets.only(bottom: theme.spacing.xs),
            child: Text(line, style: theme.textTheme.bodyMedium),
          ),
      ],
    );
  }
}

class _PharmacyDrugImportProductCard extends StatelessWidget {
  const _PharmacyDrugImportProductCard({
    required this.product,
    required this.rowIssues,
    required this.action,
    required this.targetDrugId,
    required this.canWritePricing,
    required this.enabled,
    required this.onActionChanged,
    required this.onTargetChanged,
    super.key,
  });

  final PharmacyDrugImportProduct product;
  final List<PharmacyDrugImportIssue> rowIssues;
  final PharmacyDrugImportAction action;
  final String? targetDrugId;
  final bool canWritePricing;
  final bool enabled;
  final ValueChanged<PharmacyDrugImportAction> onActionChanged;
  final ValueChanged<String> onTargetChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final Locale locale = Localizations.localeOf(context);
    final TextStyle? detailStyle = theme.textTheme.bodySmall;
    final AppWorkspaceStatusTone tone = _statusTone(product.status);
    final PharmacyDrugImportCandidate? target = action.linksExistingDrug
        ? product.linkOptionFor(targetDrugId)
        : null;
    // Merge applies only values that fill empty catalog fields.
    final List<PharmacyDrugImportChange> changes =
        target?.changes
            .where(
              (PharmacyDrugImportChange change) =>
                  action == PharmacyDrugImportAction.update ||
                  change.fillsBlank,
            )
            .toList(growable: false) ??
        const <PharmacyDrugImportChange>[];

    return AppSectionPanel(
      title: product.displayName,
      description: _productDetails(l10n, locale, product, canWritePricing),
      leadingIcon: Icons.medication_outlined,
      tone: tone,
      density: AppContentPanelDensity.compact,
      collapsible: false,
      trailing: AppStatusBadge(
        label: _statusLabel(l10n, product.status),
        tone: tone,
      ),
      children: <Widget>[
        AppResponsiveFieldRow.two(
          left: AppSelectField<PharmacyDrugImportAction>(
            labelText: l10n.pharmacyDrugImportActionLabel,
            value: action,
            allowClear: false,
            isDense: true,
            enabled: enabled,
            options: <AppSelectOption<PharmacyDrugImportAction>>[
              for (final PharmacyDrugImportAction option
                  in product.allowedActions)
                AppSelectOption<PharmacyDrugImportAction>(
                  value: option,
                  label: _actionLabel(l10n, option),
                ),
            ],
            onChanged: (PharmacyDrugImportAction? value) {
              if (value != null) {
                onActionChanged(value);
              }
            },
          ),
          right: target == null
              ? const SizedBox.shrink()
              : AppSelectField<String>(
                  labelText: l10n.pharmacyDrugImportTargetLabel,
                  value: target.drug.id,
                  allowClear: false,
                  isDense: true,
                  enabled: enabled && product.linkOptions.length > 1,
                  options: <AppSelectOption<String>>[
                    for (final PharmacyDrugImportCandidate option
                        in product.linkOptions)
                      AppSelectOption<String>(
                        value: option.drug.id,
                        label: _linkOptionLabel(l10n, option),
                      ),
                  ],
                  onChanged: (String? value) {
                    if (value != null) {
                      onTargetChanged(value);
                    }
                  },
                ),
        ),
        Text(_batchesText(l10n, locale, product), style: detailStyle),
        if (target != null) ...<Widget>[
          Text(
            l10n.pharmacyDrugImportCurrentStock(
              AppFormatters.decimal(target.drug.facilityQuantity, locale),
            ),
            style: detailStyle,
          ),
          if (changes.isEmpty)
            Text(l10n.pharmacyDrugImportNoChanges, style: detailStyle)
          else
            for (final PharmacyDrugImportChange change in changes)
              Text(_changeText(l10n, locale, change), style: detailStyle),
        ],
        for (final PharmacyDrugImportIssue issue
            in <PharmacyDrugImportIssue>[...product.issues, ...rowIssues])
          _PharmacyDrugImportIssueLine(issue: issue),
      ],
    );
  }
}

class _PharmacyDrugImportIssueLine extends StatelessWidget {
  const _PharmacyDrugImportIssueLine({required this.issue, this.productName});

  final PharmacyDrugImportIssue issue;
  final String? productName;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Locale locale = Localizations.localeOf(context);
    final int? rowNumber = issue.rowNumber;
    final String label = <String>[
      if (rowNumber != null) l10n.pharmacyDrugImportRowLabel('$rowNumber'),
      ?productName,
      pharmacyDrugImportIssueMessage(l10n, locale, issue),
    ].join(' · ');

    return AppStatusText(
      label: label,
      tone: switch (issue.severity) {
        PharmacyDrugImportIssueSeverity.error => AppWorkspaceStatusTone.error,
        PharmacyDrugImportIssueSeverity.warning =>
          AppWorkspaceStatusTone.warning,
        PharmacyDrugImportIssueSeverity.info => AppWorkspaceStatusTone.info,
      },
      maxLines: 4,
      softWrap: true,
    );
  }
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
    'MAX_PRICE_BELOW_PRICE' => l10n.pharmacyDrugImportIssueMaxPriceBelowPrice(
      number(text('retail_price_max')),
      number(text('retail_price')),
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

String _sourceLabel(AppLocalizations l10n, PharmacyDrugImportSource source) {
  return switch (source) {
    PharmacyDrugImportSource.medicErp => l10n.pharmacyDrugImportSourceMedicErp,
  };
}

String _statusLabel(AppLocalizations l10n, PharmacyDrugImportStatus status) {
  return switch (status) {
    PharmacyDrugImportStatus.newProduct => l10n.pharmacyDrugImportStatusNew,
    PharmacyDrugImportStatus.existing => l10n.pharmacyDrugImportStatusExisting,
    PharmacyDrugImportStatus.similar => l10n.pharmacyDrugImportStatusSimilar,
  };
}

AppWorkspaceStatusTone _statusTone(PharmacyDrugImportStatus status) {
  return switch (status) {
    PharmacyDrugImportStatus.newProduct => AppWorkspaceStatusTone.success,
    PharmacyDrugImportStatus.existing => AppWorkspaceStatusTone.info,
    PharmacyDrugImportStatus.similar => AppWorkspaceStatusTone.warning,
  };
}

String _actionLabel(AppLocalizations l10n, PharmacyDrugImportAction action) {
  return switch (action) {
    PharmacyDrugImportAction.create => l10n.pharmacyDrugImportActionCreate,
    PharmacyDrugImportAction.merge => l10n.pharmacyDrugImportActionMerge,
    PharmacyDrugImportAction.update => l10n.pharmacyDrugImportActionUpdate,
    PharmacyDrugImportAction.skip => l10n.pharmacyDrugImportActionSkip,
  };
}

String _filterLabel(AppLocalizations l10n, _ProductFilter filter) {
  return switch (filter) {
    _ProductFilter.all => l10n.pharmacyDrugImportFilterAll,
    _ProductFilter.newProducts => l10n.pharmacyDrugImportFilterNew,
    _ProductFilter.existing => l10n.pharmacyDrugImportFilterExisting,
    _ProductFilter.review => l10n.pharmacyDrugImportFilterReview,
    _ProductFilter.issues => l10n.pharmacyDrugImportFilterIssues,
    _ProductFilter.skipped => l10n.pharmacyDrugImportFilterSkipped,
  };
}

String _linkOptionLabel(
  AppLocalizations l10n,
  PharmacyDrugImportCandidate option,
) {
  final int? score = option.score;
  return score == null
      ? l10n.pharmacyDrugImportExactMatchOption(option.drug.displayName)
      : l10n.pharmacyDrugImportCandidateOption(
          option.drug.displayName,
          '$score',
        );
}

String _drugNameList(
  AppLocalizations l10n,
  List<PharmacyDrugImportDrug> drugs,
) {
  final String names = drugs
      .take(_namePreviewCount)
      .map((PharmacyDrugImportDrug drug) => drug.displayName)
      .join(', ');
  final int remaining = drugs.length - _namePreviewCount;
  return remaining > 0
      ? l10n.pharmacyDrugImportMoreNames(names, '$remaining')
      : names;
}

String _productDetails(
  AppLocalizations l10n,
  Locale locale,
  PharmacyDrugImportProduct product,
  bool canWritePricing,
) {
  String count(num value) => AppFormatters.decimal(value, locale);
  final String rows = product.rowNumbers.take(_rowPreviewCount).join(', ');
  final num? unitPrice = product.unitPrice;
  final num? buyUnitPrice = product.buyUnitPrice;
  return <String>[
    ?product.form,
    ?product.strength,
    l10n.pharmacyDrugImportQuantityLabel(count(product.totalQuantity)),
    l10n.pharmacyDrugImportBatchesLabel(count(product.batches.length)),
    if (canWritePricing && unitPrice != null)
      l10n.pharmacyDrugImportRetailPriceLabel(count(unitPrice)),
    if (canWritePricing && buyUnitPrice != null)
      l10n.pharmacyDrugImportCostLabel(count(buyUnitPrice)),
    l10n.pharmacyDrugImportRowsLabel(
      product.rowNumbers.length > _rowPreviewCount ? '$rows…' : rows,
    ),
  ].join(' · ');
}

String _batchesText(
  AppLocalizations l10n,
  Locale locale,
  PharmacyDrugImportProduct product,
) {
  final String batches = product.batches
      .take(_batchPreviewCount)
      .map((PharmacyDrugImportBatch batch) {
        final DateTime? expiryDate = batch.expiryDate;
        return l10n.pharmacyDrugImportBatchLine(
          batch.batchNumber ?? l10n.pharmacyDrugImportUnlabeledBatch,
          expiryDate == null
              ? l10n.pharmacyDrugImportNoExpiry
              : AppFormatters.mediumDate(expiryDate, locale),
          AppFormatters.decimal(batch.quantity, locale),
        );
      })
      .join('; ');
  final int remaining = product.batches.length - _batchPreviewCount;
  return remaining > 0
      ? '$batches ${l10n.pharmacyDrugImportMoreBatches('$remaining')}'
      : batches;
}

String _sourceFieldLabel(AppLocalizations l10n, String? field) {
  return switch (field) {
    'product_name' => l10n.pharmacyDrugImportFieldProductName,
    'product_brand' => l10n.pharmacyDrugImportFieldBrand,
    'available_quantity' => l10n.pharmacyDrugImportFieldAvailableQuantity,
    'quantity' => l10n.pharmacyDrugImportFieldReceivedQuantity,
    'retail_price' => l10n.pharmacyDrugImportFieldRetailPrice,
    'retail_price_max' => l10n.pharmacyDrugImportFieldMaxRetailPrice,
    'cost' => l10n.pharmacyDrugImportFieldCost,
    'batch_number' => l10n.pharmacyDrugImportFieldBatchNumber,
    'expiry_date' => l10n.pharmacyDrugImportFieldExpiryDate,
    'supplier' => l10n.pharmacyDrugImportFieldSupplier,
    _ => field ?? '',
  };
}

String _catalogFieldLabel(AppLocalizations l10n, String field) {
  return switch (field) {
    'brand_name' => l10n.pharmacyDrugBrandNameLabel,
    'form' => l10n.pharmacyDrugFormLabel,
    'strength' => l10n.pharmacyDrugStrengthLabel,
    'unit_price' => l10n.pharmacyDrugImportFieldRetailPrice,
    'buy_unit_price' => l10n.pharmacyDrugImportFieldCost,
    'supplier_name' => l10n.pharmacyDrugSupplierLabel,
    _ => field,
  };
}

String _changeText(
  AppLocalizations l10n,
  Locale locale,
  PharmacyDrugImportChange change,
) {
  String format(Object? value) => switch (value) {
    final num number => AppFormatters.decimal(number, locale),
    null => '—',
    _ => value.toString(),
  };
  final String label = _catalogFieldLabel(l10n, change.field);
  return change.fillsBlank
      ? l10n.pharmacyDrugImportChangeFillsBlank(
          label,
          format(change.incomingValue),
        )
      : l10n.pharmacyDrugImportChangeValue(
          label,
          format(change.currentValue),
          format(change.incomingValue),
        );
}
