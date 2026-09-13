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
import 'package:hosspi_hms/features/pharmacy/presentation/pharmacy_drug_import_review.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/widgets/pharmacy_drug_import_formatting.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/widgets/pharmacy_drug_import_product_card.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/app_action_dialogs.dart';
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

enum _ProductFilter {
  all,
  newProducts,
  existing,
  review,
  issues,
  edited,
  invalid,
  skipped,
}

enum _FileProblem { unreadable, unsupported }

const int _productPageSize = 25;
const int _namePreviewCount = 5;

/// Imports drugs and facility stock from another system's Excel export.
///
/// Choosing a file uploads and analyzes it straight away. The review lists
/// every product as a collapsed card that opens into an edit form, and nothing
/// is saved until the user imports. Pops with the [PharmacyDrugImportResult].
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

/// Review state of every product for one build.
final class _ReviewSnapshot {
  _ReviewSnapshot(this.reviews) : duplicateKeys = _duplicateRenames(reviews);

  final List<PharmacyDrugImportProductReview> reviews;

  /// Keys of renamed new drugs whose name and brand match another new drug.
  final Set<String> duplicateKeys;

  bool isInvalid(PharmacyDrugImportProductReview review) {
    return review.hasProblems || duplicateKeys.contains(review.product.key);
  }

  static Set<String> _duplicateRenames(
    List<PharmacyDrugImportProductReview> reviews,
  ) {
    if (!reviews.any(
      (PharmacyDrugImportProductReview review) => review.renamesProduct,
    )) {
      return const <String>{};
    }
    final Map<String, int> counts = <String, int>{};
    for (final PharmacyDrugImportProductReview review in reviews) {
      if (review.action == PharmacyDrugImportAction.create) {
        counts[review.identityKey] = (counts[review.identityKey] ?? 0) + 1;
      }
    }
    return <String>{
      for (final PharmacyDrugImportProductReview review in reviews)
        if (review.renamesProduct && (counts[review.identityKey] ?? 0) > 1)
          review.product.key,
    };
  }
}

class _PharmacyDrugImportDialogState extends State<PharmacyDrugImportDialog> {
  final Map<String, PharmacyDrugImportAction> _actions =
      <String, PharmacyDrugImportAction>{};
  final Map<String, String> _targets = <String, String>{};
  final Map<String, PharmacyDrugImportProductDraft> _drafts =
      <String, PharmacyDrugImportProductDraft>{};
  final TextEditingController _searchController = TextEditingController();

  _ImportStep _step = _ImportStep.setup;
  PharmacyDrugImportSource _source = PharmacyDrugImportSource.medicErp;
  PharmacyDrugImportFile? _file;
  _FileProblem? _fileProblem;
  PharmacyDrugImportPreview? _preview;
  Map<String, List<PharmacyDrugImportIssue>> _issuesByProduct =
      const <String, List<PharmacyDrugImportIssue>>{};
  PharmacyDrugImportResult? _result;
  AppFailure? _failure;
  bool _isPickingFile = false;
  bool _isAnalyzing = false;
  bool _isImporting = false;
  PharmacyDrugImportStockMode _stockMode = PharmacyDrugImportStockMode.replace;
  bool _clearMissingStock = false;
  _ProductFilter _filter = _ProductFilter.all;
  String _search = '';
  int _visibleProductCount = _productPageSize;

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

  void _linkTo(PharmacyDrugImportProduct product, String drugId) {
    setState(() {
      _targets[product.key] = drugId;
      if (!_actionFor(product).linksExistingDrug &&
          product.allowedActions.contains(PharmacyDrugImportAction.merge)) {
        _actions[product.key] = PharmacyDrugImportAction.merge;
      }
    });
  }

  void _setDraft(
    PharmacyDrugImportProduct product,
    PharmacyDrugImportProductDraft draft,
  ) {
    setState(() {
      if (draft.isEmpty) {
        _drafts.remove(product.key);
      } else {
        _drafts[product.key] = draft;
      }
    });
  }

