import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_drug_import.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pharmacy_drug_import_review.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/widgets/pharmacy_drug_import_formatting.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:hosspi_hms/shared/layout/app_workspace_summary_notification.dart';

/// Width from which comparison and batch rows lay out as table columns.
const double _tableMinWidth = 760;

const int _fieldFlex = 3;
const int _catalogFlex = 4;
const int _fileFlex = 4;
const int _valueFlex = 6;

/// One product in a drug import review.
///
/// Collapsed, the header summarizes what will be saved. Expanded, it is an
/// edit form: the action to take, the catalog drug to link, a comparison of
/// catalog, file, and editable values, and the batches that will be stocked.
class PharmacyDrugImportProductCard extends StatefulWidget {
  const PharmacyDrugImportProductCard({
    required this.review,
    required this.issues,
    required this.stockMode,
    required this.onActionChanged,
    required this.onTargetChanged,
    required this.onDraftChanged,
    this.duplicatesAnotherProduct = false,
    this.enabled = true,
    super.key,
  });

  final PharmacyDrugImportProductReview review;

  /// Product and row issues found in the file for this product.
  final List<PharmacyDrugImportIssue> issues;

  final PharmacyDrugImportStockMode stockMode;

  /// A renamed new drug has the same name and brand as another new drug.
  final bool duplicatesAnotherProduct;

  final bool enabled;

  final ValueChanged<PharmacyDrugImportAction> onActionChanged;

  /// Links the product to a catalog drug.
  final ValueChanged<String> onTargetChanged;

  final ValueChanged<PharmacyDrugImportProductDraft> onDraftChanged;

  @override
  State<PharmacyDrugImportProductCard> createState() =>
      _PharmacyDrugImportProductCardState();
}

class _PharmacyDrugImportProductCardState
    extends State<PharmacyDrugImportProductCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final PharmacyDrugImportProductReview review = widget.review;
    final PharmacyDrugImportProduct product = review.product;
    final bool invalid = review.hasProblems || widget.duplicatesAnotherProduct;

    return AppCollapsibleSection(
      titleWidget: _ProductHeader(review: review),
      headerActions: _headerBadges(
        context,
        review,
        widget.issues,
        invalid: invalid,
      ),
      titleIcon: review.isSkipped
          ? Icons.block_rounded
          : pharmacyDrugImportStatusIcon(product.status),
      accentColor: review.isSkipped
          ? theme.colorScheme.onSurfaceVariant
          : workspaceStatusToneAccentColor(
              theme,
              pharmacyDrugImportStatusTone(product.status),
            ),
      borderColor: invalid
          ? theme.statusColors.error
          : product.requiresReview && !review.isSkipped
          ? theme.statusColors.warning.withValues(alpha: 0.7)
          : null,
      expanded: _expanded,
      onExpandedChanged: (bool expanded) =>
          setState(() => _expanded = expanded),
      actions: <Widget>[
        AppButton.secondary(
          label: l10n.pharmacyDrugImportDoneEditingAction,
          leadingIcon: Icons.expand_less_rounded,
          dense: true,
          onPressed: () => setState(() => _expanded = false),
        ),
        AppButton.tertiary(
          label: l10n.pharmacyDrugImportResetChangesAction,
          leadingIcon: Icons.undo_rounded,
          dense: true,
          enabled: widget.enabled && !review.draft.isEmpty,
          onPressed: () =>
              widget.onDraftChanged(PharmacyDrugImportProductDraft.empty),
        ),
      ],
      child: _ProductEditor(
        review: review,
        issues: widget.issues,
        stockMode: widget.stockMode,
        duplicatesAnotherProduct: widget.duplicatesAnotherProduct,
        enabled: widget.enabled,
        onActionChanged: widget.onActionChanged,
        onTargetChanged: widget.onTargetChanged,
        onDraftChanged: widget.onDraftChanged,
      ),
    );
  }
}

class _ProductHeader extends StatelessWidget {
  const _ProductHeader({required this.review});

