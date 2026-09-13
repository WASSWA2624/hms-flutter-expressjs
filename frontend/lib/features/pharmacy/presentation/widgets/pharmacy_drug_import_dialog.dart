import 'dart:async';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_drug_import.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:hosspi_hms/shared/layout/app_workspace_summary_notification.dart';

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

/// Opens the platform picker for an Excel workbook and reads it into memory.
Future<PharmacyDrugImportFile?> pickPharmacyDrugImportFile({
  required String typeGroupLabel,
}) async {
  final XFile? file = await openFile(
    acceptedTypeGroups: <XTypeGroup>[
      XTypeGroup(label: typeGroupLabel, extensions: const <String>['xlsx']),
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

enum _FileProblem { unreadable, unsupported }

const int _productPageSize = 25;
const int _issuePageSize = 50;
const int _namePreviewCount = 5;
const int _rowPreviewCount = 8;

/// Imports drugs and facility stock from another system's Excel export.
///
/// Choosing a file uploads and analyzes it straight away; the review step shows
/// the server analysis with a decision per product, and nothing is saved until
/// the user confirms. Pops with the [PharmacyDrugImportResult] when done.
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
  final TextEditingController _searchController = TextEditingController();

  _ImportStep _step = _ImportStep.setup;
  PharmacyDrugImportSource _source = PharmacyDrugImportSource.medicErp;
  PharmacyDrugImportFile? _file;
  _FileProblem? _fileProblem;
  PharmacyDrugImportPreview? _preview;
  Map<String, PharmacyDrugImportProduct> _productsByKey =
      const <String, PharmacyDrugImportProduct>{};
  Map<String, List<PharmacyDrugImportIssue>> _rowIssuesByProduct =
      const <String, List<PharmacyDrugImportIssue>>{};
  PharmacyDrugImportResult? _result;
  AppFailure? _failure;
  bool _isPickingFile = false;
  bool _isAnalyzing = false;
  bool _isImporting = false;
  PharmacyDrugImportStockMode _stockMode = PharmacyDrugImportStockMode.replace;
  bool _clearMissingStock = false;
  bool _reviewConfirmed = false;
  _ProductFilter _filter = _ProductFilter.all;
  String _search = '';
  int _visibleProductCount = _productPageSize;
  int _visibleIssueCount = _issuePageSize;

  bool get _isBusy => _isPickingFile || _isAnalyzing || _isImporting;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_searchController.text == _search) {
      return;
    }
    setState(() {
      _search = _searchController.text;
      _visibleProductCount = _productPageSize;
    });
  }

  void _setFilter(_ProductFilter filter) {
    setState(() {
      _filter = filter;
      _visibleProductCount = _productPageSize;
    });
  }

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

  void _clearAnalysis() {
    _preview = null;
    _failure = null;
    _productsByKey = const <String, PharmacyDrugImportProduct>{};
    _rowIssuesByProduct = const <String, List<PharmacyDrugImportIssue>>{};
    _actions.clear();
    _targets.clear();
  }

  Future<void> _chooseFile() async {
    if (_isBusy) {
      return;
    }
    final String typeGroupLabel = context.l10n.pharmacyDrugImportFileTypeLabel;
    final PharmacyDrugImportFilePicker picker =
        widget.pickFile ??
        () => pickPharmacyDrugImportFile(typeGroupLabel: typeGroupLabel);
    setState(() {
      _isPickingFile = true;
      _fileProblem = null;
    });

    PharmacyDrugImportFile? picked;
    _FileProblem? problem;
    try {
      picked = await picker();
    } on Object catch (error, stackTrace) {
      debugPrint('Drug import file could not be read: $error\n$stackTrace');
      problem = _FileProblem.unreadable;
    }
    if (picked != null && !picked.name.toLowerCase().endsWith('.xlsx')) {
      problem = _FileProblem.unsupported;
      picked = null;
    }
    if (!mounted) {
      return;
    }

    final PharmacyDrugImportFile? chosen = picked;
    setState(() {
      _isPickingFile = false;
      _fileProblem = problem;
      if (chosen != null) {
        _file = chosen;
        _clearAnalysis();
      }
    });
    if (chosen != null) {
      // Upload and analyze right away so choosing a file moves the import on.
      unawaited(_analyze());
    }
  }

  Future<void> _analyze() async {
    final PharmacyDrugImportFile? file = _file;
    if (file == null || _isBusy) {
      return;
    }
    setState(() {
      _isAnalyzing = true;
      _failure = null;
      _fileProblem = null;
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

  List<PharmacyDrugImportProduct> _searchedProducts(
    PharmacyDrugImportPreview preview,
  ) {
    final String query = _search.trim().toLowerCase();
    return _productsFor(preview, _filter)
        .where(
          (PharmacyDrugImportProduct product) =>
              query.isEmpty ||
              product.name.toLowerCase().contains(query) ||
              (product.brandName ?? '').toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final PharmacyDrugImportPreview? preview = _preview;
    final PharmacyDrugImportResult? result = _result;
    final int stepIndex = switch (_step) {
      _ImportStep.setup => 0,
      _ImportStep.review => 1,
      _ImportStep.result => 2,
    };
    final bool canOpenReview =
        preview != null && preview.template.isValid && preview.canCommit;

    final (Widget body, List<Widget> actions) = switch ((
      _step,
      preview,
      result,
    )) {
      (_ImportStep.review, final PharmacyDrugImportPreview reviewed?, _) => (
        _buildReview(context, reviewed),
        _reviewActions(context, reviewed),
      ),
      (_ImportStep.result, _, final PharmacyDrugImportResult done?) => (
        _buildResult(context, done),
        <Widget>[
          AppButton.primary(
            label: l10n.pharmacyDrugImportDoneAction,
            leadingIcon: Icons.check_rounded,
            onPressed: () => Navigator.of(context).pop(done),
          ),
        ],
      ),
      _ => (_buildSetup(context), _setupActions(context)),
    };

    final Widget? loading = _isAnalyzing
        ? AppLoadingIndicator(
            title: l10n.pharmacyDrugImportAnalyzingTitle,
            body: l10n.pharmacyDrugImportAnalyzingBody,
            expand: false,
          )
        : _isImporting
        ? AppLoadingIndicator(
            title: l10n.pharmacyDrugImportImportingTitle,
            body: l10n.pharmacyDrugImportImportingBody,
            expand: false,
          )
        : null;

    return AppDialog(
      title: Text(l10n.pharmacyDrugImportDialogTitle),
      icon: const Icon(Icons.upload_file_outlined),
      scrollable: true,
      pinActionsToBottom: true,
      maxWidth: 1120,
      closeEnabled: !_isBusy,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppWizardStepper(
            steps: <AppWizardStepItem>[
              AppWizardStepItem(
                id: _ImportStep.setup,
                label: l10n.pharmacyDrugImportStepFile,
                completed: stepIndex > 0,
              ),
              AppWizardStepItem(
                id: _ImportStep.review,
                label: l10n.pharmacyDrugImportStepReview,
                completed: stepIndex > 1,
                enabled: canOpenReview && result == null,
              ),
              AppWizardStepItem(
                id: _ImportStep.result,
                label: l10n.pharmacyDrugImportStepImport,
                completed: result != null,
                enabled: result != null,
              ),
            ],
            currentIndex: stepIndex,
            showCurrentTitle: false,
            onStepSelected: _isBusy || result != null
                ? null
                : (int index) {
                    if (index == 0) {
                      setState(() => _step = _ImportStep.setup);
                    } else if (index == 1 && canOpenReview) {
                      setState(() => _step = _ImportStep.review);
                    }
                  },
          ),
          SizedBox(height: theme.spacing.md),
          _DestinationBanner(
            facilityName:
                result?.facilityName ?? preview?.facilityName ?? widget.facilityName,
          ),
          SizedBox(height: theme.spacing.lg),
          if (loading != null)
            Padding(
              padding: EdgeInsets.symmetric(vertical: theme.spacing.xxl),
              child: loading,
            )
          else
            body,
        ],
      ),
      actions: actions,
    );
  }

  Widget _buildSetup(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final PharmacyDrugImportPreview? preview = _preview;
    final String sourceLabel = _sourceLabel(l10n, _source);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final Widget source = _buildSourcePanel(context);
            final Widget file = _buildFilePanel(context);
            if (constraints.maxWidth < AppBreakpoints.lg) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  source,
                  SizedBox(height: theme.spacing.md),
                  file,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(flex: 5, child: source),
                SizedBox(width: theme.spacing.md),
                Expanded(flex: 6, child: file),
              ],
            );
          },
        ),
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
            onRetry: _file == null ? null : () => unawaited(_analyze()),
          ),
        ],
      ],
    );
  }

  Widget _buildSourcePanel(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String sourceLabel = _sourceLabel(l10n, _source);
    final Set<String> missingColumns =
        _preview?.template.missingColumns.toSet() ?? const <String>{};

    return AppContentPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _SectionHeading(
            icon: Icons.hub_outlined,
            title: l10n.pharmacyDrugImportSourceSectionTitle,
            subtitle: l10n.pharmacyDrugImportSourceHelper,
          ),
          SizedBox(height: theme.spacing.md),
          AppSelectField<PharmacyDrugImportSource>(
            labelText: l10n.pharmacyDrugImportSourceLabel,
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
          SizedBox(height: theme.spacing.lg),
          Text(
            l10n.pharmacyDrugImportTemplateTitle(sourceLabel),
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: AppFontWeight.semiBold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: theme.spacing.xs),
          Text(
            l10n.pharmacyDrugImportTemplateBody,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: theme.spacing.sm),
          Wrap(
            spacing: theme.spacing.xs,
            runSpacing: theme.spacing.xs,
            children: <Widget>[
              for (final String column in _source.templateColumns)
                _TemplateColumnChip(
                  label: column,
                  missing: missingColumns.contains(column),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilePanel(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return AppContentPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _SectionHeading(
            icon: Icons.table_view_outlined,
            title: l10n.pharmacyDrugImportFileSectionTitle,
            subtitle: l10n.pharmacyDrugImportFileSectionSubtitle,
          ),
          SizedBox(height: theme.spacing.md),
          _buildFilePicker(context, allowRemove: true),
        ],
      ),
    );
  }

  Widget _buildFilePicker(BuildContext context, {required bool allowRemove}) {
    final AppLocalizations l10n = context.l10n;
    final Locale locale = Localizations.localeOf(context);
    final PharmacyDrugImportFile? file = _file;

    return AppFilePickerCard(
      title: l10n.pharmacyDrugImportDropTitle,
      description: l10n.pharmacyDrugImportDropSubtitle(
        _sourceLabel(l10n, _source),
      ),
      browseLabel: l10n.pharmacyDrugImportBrowseAction,
      onBrowse: () => unawaited(_chooseFile()),
      fileName: file?.name,
      fileDetails: file == null
          ? null
          : _fileDetails(l10n, locale, file, _preview),
      replaceLabel: l10n.pharmacyDrugImportReplaceFileAction,
      removeLabel: allowRemove ? l10n.pharmacyDrugImportRemoveFileAction : null,
      onRemove: allowRemove
          ? () => setState(() {
              _file = null;
              _fileProblem = null;
              _clearAnalysis();
            })
          : null,
      isBusy: _isPickingFile,
      busyLabel: l10n.pharmacyDrugImportOpeningFile,
      enabled: !_isAnalyzing && !_isImporting,
      errorText: switch (_fileProblem) {
        _FileProblem.unreadable => l10n.pharmacyDrugImportFileReadFailedBody,
        _FileProblem.unsupported => l10n.pharmacyDrugImportFileUnsupported,
        null => null,
      },
    );
  }

  List<Widget> _setupActions(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final PharmacyDrugImportPreview? preview = _preview;
    final bool canOpenReview =
        preview != null && preview.template.isValid && preview.canCommit;
    return <Widget>[
      AppButton.close(
        label: l10n.commonCancelActionLabel,
        enabled: !_isBusy,
        onPressed: () => Navigator.of(context).pop(),
      ),
      AppButton.primary(
        label: canOpenReview
            ? l10n.pharmacyDrugImportContinueAction
            : l10n.pharmacyDrugImportAnalyzeAction,
        leadingIcon: canOpenReview
            ? Icons.arrow_forward_rounded
            : Icons.fact_check_outlined,
        isLoading: _isAnalyzing,
        enabled: _file != null && !_isBusy,
        onPressed: canOpenReview
            ? () => setState(() => _step = _ImportStep.review)
            : () => unawaited(_analyze()),
      ),
    ];
  }

  Widget _buildReview(BuildContext context, PharmacyDrugImportPreview preview) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final Locale locale = Localizations.localeOf(context);
    final PharmacyDrugImportSummary summary = preview.summary;
    final List<PharmacyDrugImportProduct> filtered = _searchedProducts(preview);
    final List<PharmacyDrugImportProduct> visible = filtered
        .take(_visibleProductCount)
        .toList(growable: false);
    final List<PharmacyDrugImportDrug> missingStock = _missingStockDrugs(
      preview,
    );
    final bool replacesStock =
        _stockMode == PharmacyDrugImportStockMode.replace;
    final int reviewCount = _reviewCount(preview);
    final int issueProducts = _productsFor(
      preview,
      _ProductFilter.issues,
    ).length;
    String count(num value) => AppFormatters.decimal(value, locale);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _buildFilePicker(context, allowRemove: false),
        SizedBox(height: theme.spacing.md),
        AppResponsiveWrap(
          maxColumns: 6,
          minItemWidth: 150,
          children: <Widget>[
            _ImportStatTile(
              icon: Icons.inventory_2_outlined,
              value: count(summary.products),
              label: l10n.pharmacyDrugImportStatProducts,
              selected: _filter == _ProductFilter.all,
              onTap: () => _setFilter(_ProductFilter.all),
            ),
            _ImportStatTile(
              icon: Icons.add_circle_outline_rounded,
              value: count(summary.newProducts),
              label: l10n.pharmacyDrugImportStatNew,
              tone: AppWorkspaceStatusTone.success,
              selected: _filter == _ProductFilter.newProducts,
              onTap: () => _setFilter(_ProductFilter.newProducts),
            ),
            _ImportStatTile(
              icon: Icons.link_rounded,
              value: count(summary.existingProducts),
              label: l10n.pharmacyDrugImportStatExisting,
              tone: AppWorkspaceStatusTone.info,
              selected: _filter == _ProductFilter.existing,
              onTap: () => _setFilter(_ProductFilter.existing),
            ),
            _ImportStatTile(
              icon: Icons.rule_rounded,
              value: count(reviewCount),
              label: l10n.pharmacyDrugImportStatReview,
              tone: reviewCount > 0
                  ? AppWorkspaceStatusTone.warning
                  : AppWorkspaceStatusTone.neutral,
              selected: _filter == _ProductFilter.review,
              onTap: () => _setFilter(_ProductFilter.review),
            ),
            _ImportStatTile(
              icon: Icons.error_outline_rounded,
              value: count(issueProducts),
              label: l10n.pharmacyDrugImportStatIssues,
              tone: summary.errors > 0
                  ? AppWorkspaceStatusTone.error
                  : issueProducts > 0
                  ? AppWorkspaceStatusTone.warning
                  : AppWorkspaceStatusTone.neutral,
              selected: _filter == _ProductFilter.issues,
              onTap: () => _setFilter(_ProductFilter.issues),
            ),
            _ImportStatTile(
              icon: Icons.medication_outlined,
              value: count(summary.totalQuantity),
              label: l10n.pharmacyDrugImportStatUnits(summary.batches),
            ),
          ],
        ),
        if (reviewCount > 0) ...<Widget>[
          SizedBox(height: theme.spacing.md),
          AppFormInformationBanner(
            title: l10n.pharmacyDrugImportReviewBannerTitle(reviewCount),
            message: l10n.pharmacyDrugImportReviewBannerBody,
            variant: _reviewConfirmed
                ? AppFormInformationVariant.success
                : AppFormInformationVariant.warning,
            children: <Widget>[
              AppCheckboxField(
                title: l10n.pharmacyDrugImportReviewConfirm,
                value: _reviewConfirmed,
                enabled: !_isBusy,
                onChanged: (bool value) =>
                    setState(() => _reviewConfirmed = value),
              ),
              if (_filter != _ProductFilter.review)
                AppButton.secondary(
                  label: l10n.pharmacyDrugImportShowReviewAction,
                  leadingIcon: Icons.filter_list_rounded,
                  dense: true,
                  enabled: !_isBusy,
                  onPressed: () => _setFilter(_ProductFilter.review),
                ),
            ],
          ),
        ],
        if (!preview.canWritePricing) ...<Widget>[
          SizedBox(height: theme.spacing.md),
          AppFormInformationBanner(
            title: l10n.pharmacyDrugImportPricingTitle,
            message: l10n.pharmacyDrugImportPricingBody,
            variant: AppFormInformationVariant.warning,
          ),
        ],
        SizedBox(height: theme.spacing.lg),
        AppContentPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _SectionHeading(
                icon: Icons.tune_rounded,
                title: l10n.pharmacyDrugImportSettingsTitle,
                subtitle: l10n.pharmacyDrugImportSettingsSubtitle,
              ),
              SizedBox(height: theme.spacing.md),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  return AppRadioGroup<PharmacyDrugImportStockMode>(
                    labelText: l10n.pharmacyDrugImportStockModeLabel,
                    value: _stockMode,
                    enabled: !_isBusy,
                    layout: constraints.maxWidth >= AppBreakpoints.lg
                        ? AppRadioGroupLayout.horizontal
                        : AppRadioGroupLayout.vertical,
                    options: <AppRadioOption<PharmacyDrugImportStockMode>>[
                      AppRadioOption<PharmacyDrugImportStockMode>(
                        value: PharmacyDrugImportStockMode.replace,
                        label: l10n.pharmacyDrugImportStockModeReplace,
                        description:
                            l10n.pharmacyDrugImportStockModeReplaceDescription,
                      ),
                      AppRadioOption<PharmacyDrugImportStockMode>(
                        value: PharmacyDrugImportStockMode.add,
                        label: l10n.pharmacyDrugImportStockModeAdd,
                        description:
                            l10n.pharmacyDrugImportStockModeAddDescription,
                      ),
                    ],
                    onChanged: (PharmacyDrugImportStockMode? value) {
                      if (value != null) {
                        setState(() => _stockMode = value);
                      }
                    },
                  );
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
            ],
          ),
        ),
        SizedBox(height: theme.spacing.lg),
        _SectionHeading(
          icon: Icons.list_alt_rounded,
          title: l10n.pharmacyDrugImportProductsTitle,
          subtitle: l10n.pharmacyDrugImportProductsSubtitle(
            count(filtered.length),
            count(summary.products),
          ),
        ),
        SizedBox(height: theme.spacing.md),
        AppResponsiveFieldRow.two(
          left: AppTextField(
            controller: _searchController,
            labelText: l10n.pharmacyDrugImportSearchLabel,
            hintText: l10n.pharmacyDrugImportSearchHint,
            prefixIcon: const Icon(Icons.search_rounded),
            allowClear: true,
            enabled: !_isBusy,
          ),
          right: AppSelectField<_ProductFilter>(
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
              if (value != null) {
                _setFilter(value);
              }
            },
          ),
        ),
        SizedBox(height: theme.spacing.md),
        if (visible.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: theme.spacing.xl),
            child: Text(
              l10n.pharmacyDrugImportNoProductsInFilter,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        for (final PharmacyDrugImportProduct product in visible) ...<Widget>[
          _ImportProductRow(
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
          Center(
            child: AppButton.secondary(
              label: l10n.pharmacyDrugImportShowMoreAction(
                count(
                  math.min(_productPageSize, filtered.length - visible.length),
                ),
              ),
              leadingIcon: Icons.expand_more_rounded,
              enabled: !_isBusy,
              onPressed: () =>
                  setState(() => _visibleProductCount += _productPageSize),
            ),
          ),
        if (preview.issues.isNotEmpty) ...<Widget>[
          SizedBox(height: theme.spacing.lg),
          _buildRowIssues(context, preview),
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
                  leadingIcon: Icons.refresh_rounded,
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
    final ThemeData theme = Theme.of(context);
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
      initiallyExpanded: false,
      spacing: theme.spacing.xs,
      children: <Widget>[
        for (final PharmacyDrugImportIssue issue in visible)
          _IssueLine(
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
              leadingIcon: Icons.expand_more_rounded,
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
    return <Widget>[
      AppButton.tertiary(
        label: l10n.pharmacyDrugImportChangeFileAction,
        leadingIcon: Icons.arrow_back_rounded,
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
        label: l10n.pharmacyDrugImportSubmitAction(_importCount(preview)),
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
    final Color success = theme.statusColors.success;
    final String? facilityName = result.facilityName ?? _preview?.facilityName;
    String count(num value) => AppFormatters.decimal(value, locale);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: success.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_rounded, size: 44, color: success),
          ),
        ),
        SizedBox(height: theme.spacing.md),
        Text(
          l10n.pharmacyDrugImportResultTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: AppFontWeight.semiBold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        SizedBox(height: theme.spacing.xs),
        Text(
          facilityName == null
              ? l10n.pharmacyDrugImportResultBodyFallback
              : l10n.pharmacyDrugImportResultBody(facilityName),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: theme.spacing.lg),
        AppResponsiveWrap(
          maxColumns: 4,
          children: <Widget>[
            _ImportStatTile(
              icon: Icons.add_circle_outline_rounded,
              value: count(result.created),
              label: l10n.pharmacyDrugImportResultStatCreated,
              tone: AppWorkspaceStatusTone.success,
            ),
            _ImportStatTile(
              icon: Icons.link_rounded,
              value: count(result.merged),
              label: l10n.pharmacyDrugImportResultStatLinked,
              tone: AppWorkspaceStatusTone.info,
            ),
            _ImportStatTile(
              icon: Icons.edit_note_rounded,
              value: count(result.updated),
              label: l10n.pharmacyDrugImportResultStatUpdated,
              tone: AppWorkspaceStatusTone.info,
            ),
            _ImportStatTile(
              icon: Icons.skip_next_outlined,
              value: count(result.skipped),
              label: l10n.pharmacyDrugImportResultStatSkipped,
            ),
            _ImportStatTile(
              icon: Icons.layers_outlined,
              value: count(result.batchesCreated + result.batchesUpdated),
              label: l10n.pharmacyDrugImportResultStatBatches,
            ),
            _ImportStatTile(
              icon: Icons.medication_outlined,
              value: count(result.quantityImported),
              label: l10n.pharmacyDrugImportResultStatUnits,
            ),
            if (result.stockCleared > 0)
              _ImportStatTile(
                icon: Icons.remove_shopping_cart_outlined,
                value: count(result.stockCleared),
                label: l10n.pharmacyDrugImportResultStatStockCleared,
                tone: AppWorkspaceStatusTone.warning,
              ),
            if (result.suppliersCreated > 0)
              _ImportStatTile(
                icon: Icons.local_shipping_outlined,
                value: count(result.suppliersCreated),
                label: l10n.pharmacyDrugImportResultStatSuppliers,
              ),
          ],
        ),
      ],
    );
  }
}

class _DestinationBanner extends StatelessWidget {
  const _DestinationBanner({required this.facilityName});

  final String? facilityName;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final Color accent = theme.statusColors.info;
    final String? name = facilityName;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(
          context.responsiveRadius(theme.radius.md),
        ),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.md,
          vertical: theme.spacing.sm,
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.local_hospital_outlined, color: accent),
            SizedBox(width: theme.spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    name == null
                        ? l10n.pharmacyDrugImportDestinationFallback
                        : l10n.pharmacyDrugImportDestination(name),
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: AppFontWeight.semiBold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    l10n.pharmacyDrugImportDestinationHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String? subtitleText = subtitle;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(theme.radius.md),
          ),
          child: Icon(icon, size: 20, color: colorScheme.primary),
        ),
        SizedBox(width: theme.spacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: AppFontWeight.semiBold,
                  color: colorScheme.onSurface,
                ),
              ),
              if (subtitleText != null)
                Text(
                  subtitleText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TemplateColumnChip extends StatelessWidget {
  const _TemplateColumnChip({required this.label, required this.missing});

  final String label;
  final bool missing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color error = theme.statusColors.error;
    final Color foreground = missing ? error : colorScheme.onSurfaceVariant;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: missing
            ? error.withValues(alpha: 0.12)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(theme.radius.sm),
        border: Border.all(
          color: missing
              ? error.withValues(alpha: 0.5)
              : theme.borders.faint,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.sm,
          vertical: theme.spacing.xs / 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (missing) ...<Widget>[
              Icon(Icons.close_rounded, size: 14, color: foreground),
              SizedBox(width: theme.spacing.xs / 2),
            ],
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(color: foreground),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportStatTile extends StatelessWidget {
  const _ImportStatTile({
    required this.icon,
    required this.value,
    required this.label,
    this.tone = AppWorkspaceStatusTone.neutral,
    this.selected = false,
    this.onTap,
  });

  final IconData icon;
  final String value;
  final String label;
  final AppWorkspaceStatusTone tone;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color accent = workspaceStatusToneAccentColor(theme, tone);

    return Semantics(
      button: onTap != null,
      selected: selected,
      label: '$value $label',
      excludeSemantics: true,
      child: Material(
        color: selected
            ? accent.withValues(alpha: 0.14)
            : colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            context.responsiveRadius(theme.radius.md),
          ),
          side: selected
              ? BorderSide(color: accent, width: theme.borders.medium)
              : theme.borders.side(),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(theme.spacing.md),
            child: Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(theme.radius.md),
                  ),
                  child: Icon(icon, size: 22, color: accent),
                ),
                SizedBox(width: theme.spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: AppFontWeight.semiBold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ImportProductRow extends StatefulWidget {
  const _ImportProductRow({
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
  State<_ImportProductRow> createState() => _ImportProductRowState();
}

class _ImportProductRowState extends State<_ImportProductRow> {
  // Products that need a decision open with their evidence visible.
  late bool _expanded = widget.product.requiresReview;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Locale locale = Localizations.localeOf(context);
    final PharmacyDrugImportProduct product = widget.product;
    final PharmacyDrugImportAction action = widget.action;
    final AppWorkspaceStatusTone tone = _statusTone(product.status);
    final Color accent = workspaceStatusToneAccentColor(theme, tone);
    final List<PharmacyDrugImportIssue> issues = <PharmacyDrugImportIssue>[
      ...product.issues,
      ...widget.rowIssues,
    ];
    final PharmacyDrugImportCandidate? target = action.linksExistingDrug
        ? product.linkOptionFor(widget.targetDrugId)
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
    final bool hasDetails =
        product.batches.isNotEmpty || target != null || issues.isNotEmpty;
    final String brand = (product.brandName ?? '').trim();
    final TextStyle? muted = theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );

    return AnimatedOpacity(
      opacity: action == PharmacyDrugImportAction.skip ? 0.6 : 1,
      duration: const Duration(milliseconds: 150),
      child: Material(
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            context.responsiveRadius(theme.radius.md),
          ),
          side: theme.borders.side(),
        ),
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: accent, width: 4)),
          ),
          child: Padding(
            padding: EdgeInsets.all(theme.spacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: AppFontWeight.semiBold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          if (brand.isNotEmpty)
                            Text(
                              brand,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(width: theme.spacing.sm),
                    Flexible(
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: theme.spacing.xs,
                        runSpacing: theme.spacing.xs,
                        children: <Widget>[
                          if (issues.isNotEmpty)
                            AppStatusBadge(
                              label: l10n.pharmacyDrugImportIssueCount(
                                issues.length,
                              ),
                              tone: _worstTone(issues),
                            ),
                          AppStatusBadge(
                            label: _statusLabel(l10n, product.status),
                            tone: tone,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: theme.spacing.xs),
                Text(
                  _productDetails(
                    l10n,
                    locale,
                    product,
                    widget.canWritePricing,
                  ),
                  style: muted,
                ),
                SizedBox(height: theme.spacing.md),
                AppResponsiveFieldRow(
                  children: <Widget>[
                    AppSelectField<PharmacyDrugImportAction>(
                      labelText: l10n.pharmacyDrugImportActionLabel,
                      value: action,
                      allowClear: false,
                      isDense: true,
                      enabled: widget.enabled,
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
                          widget.onActionChanged(value);
                        }
                      },
                    ),
                    if (target != null)
                      AppSelectField<String>(
                        labelText: l10n.pharmacyDrugImportTargetLabel,
                        value: target.drug.id,
                        allowClear: false,
                        isDense: true,
                        enabled:
                            widget.enabled && product.linkOptions.length > 1,
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
                            widget.onTargetChanged(value);
                          }
                        },
                      ),
                  ],
                ),
                if (hasDetails)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(top: theme.spacing.xs),
                      child: AppButton.tertiary(
                        label: _expanded
                            ? l10n.pharmacyDrugImportHideDetailsAction
                            : l10n.pharmacyDrugImportShowDetailsAction,
                        leadingIcon: _expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        dense: true,
                        onPressed: () => setState(() => _expanded = !_expanded),
                      ),
                    ),
                  ),
                if (_expanded) ...<Widget>[
                  if (product.batches.isNotEmpty)
                    _DetailBlock(
                      title: l10n.pharmacyDrugImportBatchesTitle,
                      children: <Widget>[
                        for (final PharmacyDrugImportBatch batch
                            in product.batches)
                          Text(_batchLine(l10n, locale, batch), style: muted),
                      ],
                    ),
                  if (target != null)
                    _DetailBlock(
                      title: l10n.pharmacyDrugImportChangesTitle,
                      children: <Widget>[
                        Text(
                          l10n.pharmacyDrugImportCurrentStock(
                            AppFormatters.decimal(
                              target.drug.facilityQuantity,
                              locale,
                            ),
                          ),
                          style: muted,
                        ),
                        if (changes.isEmpty)
                          Text(l10n.pharmacyDrugImportNoChanges, style: muted)
                        else
                          for (final PharmacyDrugImportChange change in changes)
                            Text(
                              _changeText(l10n, locale, change),
                              style: muted,
                            ),
                      ],
                    ),
                  if (issues.isNotEmpty)
                    _DetailBlock(
                      title: l10n.pharmacyDrugImportIssuesTitle,
                      children: <Widget>[
                        for (final PharmacyDrugImportIssue issue in issues)
                          _IssueLine(issue: issue),
                      ],
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(top: theme.spacing.sm),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(theme.radius.sm),
        ),
        child: Padding(
          padding: EdgeInsets.all(theme.spacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                title,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: AppFontWeight.semiBold,
                  color: colorScheme.onSurface,
                ),
              ),
              SizedBox(height: theme.spacing.xs),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _IssueLine extends StatelessWidget {
  const _IssueLine({required this.issue, this.productName});

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

AppWorkspaceStatusTone _worstTone(List<PharmacyDrugImportIssue> issues) {
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

String _formatFileSize(AppLocalizations l10n, Locale locale, int bytes) {
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

String _fileDetails(
  AppLocalizations l10n,
  Locale locale,
  PharmacyDrugImportFile file,
  PharmacyDrugImportPreview? preview,
) {
  final String size = _formatFileSize(l10n, locale, file.bytes.length);
  final String? sheetName = preview?.sheetName;
  if (preview == null || sheetName == null || !preview.template.isValid) {
    return size;
  }
  return l10n.pharmacyDrugImportFileDetails(
    size,
    l10n.pharmacyDrugImportFileMeta(
      sheetName,
      AppFormatters.decimal(preview.summary.totalRows, locale),
    ),
  );
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

String _batchLine(
  AppLocalizations l10n,
  Locale locale,
  PharmacyDrugImportBatch batch,
) {
  final DateTime? expiryDate = batch.expiryDate;
  return l10n.pharmacyDrugImportBatchLine(
    batch.batchNumber ?? l10n.pharmacyDrugImportUnlabeledBatch,
    expiryDate == null
        ? l10n.pharmacyDrugImportNoExpiry
        : AppFormatters.mediumDate(expiryDate, locale),
    AppFormatters.decimal(batch.quantity, locale),
  );
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