  void _clearAnalysis() {
    _preview = null;
    _failure = null;
    _issuesByProduct = const <String, List<PharmacyDrugImportIssue>>{};
    _actions.clear();
    _targets.clear();
    _drafts.clear();
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
    // and edits that the fresh plan still allows.
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
    for (final String key in _drafts.keys.toList()) {
      final PharmacyDrugImportProduct? product = productsByKey[key];
      if (product == null) {
        _drafts.remove(key);
        continue;
      }
      final Set<String> batchKeys = <String>{
        for (final PharmacyDrugImportBatch batch in product.batches) batch.key,
      };
      PharmacyDrugImportProductDraft draft = _drafts[key]!;
      for (final String batchKey in draft.batches.keys.toList()) {
        if (!batchKeys.contains(batchKey)) {
          draft = draft.withBatch(batchKey, null);
        }
      }
      _drafts[key] = draft;
    }

    final Map<String, List<PharmacyDrugImportIssue>> issues =
        <String, List<PharmacyDrugImportIssue>>{
          for (final PharmacyDrugImportProduct product in preview.products)
            product.key: <PharmacyDrugImportIssue>[...product.issues],
        };
    for (final PharmacyDrugImportIssue issue in preview.issues) {
      final String? key = issue.productKey;
      if (key != null) {
        issues[key]?.add(issue);
      }
    }

    _preview = preview;
    _issuesByProduct = issues;
    _visibleProductCount = _productPageSize;
    _step = preview.template.isValid && preview.canCommit
        ? _ImportStep.review
        : _ImportStep.setup;
  }

  PharmacyDrugImportProductReview _reviewFor(
    PharmacyDrugImportProduct product,
    PharmacyDrugImportPreview preview,
  ) {
    final PharmacyDrugImportAction action = _actionFor(product);
    return PharmacyDrugImportProductReview(
      product: product,
      action: action,
      target: action.linksExistingDrug
          ? product.linkOptionFor(_targetFor(product))
          : null,
      draft: _drafts[product.key] ?? PharmacyDrugImportProductDraft.empty,
      canWritePricing: preview.canWritePricing,
    );
  }

  _ReviewSnapshot _snapshot(PharmacyDrugImportPreview preview) {
    return _ReviewSnapshot(
      preview.products
          .map(
            (PharmacyDrugImportProduct product) => _reviewFor(product, preview),
          )
          .toList(growable: false),
    );
  }