  final PharmacyDrugImportProductReview review;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final PharmacyDrugImportProduct product = review.product;
    final PharmacyDrugImportAction action = review.action;
    final String editedName = review
        .valueText(PharmacyDrugImportField.name)
        .trim();
    final String name =
        action == PharmacyDrugImportAction.create && editedName.isNotEmpty
        ? editedName
        : product.name;
    final String brand = review
        .valueText(PharmacyDrugImportField.brandName)
        .trim();
    final PharmacyDrugImportDrug? linked = review.target?.drug;
    final Color linkColor = theme.statusColors.info;

    final Widget details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text.rich(
          TextSpan(
            children: <InlineSpan>[
              TextSpan(
                text: name,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: AppFontWeight.strong,
                  color: colorScheme.onSurface,
                ),
              ),
              if (brand.isNotEmpty)
                TextSpan(
                  text: '  ·  $brand',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: theme.spacing.xs / 2),
        Text(
          _productFacts(context, review),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        if (linked != null) ...<Widget>[
          SizedBox(height: theme.spacing.xs / 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.link_rounded, size: 16, color: linkColor),
              SizedBox(width: theme.spacing.xs / 2),
              Flexible(
                child: Text(
                  l10n.pharmacyDrugImportLinksTo(linked.displayName),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: linkColor,
                    fontWeight: AppFontWeight.emphasis,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );

    return details;
  }
}

/// Status, action, issue, and edit badges shown at the end of a product header.
List<Widget> _headerBadges(
  BuildContext context,
  PharmacyDrugImportProductReview review,
  List<PharmacyDrugImportIssue> issues, {
  required bool invalid,
}) {
  final AppLocalizations l10n = context.l10n;
  final PharmacyDrugImportProduct product = review.product;
  final PharmacyDrugImportAction action = review.action;

  return <Widget>[
    // New products are already described by their action.
    if (product.status != PharmacyDrugImportStatus.newProduct)
      AppStatusBadge(
        label: pharmacyDrugImportStatusLabel(l10n, product.status),
        tone: pharmacyDrugImportStatusTone(product.status),
      ),
    AppStatusBadge(
      label: pharmacyDrugImportActionLabel(l10n, action),
      icon: pharmacyDrugImportActionIcon(action),
      tone: switch (action) {
        PharmacyDrugImportAction.create => AppWorkspaceStatusTone.success,
        PharmacyDrugImportAction.merge ||
        PharmacyDrugImportAction.update => AppWorkspaceStatusTone.info,
        PharmacyDrugImportAction.skip => AppWorkspaceStatusTone.neutral,
      },
    ),
    if (issues.isNotEmpty)
      AppStatusBadge(
        label: l10n.pharmacyDrugImportIssueCount(issues.length),
        tone: pharmacyDrugImportIssuesTone(issues),
      ),
    if (review.hasEdits)
      AppStatusBadge(
        label: l10n.pharmacyDrugImportEditedBadge,
        icon: Icons.edit_outlined,
        tone: AppWorkspaceStatusTone.info,
      ),
    if (invalid)
      AppStatusBadge(
        label: l10n.pharmacyDrugImportFixBadge,
        tone: AppWorkspaceStatusTone.error,
      ),
  ];
}

class _ProductEditor extends StatefulWidget {
  const _ProductEditor({
    required this.review,
    required this.issues,
    required this.stockMode,
    required this.duplicatesAnotherProduct,
    required this.enabled,
    required this.onActionChanged,
    required this.onTargetChanged,
    required this.onDraftChanged,
  });

  final PharmacyDrugImportProductReview review;
  final List<PharmacyDrugImportIssue> issues;
  final PharmacyDrugImportStockMode stockMode;
  final bool duplicatesAnotherProduct;
  final bool enabled;
  final ValueChanged<PharmacyDrugImportAction> onActionChanged;
  final ValueChanged<String> onTargetChanged;
  final ValueChanged<PharmacyDrugImportProductDraft> onDraftChanged;

  @override
  State<_ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<_ProductEditor> {
  final Map<PharmacyDrugImportField, TextEditingController> _fieldControllers =
      <PharmacyDrugImportField, TextEditingController>{};
  final Map<String, TextEditingController> _batchNumberControllers =
      <String, TextEditingController>{};
  final Map<String, TextEditingController> _quantityControllers =
      <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    _syncControllers();
  }

  @override
  void didUpdateWidget(covariant _ProductEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncControllers();
  }

  @override
  void dispose() {
    for (final TextEditingController controller in <TextEditingController>[
      ..._fieldControllers.values,
      ..._batchNumberControllers.values,
      ..._quantityControllers.values,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  // Fields show the value that will be saved. Typing records an edit, so a
  // field is only rewritten when the action, the link, or a reset changes it.
  void _syncControllers() {
    final PharmacyDrugImportProductReview review = widget.review;
    for (final PharmacyDrugImportField field
        in PharmacyDrugImportField.values) {
      _setText(
        _fieldControllers.putIfAbsent(field, TextEditingController.new),
        review.valueText(field),
      );
    }
    for (final PharmacyDrugImportBatch batch in review.product.batches) {
      final PharmacyDrugImportBatchDraft value = review.batchValue(batch);
      _setText(
        _batchNumberControllers.putIfAbsent(
          batch.key,
          TextEditingController.new,
        ),
        value.batchNumber,
      );
      _setText(
        _quantityControllers.putIfAbsent(batch.key, TextEditingController.new),
        value.quantity,
      );
    }
  }

  static void _setText(TextEditingController controller, String text) {
    if (controller.text != text) {
      controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  void _updateField(PharmacyDrugImportField field, String text) {
    final PharmacyDrugImportProductReview review = widget.review;
    // Typing the suggested value back is the same as leaving it unchanged.
    final String? edit = text == review.suggestedText(field) ? null : text;
    widget.onDraftChanged(review.draft.withField(field, edit));
  }

  void _updateBatch(
    PharmacyDrugImportBatch batch,
    PharmacyDrugImportBatchDraft Function(PharmacyDrugImportBatchDraft value)
    change,
  ) {
    final PharmacyDrugImportProductReview review = widget.review;
    final PharmacyDrugImportBatchDraft value = change(
      review.batchValue(batch),
    );
    widget.onDraftChanged(
      review.draft.withBatch(batch.key, value.matches(batch) ? null : value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final PharmacyDrugImportProductReview review = widget.review;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (widget.issues.isNotEmpty) ...<Widget>[
          _IssueList(issues: widget.issues),
          SizedBox(height: theme.spacing.lg),
        ],
        _EditorSectionTitle(
          icon: Icons.alt_route_rounded,
          title: l10n.pharmacyDrugImportDecisionTitle,
        ),
        SizedBox(height: theme.spacing.sm),
        _buildActionChoices(context),
        ..._buildLinkChoices(context),
        SizedBox(height: theme.spacing.lg),
        _EditorSectionTitle(
          icon: Icons.fact_check_outlined,
          title: l10n.pharmacyDrugImportDetailsTitle,
          subtitle: switch (review.action) {
            PharmacyDrugImportAction.create =>
              l10n.pharmacyDrugImportDetailsHintCreate,
            PharmacyDrugImportAction.merge =>
              l10n.pharmacyDrugImportDetailsHintMerge,
            PharmacyDrugImportAction.update =>
              l10n.pharmacyDrugImportDetailsHintUpdate,
            PharmacyDrugImportAction.skip =>
              l10n.pharmacyDrugImportDetailsHintSkip,
          },
        ),
        SizedBox(height: theme.spacing.sm),
        _buildComparison(context),
        SizedBox(height: theme.spacing.lg),
        _EditorSectionTitle(
          icon: Icons.inventory_2_outlined,
          title: l10n.pharmacyDrugImportStockTitle,
          subtitle: _stockSummary(context),
        ),
        SizedBox(height: theme.spacing.sm),
        _buildBatches(context),
      ],
    );
  }

  Widget _buildActionChoices(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final PharmacyDrugImportProductReview review = widget.review;
    final List<PharmacyDrugImportAction> actions =
        review.product.allowedActions;

    return AppResponsiveWrap(
      maxColumns: math.max(1, actions.length),
      minItemWidth: 210,
      children: <Widget>[
        for (final PharmacyDrugImportAction action in actions)
          _Interactive(
            enabled: widget.enabled,
            child: AppChoiceTile(
              label: pharmacyDrugImportActionLabel(l10n, action),
              subtitle: pharmacyDrugImportActionDescription(l10n, action),
              icon: pharmacyDrugImportActionIcon(action),
              selected: action == review.action,
              onTap: () {
                if (action != review.action) {
                  widget.onActionChanged(action);
                }
              },
            ),
          ),
      ],
    );
  }

  List<Widget> _buildLinkChoices(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final Locale locale = Localizations.localeOf(context);
    final PharmacyDrugImportProductReview review = widget.review;
    final List<PharmacyDrugImportCandidate> options =
        review.product.linkOptions;
    if (options.isEmpty || review.isSkipped) {
      return const <Widget>[];
    }
    final bool links = review.action.linksExistingDrug;

    return <Widget>[
      SizedBox(height: theme.spacing.lg),
      _EditorSectionTitle(
        icon: links ? Icons.link_rounded : Icons.content_copy_rounded,
        title: links
            ? l10n.pharmacyDrugImportLinkTargetTitle
            : l10n.pharmacyDrugImportSimilarDrugsTitle,
        subtitle: links ? null : l10n.pharmacyDrugImportSimilarDrugsHint,
      ),
      SizedBox(height: theme.spacing.sm),
      AppResponsiveWrap(
        maxColumns: 2,
        minItemWidth: 320,
        children: <Widget>[
          for (final PharmacyDrugImportCandidate option in options)
            _Interactive(
              enabled: widget.enabled,
              child: AppChoiceTile(
                label: option.drug.displayName,
                subtitle: _candidateDetails(l10n, locale, option),
                icon: Icons.medication_outlined,
                accentColor: theme.statusColors.info,
                selected: links && option.drug.id == review.target?.drug.id,
                onTap: () => widget.onTargetChanged(option.drug.id),
              ),
            ),
        ],
      ),
    ];
  }

  Widget _buildComparison(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final PharmacyDrugImportProductReview review = widget.review;
    final List<PharmacyDrugImportField> fields = review.fields;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool table = constraints.maxWidth >= _tableMinWidth;
        return _Framed(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (table)
                _TableRow(
                  header: true,
                  cells: <(int, Widget)>[
                    (
                      _fieldFlex,
                      _HeaderText(l10n.pharmacyDrugImportColumnField),
                    ),
                    if (review.isLinked)
                      (
                        _catalogFlex,
                        _HeaderText(l10n.pharmacyDrugImportColumnCatalog),
                      ),
                    (_fileFlex, _HeaderText(l10n.pharmacyDrugImportColumnFile)),
                    (
                      _valueFlex,
                      _HeaderText(l10n.pharmacyDrugImportColumnNewValue),
                    ),
                  ],
                ),
              for (int index = 0; index < fields.length; index += 1) ...<Widget>[
                if (index > 0 || table)
                  Divider(height: 1, color: theme.borders.faint),
                if (table)
                  _comparisonRow(context, fields[index])
                else
                  _comparisonBlock(context, fields[index]),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _comparisonRow(BuildContext context, PharmacyDrugImportField field) {
    final AppLocalizations l10n = context.l10n;
    final PharmacyDrugImportProductReview review = widget.review;

    return _TableRow(
      cells: <(int, Widget)>[
        (
          _fieldFlex,
          _CellText(pharmacyDrugImportFieldLabel(l10n, field), strong: true),
        ),
        if (review.isLinked)
          (_catalogFlex, _valueText(context, field, review.catalogText(field))),
        (_fileFlex, _valueText(context, field, review.fileText(field))),
        (_valueFlex, _valueEditor(context, field, labeled: false)),
      ],
    );
  }

  Widget _comparisonBlock(BuildContext context, PharmacyDrugImportField field) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final PharmacyDrugImportProductReview review = widget.review;

    return Padding(
      padding: EdgeInsets.all(theme.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            pharmacyDrugImportFieldLabel(l10n, field),
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: AppFontWeight.semiBold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: theme.spacing.xs / 2),
          Wrap(
            spacing: theme.spacing.md,
            runSpacing: theme.spacing.xs / 2,
            children: <Widget>[
              if (review.isLinked)
                _LabeledValue(
                  label: l10n.pharmacyDrugImportColumnCatalog,
                  value: _displayValue(l10n, field, review.catalogText(field)),
                ),
              _LabeledValue(
                label: l10n.pharmacyDrugImportColumnFile,
                value: _displayValue(l10n, field, review.fileText(field)),
              ),
            ],
          ),
          SizedBox(height: theme.spacing.sm),
          _valueEditor(context, field, labeled: true),
        ],
      ),
    );
  }

  Widget _valueText(
    BuildContext context,
    PharmacyDrugImportField field,
    String? raw,
  ) {
    return _CellText(
      _displayValue(context.l10n, field, raw),
      muted: raw == null || raw.trim().isEmpty,
    );
  }

  String _displayValue(
    AppLocalizations l10n,
    PharmacyDrugImportField field,
    String? raw,
  ) {
    final String text = raw?.trim() ?? '';
    if (text.isEmpty) {
      return l10n.pharmacyDrugImportEmptyValue;
    }
    if (!field.isPrice) {
      return text;
    }
    final num? value = parsePharmacyDrugImportPrice(text).value;
    return value == null
        ? text
        : AppFormatters.decimal(value, Localizations.localeOf(context));
  }

  Widget _valueEditor(
    BuildContext context,
    PharmacyDrugImportField field, {
    required bool labeled,
  }) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final Locale locale = Localizations.localeOf(context);
    final PharmacyDrugImportProductReview review = widget.review;

    if (!review.isEditable(field)) {
      final String value = review.valueText(field);
      final Widget text = labeled
          ? _LabeledValue(
              label: l10n.pharmacyDrugImportColumnNewValue,
              value: _displayValue(l10n, field, value),
            )
          : _valueText(context, field, value);
      if (field != PharmacyDrugImportField.name || !review.isLinked) {
        return text;
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          text,
          SizedBox(height: theme.spacing.xs / 2),
          AppStatusText(label: l10n.pharmacyDrugImportOutcomeNameKept),
        ],
      );
    }

    final PharmacyDrugImportValueProblem? problem =
        review.fieldProblem(field) ??
        (widget.duplicatesAnotherProduct &&
                (field == PharmacyDrugImportField.name ||
                    field == PharmacyDrugImportField.brandName)
            ? PharmacyDrugImportValueProblem.duplicateProduct
            : null);
    final PharmacyDrugImportFieldOutcome? outcome = review.outcome(field);
    final bool edited = review.isEdited(field);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: AppTextField(
                key: ValueKey<String>(
                  'pharmacy-drug-import-${review.product.key}-${field.apiValue}',
                ),
                controller: _fieldControllers[field],
                labelText: labeled
                    ? l10n.pharmacyDrugImportColumnNewValue
                    : null,
                semanticLabel: pharmacyDrugImportFieldLabel(l10n, field),
                isRequired: labeled && field == PharmacyDrugImportField.name,
                isDense: true,
                enabled: widget.enabled,
                enableSpeechToText: false,
                keyboardType: field.isPrice
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.text,
                errorText: problem == null
                    ? null
                    : pharmacyDrugImportValueProblemMessage(
                        l10n,
                        locale,
                        problem,
                        maxLength: field.maxLength,
                      ),
                onChanged: (String text) => _updateField(field, text),
              ),
            ),
            if (edited) ...<Widget>[
              SizedBox(width: theme.spacing.xs),
              AppButton.tertiary(
                label: l10n.pharmacyDrugImportResetFieldAction,
                tooltip: l10n.pharmacyDrugImportResetFieldAction,
                leadingIcon: Icons.undo_rounded,
                iconOnly: true,
                enabled: widget.enabled,
                onPressed: () => widget.onDraftChanged(
                  widget.review.draft.withField(field, null),
                ),
              ),
            ],
          ],
        ),
        if (outcome != null || edited)
          Padding(
            padding: EdgeInsets.only(top: theme.spacing.xs / 2),
            child: Wrap(
              spacing: theme.spacing.md,
              runSpacing: theme.spacing.xs / 2,
              children: <Widget>[
                if (edited)
                  AppStatusText(
                    label: l10n.pharmacyDrugImportEditedBadge,
                    icon: Icons.edit_outlined,
                    tone: AppWorkspaceStatusTone.info,
                  ),
                if (outcome != null)
                  AppStatusText(
                    label: pharmacyDrugImportOutcomeLabel(l10n, outcome),
                    tone: pharmacyDrugImportOutcomeTone(outcome),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  String? _stockSummary(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Locale locale = Localizations.localeOf(context);
    final PharmacyDrugImportProductReview review = widget.review;
    if (review.isSkipped) {
      return null;
    }
    String count(num value) => AppFormatters.decimal(value, locale);
    final int incoming = review.totalQuantity;
    final PharmacyDrugImportDrug? drug = review.target?.drug;
    if (drug == null) {
      return l10n.pharmacyDrugImportStockChangeNew(count(incoming));
    }
    final int next = widget.stockMode == PharmacyDrugImportStockMode.add
        ? drug.facilityQuantity + incoming
        : incoming;
    return l10n.pharmacyDrugImportStockChangeLinked(
      count(drug.facilityQuantity),
      count(next),
    );
  }

  Widget _buildBatches(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<PharmacyDrugImportBatch> batches =
        widget.review.product.batches;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool table = constraints.maxWidth >= _tableMinWidth;
        return _Framed(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (table)
                _TableRow(
                  header: true,
                  cells: <(int, Widget)>[
                    (4, _HeaderText(l10n.pharmacyDrugImportFieldBatchNumber)),
                    (5, _HeaderText(l10n.pharmacyDrugImportFieldExpiryDate)),
                    (3, _HeaderText(l10n.pharmacyDrugImportColumnQuantity)),
                    (2, _HeaderText(l10n.pharmacyDrugImportColumnRows)),
                  ],
                ),
              for (int index = 0; index < batches.length; index += 1) ...<Widget>[
                if (index > 0 || table)
                  Divider(height: 1, color: theme.borders.faint),
                _batchRow(context, batches[index], table: table),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _batchRow(
    BuildContext context,
    PharmacyDrugImportBatch batch, {
    required bool table,
  }) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final Locale locale = Localizations.localeOf(context);
    final PharmacyDrugImportProductReview review = widget.review;
    final PharmacyDrugImportBatchDraft value = review.batchValue(batch);
    final bool enabled = widget.enabled && !review.isSkipped;
    String? message(PharmacyDrugImportValueProblem? problem) => problem == null
        ? null
        : pharmacyDrugImportValueProblemMessage(
            l10n,
            locale,
            problem,
            maxLength: pharmacyDrugImportMaxBatchNumberLength,
          );

    final String fieldKey =
        'pharmacy-drug-import-${review.product.key}-batch-${batch.key}';
    final Widget number = AppTextField(
      key: ValueKey<String>('$fieldKey-number'),
      controller: _batchNumberControllers[batch.key],
      labelText: table ? null : l10n.pharmacyDrugImportFieldBatchNumber,
      semanticLabel: l10n.pharmacyDrugImportFieldBatchNumber,
      hintText: l10n.pharmacyDrugImportUnlabeledBatch,
      isDense: true,
      enabled: enabled,
      enableSpeechToText: false,
      errorText: message(review.batchNumberProblem(batch)),
      onChanged: (String text) => _updateBatch(
        batch,
        (PharmacyDrugImportBatchDraft current) =>
            current.copyWith(batchNumber: text),
      ),
    );
    final Widget expiry = AppDateField(
      labelText: table ? null : l10n.pharmacyDrugImportFieldExpiryDate,
      semanticLabel: l10n.pharmacyDrugImportFieldExpiryDate,
      value: value.expiryDate,
      pickerButtonLabel: l10n.housekeepingPickDateAction,
      invalidDateMessage: l10n.pharmacyDrugImportFieldExpiryDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      enabled: enabled,
      enableSpeechToText: false,
      onChanged: (DateTime? date) => _updateBatch(
        batch,
        (PharmacyDrugImportBatchDraft current) =>
            current.copyWith(expiryDate: () => date),
      ),
    );
    final Widget quantity = AppTextField(
      key: ValueKey<String>('$fieldKey-quantity'),
      controller: _quantityControllers[batch.key],
      labelText: table ? null : l10n.pharmacyDrugImportColumnQuantity,
      semanticLabel: l10n.pharmacyDrugImportColumnQuantity,
      isDense: true,
      enabled: enabled,
      enableSpeechToText: false,
      keyboardType: TextInputType.number,
      errorText: message(review.quantityProblem(batch)),
      onChanged: (String text) => _updateBatch(
        batch,
        (PharmacyDrugImportBatchDraft current) =>
            current.copyWith(quantity: text),
      ),
    );
    final String rows = batch.rowNumbers.join(', ');
    final Widget? reset = review.isBatchEdited(batch)
        ? AppButton.tertiary(
            label: l10n.pharmacyDrugImportResetBatchAction,
            tooltip: l10n.pharmacyDrugImportResetBatchAction,
            leadingIcon: Icons.undo_rounded,
            iconOnly: true,
            enabled: widget.enabled,
            onPressed: () => widget.onDraftChanged(
              widget.review.draft.withBatch(batch.key, null),
            ),
          )
        : null;

    if (table) {
      return _TableRow(
        cells: <(int, Widget)>[
          (4, number),
          (5, expiry),
          (3, quantity),
          (
            2,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: _CellText(
                    rows.isEmpty ? l10n.pharmacyDrugImportEmptyValue : rows,
                    muted: true,
                  ),
                ),
                ?reset,
              ],
            ),
          ),
        ],
      );
    }
    return Padding(
      padding: EdgeInsets.all(theme.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          number,
          SizedBox(height: theme.spacing.sm),
          expiry,
          SizedBox(height: theme.spacing.sm),
          quantity,
          if (rows.isNotEmpty || reset != null)
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    rows.isEmpty ? '' : l10n.pharmacyDrugImportRowsLabel(rows),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                ?reset,
              ],
            ),
        ],
      ),
    );
  }
}

class _IssueList extends StatelessWidget {
  const _IssueList({required this.issues});

  final List<PharmacyDrugImportIssue> issues;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final Locale locale = Localizations.localeOf(context);
    final Color accent = workspaceStatusToneAccentColor(
      theme,
      pharmacyDrugImportIssuesTone(issues),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(theme.radius.sm),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              l10n.pharmacyDrugImportIssuesTitle,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: AppFontWeight.semiBold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            for (final PharmacyDrugImportIssue issue in issues)
              Padding(
                padding: EdgeInsets.only(top: theme.spacing.xs),
                child: AppStatusText(
                  label: <String>[
                    if (issue.rowNumber case final int row)
                      l10n.pharmacyDrugImportRowLabel('$row'),
                    pharmacyDrugImportIssueMessage(l10n, locale, issue),
                  ].join(' · '),
                  tone: pharmacyDrugImportIssueTone(issue.severity),
                  maxLines: 4,
                  softWrap: true,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EditorSectionTitle extends StatelessWidget {
  const _EditorSectionTitle({
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
        Icon(icon, size: 20, color: colorScheme.primary),
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

class _Framed extends StatelessWidget {
  const _Framed({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final BorderRadius radius = BorderRadius.circular(theme.radius.sm);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: theme.borders.faint),
      ),
      child: ClipRRect(borderRadius: radius, child: child),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({required this.cells, this.header = false});

  /// Flex and content per column.
  final List<(int, Widget)> cells;
  final bool header;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Widget row = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.md,
        vertical: theme.spacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (int index = 0; index < cells.length; index += 1) ...<Widget>[
            if (index > 0) SizedBox(width: theme.spacing.md),
            Expanded(flex: cells[index].$1, child: cells[index].$2),
          ],
        ],
      ),
    );
    if (!header) {
      return row;
    }
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      child: row,
    );
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.labelMedium?.copyWith(
        fontWeight: AppFontWeight.semiBold,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _CellText extends StatelessWidget {
  const _CellText(this.text, {this.muted = false, this.strong = false});

  final String text;
  final bool muted;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextStyle? base = strong
        ? theme.textTheme.labelLarge?.copyWith(
            fontWeight: AppFontWeight.semiBold,
          )
        : theme.textTheme.bodyMedium;

    // Top inset lines text up with the dense fields beside it.
    return Padding(
      padding: EdgeInsets.only(top: theme.spacing.sm),
      child: Text(
        text,
        style: base?.copyWith(
          color: muted ? colorScheme.onSurfaceVariant : colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _LabeledValue extends StatelessWidget {
  const _LabeledValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text: '$label: ',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          TextSpan(
            text: value,
            style: TextStyle(color: colorScheme.onSurface),
          ),
        ],
      ),
      style: theme.textTheme.bodySmall,
    );
  }
}

class _Interactive extends StatelessWidget {
  const _Interactive({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (enabled) {
      return child;
    }
    return IgnorePointer(child: Opacity(opacity: 0.6, child: child));
  }
}

String _productFacts(
  BuildContext context,
  PharmacyDrugImportProductReview review,
) {
  final AppLocalizations l10n = context.l10n;
  final Locale locale = Localizations.localeOf(context);
  String count(num value) => AppFormatters.decimal(value, locale);
  String text(PharmacyDrugImportField field) => review.valueText(field).trim();
  num? price(PharmacyDrugImportField field) => review.canWritePricing
      ? parsePharmacyDrugImportPrice(review.valueText(field)).value
      : null;
  final String form = text(PharmacyDrugImportField.form);
  final String strength = text(PharmacyDrugImportField.strength);
  final num? retail = price(PharmacyDrugImportField.unitPrice);
  final num? cost = price(PharmacyDrugImportField.buyUnitPrice);

  return <String>[
    if (form.isNotEmpty) form,
    if (strength.isNotEmpty) strength,
    l10n.pharmacyDrugImportQuantityLabel(count(review.totalQuantity)),
    l10n.pharmacyDrugImportBatchCount(review.product.batches.length),
    if (retail != null) l10n.pharmacyDrugImportRetailPriceLabel(count(retail)),
    if (cost != null) l10n.pharmacyDrugImportCostLabel(count(cost)),
  ].join(' · ');
}

String _candidateDetails(
  AppLocalizations l10n,
  Locale locale,
  PharmacyDrugImportCandidate option,
) {
  final PharmacyDrugImportDrug drug = option.drug;
  final int? score = option.score;
  String? nonEmpty(String? value) {
    final String text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }

  return <String>[
    if (score == null)
      l10n.pharmacyDrugImportExactMatch
    else
      l10n.pharmacyDrugImportCandidateScore('$score'),
    ?nonEmpty(drug.form),
    ?nonEmpty(drug.strength),
    l10n.pharmacyDrugImportStockHere(
      AppFormatters.decimal(drug.facilityQuantity, locale),
    ),
  ].join(' · ');
}
