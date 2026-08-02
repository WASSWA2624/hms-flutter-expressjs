import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_content_panel.dart';
import 'package:hosspi_hms/shared/components/app_dialog.dart';
import 'package:hosspi_hms/shared/components/app_form_information_banner.dart';
import 'package:hosspi_hms/shared/components/app_text_field.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

/// One compared field on a similarity match card.
@immutable
final class AppSimilarityFieldRow {
  const AppSimilarityFieldRow({
    required this.key,
    required this.label,
    this.proposedValue,
    this.existingValue,
    this.score,
  });

  final String key;
  final String label;
  final String? proposedValue;
  final String? existingValue;
  final int? score;

  bool get isExact => score == 100;
}

/// Editable proposed field shown in the review dialog.
@immutable
final class AppSimilarityProposedField {
  const AppSimilarityProposedField({
    required this.key,
    required this.label,
    this.initialValue = '',
    this.isRequired = false,
    this.editable = true,
  });

  final String key;
  final String label;
  final String initialValue;
  final bool isRequired;

  /// When false, the field stays read-only even if the dialog is editable.
  final bool editable;
}

/// One existing candidate in a similarity review.
@immutable
final class AppSimilarityMatch<T> {
  const AppSimilarityMatch({
    required this.item,
    required this.title,
    required this.overallScore,
    required this.fields,
    this.subtitle,
    this.isExact = false,
  });

  final T item;
  final String title;
  final String? subtitle;
  final int overallScore;
  final bool isExact;
  final List<AppSimilarityFieldRow> fields;
}

enum AppSimilarityReviewAction { cancel, proceed, useExisting, retry }

/// Result of [showAppSimilarityReviewDialog].
@immutable
final class AppSimilarityReviewResult<T> {
  const AppSimilarityReviewResult._({
    required this.action,
    this.selected,
    this.proposedValues = const <String, String>{},
  });

  const AppSimilarityReviewResult.cancel()
    : this._(action: AppSimilarityReviewAction.cancel);

  const AppSimilarityReviewResult.proceed({
    Map<String, String> proposedValues = const <String, String>{},
  }) : this._(
         action: AppSimilarityReviewAction.proceed,
         proposedValues: proposedValues,
       );

  const AppSimilarityReviewResult.useExisting(
    T item, {
    Map<String, String> proposedValues = const <String, String>{},
  }) : this._(
         action: AppSimilarityReviewAction.useExisting,
         selected: item,
         proposedValues: proposedValues,
       );

  const AppSimilarityReviewResult.retry({
    required Map<String, String> proposedValues,
  }) : this._(
         action: AppSimilarityReviewAction.retry,
         proposedValues: proposedValues,
       );

  final AppSimilarityReviewAction action;
  final T? selected;
  final Map<String, String> proposedValues;
}

/// Domain-agnostic match card: proposed vs existing fields, scores, Use this.
class AppSimilarityMatchCard<T> extends StatelessWidget {
  const AppSimilarityMatchCard({
    required this.match,
    required this.onUseThis,
    this.existingHeading,
    this.useThisLabel,
    this.useThisIcon,
    this.exactBadgeLabel,
    this.nearBadgeLabel,
    this.fieldColumnLabel,
    this.proposedColumnLabel,
    this.existingColumnLabel,
    this.emptyValueLabel = '—',
    this.initiallyExpanded = true,
    super.key,
  });

  final AppSimilarityMatch<T> match;
  final VoidCallback onUseThis;
  final String? existingHeading;
  final String? useThisLabel;
  final IconData? useThisIcon;
  final String? exactBadgeLabel;
  final String? nearBadgeLabel;
  final String? fieldColumnLabel;
  final String? proposedColumnLabel;
  final String? existingColumnLabel;
  final String emptyValueLabel;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final AppStatusColors statusColors = theme.statusColors;
    final bool exact = match.isExact;
    final Color accent = exact ? statusColors.error : statusColors.warning;
    final Color container = exact
        ? statusColors.errorContainer
        : statusColors.warningContainer;
    final Color onContainer = exact
        ? statusColors.onErrorContainer
        : statusColors.onWarningContainer;
    final String badgeLabel = exact
        ? (exactBadgeLabel ?? l10n.appSimilarityExactMatchLabel)
        : (nearBadgeLabel ?? l10n.appSimilarityNearMatchLabel);