  Future<void> _import() async {
    final PharmacyDrugImportPreview? preview = _preview;
    final PharmacyDrugImportFile? file = _file;
    final String? planHash = preview?.planHash;
    if (preview == null || file == null || planHash == null) {
      return;
    }
    final _ReviewSnapshot snapshot = _snapshot(preview);
    if (!_canImport(preview, snapshot)) {
      return;
    }

    final int reviewCount = _pendingReviewCount(snapshot);
    if (reviewCount > 0) {
      final AppLocalizations l10n = context.l10n;
      final bool? confirmed = await showAppDialog<bool>(
        context: context,
        builder: (BuildContext context) => AppConfirmActionDialog(
          title: l10n.pharmacyDrugImportReviewConfirmTitle,
          body: l10n.pharmacyDrugImportReviewConfirmBody(reviewCount),
          submitLabel: l10n.pharmacyDrugImportReviewConfirmSubmit,
          cancelLabel: l10n.pharmacyDrugImportReviewConfirmCancel,
          icon: const Icon(Icons.rule_rounded),
          submitLeadingIcon: Icons.cloud_upload_outlined,
        ),
      );
      if (!mounted) {
        return;
      }
      if (confirmed != true) {
        _setFilter(_ProductFilter.review);
        return;
      }
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
        decisions: snapshot.reviews
            .map(
              (PharmacyDrugImportProductReview review) => review.toDecision(),
            )
            .toList(growable: false),
        stockMode: _stockMode,
        clearMissingStock: _clearsMissingStock(preview),
        // Products that need review were confirmed above or are all skipped.
        confirmReview: preview.products.any(
          (PharmacyDrugImportProduct product) => product.requiresReview,
        ),
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

  /// Products resembling catalog drugs that are still being imported.
  int _pendingReviewCount(_ReviewSnapshot snapshot) {
    return snapshot.reviews
        .where(
          (PharmacyDrugImportProductReview review) =>
              review.product.requiresReview && !review.isSkipped,
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

  bool _canImport(PharmacyDrugImportPreview preview, _ReviewSnapshot snapshot) {
    return !_isBusy &&
        preview.planHash != null &&
        (_importCount(preview) > 0 || _clearsMissingStock(preview)) &&
        !snapshot.reviews.any(snapshot.isInvalid);
  }

  bool _matchesFilter(
    _ReviewSnapshot snapshot,
    PharmacyDrugImportProductReview review,
    _ProductFilter filter,
  ) {
    final PharmacyDrugImportProduct product = review.product;
    return switch (filter) {
      _ProductFilter.all => true,
      _ProductFilter.newProducts =>
        product.status == PharmacyDrugImportStatus.newProduct,
      _ProductFilter.existing =>
        product.status == PharmacyDrugImportStatus.existing,
      _ProductFilter.review => product.requiresReview,
      _ProductFilter.issues =>
        _issuesByProduct[product.key]?.isNotEmpty ?? false,
      _ProductFilter.edited => review.hasEdits,
      _ProductFilter.invalid => snapshot.isInvalid(review),
      _ProductFilter.skipped => review.isSkipped,
    };
  }

  int _countFor(_ReviewSnapshot snapshot, _ProductFilter filter) {
    return snapshot.reviews
        .where(
          (PharmacyDrugImportProductReview review) =>
              _matchesFilter(snapshot, review, filter),
        )
        .length;
  }

  List<PharmacyDrugImportProductReview> _filteredReviews(
    _ReviewSnapshot snapshot,
  ) {
    final String query = _search.trim().toLowerCase();
    return snapshot.reviews
        .where(
          (PharmacyDrugImportProductReview review) =>
              _matchesFilter(snapshot, review, _filter) &&
              (query.isEmpty ||
                  review.product.name.toLowerCase().contains(query) ||
                  (review.product.brandName ?? '').toLowerCase().contains(
                    query,
                  )),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final PharmacyDrugImportPreview? preview = _preview;
    final PharmacyDrugImportResult? result = _result;

    final (Widget body, List<Widget> actions) = switch ((
      _step,
      preview,
      result,
    )) {
      (_ImportStep.review, final PharmacyDrugImportPreview reviewed?, _) =>
        _reviewScreen(context, reviewed),
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

  (Widget, List<Widget>) _reviewScreen(
    BuildContext context,
    PharmacyDrugImportPreview preview,
  ) {
    final _ReviewSnapshot snapshot = _snapshot(preview);
    return (
      _buildReview(context, preview, snapshot),
      _reviewActions(context, preview, snapshot),
    );
  }

  Widget _buildSetup(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final PharmacyDrugImportPreview? preview = _preview;
    final String sourceLabel = pharmacyDrugImportSourceLabel(l10n, _source);

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
    final String sourceLabel = pharmacyDrugImportSourceLabel(l10n, _source);
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
                  label: pharmacyDrugImportSourceLabel(l10n, source),
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
        pharmacyDrugImportSourceLabel(l10n, _source),
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

  Widget _buildReview(
    BuildContext context,
    PharmacyDrugImportPreview preview,
    _ReviewSnapshot snapshot,
  ) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final Locale locale = Localizations.localeOf(context);
    final PharmacyDrugImportSummary summary = preview.summary;
    final List<PharmacyDrugImportProductReview> filtered = _filteredReviews(
      snapshot,
    );
    final List<PharmacyDrugImportProductReview> visible = filtered
        .take(_visibleProductCount)
        .toList(growable: false);
    final int reviewCount = _countFor(snapshot, _ProductFilter.review);
    final int issueProducts = _countFor(snapshot, _ProductFilter.issues);
    final int invalidProducts = _countFor(snapshot, _ProductFilter.invalid);
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
        if (!preview.canWritePricing) ...<Widget>[
          SizedBox(height: theme.spacing.md),
          AppFormInformationBanner(
            title: l10n.pharmacyDrugImportPricingTitle,
            message: l10n.pharmacyDrugImportPricingBody,
            variant: AppFormInformationVariant.warning,
          ),
        ],
        if (invalidProducts > 0) ...<Widget>[
          SizedBox(height: theme.spacing.md),
          AppFormInformationBanner(
            title: l10n.pharmacyDrugImportInvalidBannerTitle(invalidProducts),
            message: l10n.pharmacyDrugImportInvalidBannerBody,
            variant: AppFormInformationVariant.error,
            children: <Widget>[
              if (_filter != _ProductFilter.invalid)
                AppButton.secondary(
                  label: l10n.pharmacyDrugImportShowInvalidAction,
                  leadingIcon: Icons.filter_list_rounded,
                  dense: true,
                  enabled: !_isBusy,
                  onPressed: () => _setFilter(_ProductFilter.invalid),
                ),
            ],
          ),
        ],
        SizedBox(height: theme.spacing.lg),
        _buildSettings(context, preview),
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
                if (filter != _ProductFilter.invalid ||
                    invalidProducts > 0 ||
                    _filter == filter)
                  AppSelectOption<_ProductFilter>(
                    value: filter,
                    label: l10n.pharmacyDrugImportFilterOption(
                      _filterLabel(l10n, filter),
                      count(_countFor(snapshot, filter)),
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
        for (final PharmacyDrugImportProductReview review in visible) ...<Widget>[
          PharmacyDrugImportProductCard(
            key: ValueKey<String>('pharmacy-drug-import-${review.product.key}'),
            source: _source,
            review: review,
            issues:
                _issuesByProduct[review.product.key] ??
                const <PharmacyDrugImportIssue>[],
            stockMode: _stockMode,
            duplicatesAnotherProduct: snapshot.duplicateKeys.contains(
              review.product.key,
            ),
            enabled: !_isBusy,
            onActionChanged: (PharmacyDrugImportAction action) =>
                setState(() => _actions[review.product.key] = action),
            onTargetChanged: (String drugId) =>
                _linkTo(review.product, drugId),
            onDraftChanged: (PharmacyDrugImportProductDraft draft) =>
                _setDraft(review.product, draft),
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
      ],
    );
  }

  Widget _buildSettings(
    BuildContext context,
    PharmacyDrugImportPreview preview,
  ) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final Locale locale = Localizations.localeOf(context);
    final List<PharmacyDrugImportDrug> missingStock = _missingStockDrugs(
      preview,
    );
    final bool replacesStock =
        _stockMode == PharmacyDrugImportStockMode.replace;
    final String summary = <String>[
      if (replacesStock)
        l10n.pharmacyDrugImportSettingsSummaryReplace
      else
        l10n.pharmacyDrugImportSettingsSummaryAdd,
      if (missingStock.isNotEmpty)
        _clearsMissingStock(preview)
            ? l10n.pharmacyDrugImportSettingsSummaryClears(missingStock.length)
            : l10n.pharmacyDrugImportSettingsSummaryKeeps(missingStock.length),
    ].join(' · ');

    return AppCollapsibleSection(
      key: const ValueKey<String>('pharmacy-drug-import-settings'),
      title: l10n.pharmacyDrugImportSettingsTitle,
      subtitle: summary,
      titleIcon: Icons.tune_rounded,
      initiallyExpanded: false,
      description: l10n.pharmacyDrugImportSettingsSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
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
                    description: l10n.pharmacyDrugImportStockModeAddDescription,
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
                AppFormatters.decimal(missingStock.length, locale),
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
    );
  }

  List<Widget> _reviewActions(
    BuildContext context,
    PharmacyDrugImportPreview preview,
    _ReviewSnapshot snapshot,
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
        enabled: _canImport(preview, snapshot),
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

String _filterLabel(AppLocalizations l10n, _ProductFilter filter) {
  return switch (filter) {
    _ProductFilter.all => l10n.pharmacyDrugImportFilterAll,
    _ProductFilter.newProducts => l10n.pharmacyDrugImportFilterNew,
    _ProductFilter.existing => l10n.pharmacyDrugImportFilterExisting,
    _ProductFilter.review => l10n.pharmacyDrugImportFilterReview,
    _ProductFilter.issues => l10n.pharmacyDrugImportFilterIssues,
    _ProductFilter.edited => l10n.pharmacyDrugImportFilterEdited,
    _ProductFilter.invalid => l10n.pharmacyDrugImportFilterInvalid,
    _ProductFilter.skipped => l10n.pharmacyDrugImportFilterSkipped,
  };
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

String _fileDetails(
  AppLocalizations l10n,
  Locale locale,
  PharmacyDrugImportFile file,
  PharmacyDrugImportPreview? preview,
) {
  final String size = pharmacyDrugImportFileSize(
    l10n,
    locale,
    file.bytes.length,
  );
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