    return AppCollapsibleSection(
      initiallyExpanded: initiallyExpanded,
      backgroundColor: container,
      borderColor: accent.withValues(alpha: 0.55),
      accentColor: accent,
      titleColor: onContainer,
      titleIcon: exact ? Icons.gpp_bad_outlined : Icons.warehouse_outlined,
      eyebrow: existingHeading ?? l10n.appSimilarityExistingHeading,
      title: match.title,
      subtitle: (match.subtitle ?? '').trim().isEmpty ? null : match.subtitle,
      contentPadding: EdgeInsets.all(theme.spacing.md),
      headerActions: <Widget>[
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.sm,
            vertical: theme.spacing.xs / 2,
          ),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.14),
            border: Border.all(color: accent.withValues(alpha: 0.45)),
          ),
          child: Text(
            badgeLabel,
            style: theme.textTheme.labelMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          '${match.overallScore}%',
          style: theme.textTheme.labelLarge?.copyWith(
            color: accent,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _AppSimilarityFieldTable(
            fields: match.fields,
            fieldColumnLabel:
                fieldColumnLabel ?? l10n.appSimilarityFieldColumnLabel,
            proposedColumnLabel:
                proposedColumnLabel ?? l10n.appSimilarityProposedColumnLabel,
            existingColumnLabel:
                existingColumnLabel ?? l10n.appSimilarityExistingColumnLabel,
            emptyValueLabel: emptyValueLabel,
          ),
          SizedBox(height: theme.spacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton.secondary(
              label: useThisLabel ?? l10n.appSimilarityUseThisAction,
              leadingIcon: useThisIcon ?? Icons.check,
              onPressed: onUseThis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared similarity review dialog: banner, proposed values, matches.
///
/// Set [enableRetry] false when the caller cannot re-check after edits.
/// Set [proposedReadOnly] true to show proposed values without text fields.
Future<AppSimilarityReviewResult<T>> showAppSimilarityReviewDialog<T>(
  BuildContext context, {
  required String title,
  required String bannerTitle,
  required String bannerMessage,
  required AppFormInformationVariant bannerVariant,
  required List<AppSimilarityProposedField> proposedFields,
  required List<AppSimilarityMatch<T>> matches,
  required int overallScore,
  bool blockProceed = false,
  bool enableRetry = true,
  bool proposedReadOnly = false,
  String? proceedLabel,
  String? continueLabel,
  String? useThisLabel,
  String? proposedHeading,
  String? matchesHeading,
  String? exactBadgeLabel,
  String? nearBadgeLabel,
  String? retryLabel,
  String? closestMatchLabel,
  String? noMatchLabel,
  String? existingHeading,
  String? fieldColumnLabel,
  String? proposedColumnLabel,
  String? existingColumnLabel,
  String? emptyValueLabel,
  IconData? dialogIcon,
  IconData? useThisIcon,
}) {
  return showAppDialog<AppSimilarityReviewResult<T>>(
    context: context,
    builder: (BuildContext dialogContext) => _AppSimilarityReviewDialog<T>(
      title: title,
      bannerTitle: bannerTitle,
      bannerMessage: bannerMessage,
      bannerVariant: bannerVariant,
      proposedFields: proposedFields,
      matches: matches,
      overallScore: overallScore,
      blockProceed: blockProceed,
      enableRetry: enableRetry,
      proposedReadOnly: proposedReadOnly,
      proceedLabel: proceedLabel,
      continueLabel: continueLabel,
      useThisLabel: useThisLabel,
      proposedHeading: proposedHeading,
      matchesHeading: matchesHeading,
      exactBadgeLabel: exactBadgeLabel,
      nearBadgeLabel: nearBadgeLabel,
      retryLabel: retryLabel,
      closestMatchLabel: closestMatchLabel,
      noMatchLabel: noMatchLabel,
      existingHeading: existingHeading,
      fieldColumnLabel: fieldColumnLabel,
      proposedColumnLabel: proposedColumnLabel,
      existingColumnLabel: existingColumnLabel,
      emptyValueLabel: emptyValueLabel,
      dialogIcon: dialogIcon,
      useThisIcon: useThisIcon,
    ),
  ).then(
    (AppSimilarityReviewResult<T>? value) =>
        value ?? AppSimilarityReviewResult<T>.cancel(),
  );
}

class _AppSimilarityReviewDialog<T> extends StatefulWidget {
  const _AppSimilarityReviewDialog({
    required this.title,
    required this.bannerTitle,
    required this.bannerMessage,
    required this.bannerVariant,
    required this.proposedFields,
    required this.matches,
    required this.overallScore,
    required this.blockProceed,
    this.enableRetry = true,
    this.proposedReadOnly = false,
    this.proceedLabel,
    this.continueLabel,
    this.useThisLabel,
    this.proposedHeading,
    this.matchesHeading,
    this.exactBadgeLabel,
    this.nearBadgeLabel,
    this.retryLabel,
    this.closestMatchLabel,
    this.noMatchLabel,
    this.existingHeading,
    this.fieldColumnLabel,
    this.proposedColumnLabel,
    this.existingColumnLabel,
    this.emptyValueLabel,
    this.dialogIcon,
    this.useThisIcon,
  });

  final String title;
  final String bannerTitle;
  final String bannerMessage;
  final AppFormInformationVariant bannerVariant;
  final List<AppSimilarityProposedField> proposedFields;
  final List<AppSimilarityMatch<T>> matches;
  final int overallScore;
  final bool blockProceed;
  final bool enableRetry;
  final bool proposedReadOnly;
  final String? proceedLabel;
  final String? continueLabel;
  final String? useThisLabel;
  final String? proposedHeading;
  final String? matchesHeading;
  final String? exactBadgeLabel;
  final String? nearBadgeLabel;
  final String? retryLabel;
  final String? closestMatchLabel;
  final String? noMatchLabel;
  final String? existingHeading;
  final String? fieldColumnLabel;
  final String? proposedColumnLabel;
  final String? existingColumnLabel;
  final String? emptyValueLabel;
  final IconData? dialogIcon;
  final IconData? useThisIcon;

  @override
  State<_AppSimilarityReviewDialog<T>> createState() =>
      _AppSimilarityReviewDialogState<T>();
}

class _AppSimilarityReviewDialogState<T>
    extends State<_AppSimilarityReviewDialog<T>> {
  late final Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = <String, TextEditingController>{
      for (final AppSimilarityProposedField field in widget.proposedFields)
        field.key: TextEditingController(text: field.initialValue),
    };
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Map<String, String> _readProposedValues() {
    return <String, String>{
      for (final MapEntry<String, TextEditingController> entry
          in _controllers.entries)
        entry.key: entry.value.text.trim(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final bool hasMatches = widget.matches.isNotEmpty;
    final bool canProceed = !widget.blockProceed;
    final bool isExact = widget.blockProceed;
    final IconData resolvedIcon =
        widget.dialogIcon ??
        (isExact
            ? Icons.gpp_bad_outlined
            : hasMatches
            ? Icons.warning_amber_outlined
            : Icons.verified_outlined);
    final String resolvedProceedLabel = hasMatches
        ? (widget.proceedLabel ?? l10n.appSimilaritySaveAnywayAction)
        : (widget.continueLabel ?? l10n.commonContinueActionLabel);
    final String emptyLabel =
        widget.emptyValueLabel ?? l10n.clinicalOrderEmptyValueLabel;
    final AppStatusColors statusColors = theme.statusColors;
    final Color proposedAccent = isExact
        ? statusColors.error
        : hasMatches
        ? statusColors.warning
        : statusColors.success;
    final Color proposedContainer = isExact
        ? statusColors.errorContainer
        : hasMatches
        ? statusColors.warningContainer
        : statusColors.successContainer;
    final Color proposedOnContainer = isExact
        ? statusColors.onErrorContainer
        : hasMatches
        ? statusColors.onWarningContainer
        : statusColors.onSuccessContainer;
    final String closestMatchText =
        '${widget.closestMatchLabel ?? l10n.appSimilarityClosestMatchLabel}: ${widget.overallScore}%';

    return AppDialog(
      title: Text(widget.title),
      icon: Icon(resolvedIcon),
      scrollable: true,
      maxWidth: 820,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppFormInformationBanner(
            title: widget.bannerTitle,
            message: widget.bannerMessage,
            variant: widget.bannerVariant,
            icon: resolvedIcon,
            borderRadius: BorderRadius.zero,
          ),
          SizedBox(height: theme.spacing.md),
          AppCollapsibleSection(
            initiallyExpanded: false,
            backgroundColor: proposedContainer,
            borderColor: proposedAccent.withValues(alpha: 0.55),
            accentColor: proposedAccent,
            titleColor: proposedOnContainer,
            titleIcon: widget.proposedReadOnly
                ? Icons.list_alt_outlined
                : Icons.edit_note_outlined,
            title: widget.proposedHeading ?? l10n.appSimilarityProposedHeading,
            contentPadding: EdgeInsets.all(theme.spacing.md),
            headerActions: <Widget>[
              Text(
                closestMatchText,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: proposedAccent,
                ),
              ),
              if (widget.enableRetry)
                AppButton.tertiary(
                  dense: true,
                  label: widget.retryLabel ?? l10n.appSimilarityRetryAction,
                  leadingIcon: Icons.refresh,
                  onPressed: () => Navigator.of(context).pop(
                    AppSimilarityReviewResult<T>.retry(
                      proposedValues: _readProposedValues(),
                    ),
                  ),
                ),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (
                  int index = 0;
                  index < widget.proposedFields.length;
                  index += 1
                ) ...<Widget>[
                  if (index > 0) SizedBox(height: theme.spacing.sm),
                  if (widget.proposedReadOnly ||
                      !widget.proposedFields[index].editable)
                    _AppSimilarityReadOnlyField(
                      label: widget.proposedFields[index].label,
                      value: widget.proposedFields[index].initialValue,
                      emptyValueLabel: emptyLabel,
                      isRequired: widget.proposedFields[index].isRequired,
                    )
                  else
                    AppTextField(
                      controller:
                          _controllers[widget.proposedFields[index].key]!,
                      labelText: widget.proposedFields[index].label,
                      isRequired: widget.proposedFields[index].isRequired,
                      enableSpeechToText: false,
                    ),
                ],
              ],
            ),
          ),
          SizedBox(height: theme.spacing.lg),
          if (hasMatches) ...<Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    widget.matchesHeading ?? l10n.appSimilarityMatchesHeading,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.start,
                  ),
                ),
                Text(
                  l10n.appSimilarityMatchCountLabel(widget.matches.length),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            SizedBox(height: theme.spacing.sm),
            for (int index = 0; index < widget.matches.length; index += 1) ...<
              Widget
            >[
              if (index > 0) SizedBox(height: theme.spacing.md),
              AppSimilarityMatchCard<T>(
                match: widget.matches[index],
                existingHeading: widget.existingHeading,
                useThisLabel: widget.useThisLabel,
                useThisIcon: widget.useThisIcon,
                exactBadgeLabel: widget.exactBadgeLabel,
                nearBadgeLabel: widget.nearBadgeLabel,
                fieldColumnLabel: widget.fieldColumnLabel,
                proposedColumnLabel: widget.proposedColumnLabel,
                existingColumnLabel: widget.existingColumnLabel,
                emptyValueLabel: emptyLabel,
                initiallyExpanded: index == 0,
                onUseThis: () => Navigator.of(context).pop(
                  AppSimilarityReviewResult<T>.useExisting(
                    widget.matches[index].item,
                    proposedValues: _readProposedValues(),
                  ),
                ),
              ),
            ],
          ] else
            _AppSimilarityNoMatchPanel(
              score: widget.overallScore,
              label:
                  widget.noMatchLabel ??
                  l10n.appSimilarityNoMatchScoreLabel(widget.overallScore),
            ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          leadingIcon: Icons.close,
          onPressed: () => Navigator.of(
            context,
          ).pop(AppSimilarityReviewResult<T>.cancel()),
        ),
        if (canProceed)
          AppButton.primary(
            label: resolvedProceedLabel,
            leadingIcon: hasMatches
                ? Icons.add_home_work_outlined
                : Icons.check_circle_outline,
            onPressed: () => Navigator.of(context).pop(
              AppSimilarityReviewResult<T>.proceed(
                proposedValues: _readProposedValues(),
              ),
            ),
          ),
      ],
    );
  }
}

class _AppSimilarityReadOnlyField extends StatelessWidget {
  const _AppSimilarityReadOnlyField({
    required this.label,
    required this.value,
    required this.emptyValueLabel,
    this.isRequired = false,
  });

  final String label;
  final String value;
  final String emptyValueLabel;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String trimmed = value.trim();
    final String display = trimmed.isEmpty ? emptyValueLabel : trimmed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text.rich(
          TextSpan(
            children: <InlineSpan>[
              TextSpan(
                text: label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (isRequired)
                TextSpan(
                  text: ' *',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.statusColors.error,
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: theme.spacing.xs / 2),
        Text(
          display,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: trimmed.isEmpty
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.onSurface,
          ),
          textAlign: TextAlign.start,
        ),
      ],
    );
  }
}

class _AppSimilarityNoMatchPanel extends StatelessWidget {
  const _AppSimilarityNoMatchPanel({required this.score, required this.label});

  final int score;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppStatusColors statusColors = theme.statusColors;

    return AppContentPanel(
      tone: AppWorkspaceStatusTone.success,
      density: AppContentPanelDensity.compact,
      child: Row(
        children: <Widget>[
          Icon(
            Icons.verified_outlined,
            color: statusColors.success,
            size: theme.appTokens.listIconSize,
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.start,
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacing.sm,
              vertical: theme.spacing.xs,
            ),
            decoration: BoxDecoration(
              color: statusColors.successContainer,
              borderRadius: BorderRadius.circular(theme.radius.md),
            ),
            child: Text(
              '$score%',
              style: theme.textTheme.labelLarge?.copyWith(
                color: statusColors.onSuccessContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppSimilarityFieldTable extends StatelessWidget {
  const _AppSimilarityFieldTable({
    required this.fields,
    required this.fieldColumnLabel,
    required this.proposedColumnLabel,
    required this.existingColumnLabel,
    required this.emptyValueLabel,
  });

  final List<AppSimilarityFieldRow> fields;
  final String fieldColumnLabel;
  final String proposedColumnLabel;
  final String existingColumnLabel;
  final String emptyValueLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppStatusColors statusColors = theme.statusColors;
    if (fields.isEmpty) {
      return const SizedBox.shrink();
    }

    final TextStyle headerStyle = theme.textTheme.labelSmall!.copyWith(
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              flex: 2,
              child: Text(
                fieldColumnLabel,
                style: headerStyle,
                textAlign: TextAlign.start,
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                proposedColumnLabel,
                style: headerStyle,
                textAlign: TextAlign.start,
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                existingColumnLabel,
                style: headerStyle,
                textAlign: TextAlign.start,
              ),
            ),
            SizedBox(
              width: 56,
              child: Text('%', style: headerStyle, textAlign: TextAlign.end),
            ),
          ],
        ),
        SizedBox(height: theme.spacing.xs),
        for (final AppSimilarityFieldRow row in fields)
          Padding(
            padding: EdgeInsets.symmetric(vertical: theme.spacing.xs / 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  flex: 2,
                  child: Text(
                    row.label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.start,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    _display(row.proposedValue),
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.start,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    _display(row.existingValue),
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.start,
                  ),
                ),
                SizedBox(
                  width: 56,
                  child: Text(
                    row.score == null ? emptyValueLabel : '${row.score}%',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: row.isExact
                          ? statusColors.error
                          : (row.score ?? 0) >= 70
                          ? statusColors.warning
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _display(String? value) {
    final String trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? emptyValueLabel : trimmed;
  }
}
