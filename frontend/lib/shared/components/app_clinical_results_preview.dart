import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_dialog.dart';
import 'package:hosspi_hms/shared/components/app_report_actions.dart';
import 'package:hosspi_hms/shared/components/app_state_view.dart';
import 'package:hosspi_hms/shared/components/app_status_badge.dart';
import 'package:hosspi_hms/shared/components/app_timeline.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

enum AppClinicalResultsPreviewMode { inline, modal, fullScreen }

enum AppClinicalResultStatus { preliminary, verified, corrected, unavailable }

/// Clinical module that supplied a preview entry (presentation-only).
enum AppClinicalResultModule {
  laboratory,
  radiology,
  procedure,
  clinicalAssessment,
  other,
}

/// Abnormality flag for laboratory (and similar) result rows.
///
/// Always pair with a localized [AppClinicalResultFlagDisplay.label] — never
/// rely on color alone.
enum AppClinicalResultFlag { normal, abnormal, critical, unknown }

/// Localized label + non-color cue for clinical result release states.
@immutable
final class AppClinicalResultStatusDisplay {
  const AppClinicalResultStatusDisplay({
    required this.status,
    required this.label,
    required this.tone,
    required this.icon,
  });

  final AppClinicalResultStatus status;
  final String label;
  final AppWorkspaceStatusTone tone;
  final IconData icon;

  static AppClinicalResultStatusDisplay resolve(
    AppLocalizations l10n,
    AppClinicalResultStatus status,
  ) {
    return switch (status) {
      AppClinicalResultStatus.preliminary => AppClinicalResultStatusDisplay(
        status: status,
        label: l10n.clinicalResultsStatusPreliminaryLabel,
        tone: AppWorkspaceStatusTone.warning,
        icon: Icons.pending_outlined,
      ),
      AppClinicalResultStatus.verified => AppClinicalResultStatusDisplay(
        status: status,
        label: l10n.clinicalResultsStatusVerifiedLabel,
        tone: AppWorkspaceStatusTone.success,
        icon: Icons.verified_outlined,
      ),
      AppClinicalResultStatus.corrected => AppClinicalResultStatusDisplay(
        status: status,
        label: l10n.clinicalResultsStatusCorrectedLabel,
        tone: AppWorkspaceStatusTone.info,
        icon: Icons.edit_note_outlined,
      ),
      AppClinicalResultStatus.unavailable => AppClinicalResultStatusDisplay(
        status: status,
        label: l10n.clinicalResultsStatusUnavailableLabel,
        tone: AppWorkspaceStatusTone.neutral,
        icon: Icons.block_outlined,
      ),
    };
  }
}

@immutable
final class AppClinicalResultFlagDisplay {
  const AppClinicalResultFlagDisplay({
    required this.flag,
    required this.label,
    required this.tone,
    required this.icon,
  });

  final AppClinicalResultFlag flag;
  final String label;
  final AppWorkspaceStatusTone tone;
  final IconData icon;

  static AppClinicalResultFlagDisplay resolve(
    AppLocalizations l10n,
    AppClinicalResultFlag flag, {
    String? customLabel,
  }) {
    final String? override = customLabel?.trim();
    return switch (flag) {
      AppClinicalResultFlag.normal => AppClinicalResultFlagDisplay(
        flag: flag,
        label: (override != null && override.isNotEmpty)
            ? override
            : l10n.clinicalResultsFlagNormalLabel,
        tone: AppWorkspaceStatusTone.success,
        icon: Icons.check_circle_outline,
      ),
      AppClinicalResultFlag.abnormal => AppClinicalResultFlagDisplay(
        flag: flag,
        label: (override != null && override.isNotEmpty)
            ? override
            : l10n.clinicalResultsFlagAbnormalLabel,
        tone: AppWorkspaceStatusTone.warning,
        icon: Icons.warning_amber_outlined,
      ),
      AppClinicalResultFlag.critical => AppClinicalResultFlagDisplay(
        flag: flag,
        label: (override != null && override.isNotEmpty)
            ? override
            : l10n.clinicalResultsFlagCriticalLabel,
        tone: AppWorkspaceStatusTone.error,
        icon: Icons.priority_high,
      ),
      AppClinicalResultFlag.unknown => AppClinicalResultFlagDisplay(
        flag: flag,
        label: (override != null && override.isNotEmpty)
            ? override
            : l10n.clinicalResultsFlagUnknownLabel,
        tone: AppWorkspaceStatusTone.neutral,
        icon: Icons.help_outline,
      ),
    };
  }
}

@immutable
final class AppClinicalResultModuleDisplay {
  const AppClinicalResultModuleDisplay({
    required this.module,
    required this.label,
    required this.icon,
  });

  final AppClinicalResultModule module;
  final String label;
  final IconData icon;

  static AppClinicalResultModuleDisplay resolve(
    AppLocalizations l10n,
    AppClinicalResultModule module,
  ) {
    return switch (module) {
      AppClinicalResultModule.laboratory => AppClinicalResultModuleDisplay(
        module: module,
        label: l10n.clinicalResultsModuleLaboratoryLabel,
        icon: Icons.science_outlined,
      ),
      AppClinicalResultModule.radiology => AppClinicalResultModuleDisplay(
        module: module,
        label: l10n.clinicalResultsModuleRadiologyLabel,
        icon: Icons.biotech_outlined,
      ),
      AppClinicalResultModule.procedure => AppClinicalResultModuleDisplay(
        module: module,
        label: l10n.clinicalResultsModuleProcedureLabel,
        icon: Icons.medical_services_outlined,
      ),
      AppClinicalResultModule.clinicalAssessment =>
        AppClinicalResultModuleDisplay(
          module: module,
          label: l10n.clinicalResultsModuleAssessmentLabel,
          icon: Icons.assignment_outlined,
        ),
      AppClinicalResultModule.other => AppClinicalResultModuleDisplay(
        module: module,
        label: l10n.clinicalResultsModuleOtherLabel,
        icon: Icons.folder_outlined,
      ),
    };
  }
}

/// Print eligibility from authorization + printable released content.
///
/// Never derive from transient UI selection or unrelated filter state.
bool appClinicalResultsPrintEligible({
  required bool authorized,
  required bool hasPrintableReleasedContent,
}) {
  return authorized && hasPrintableReleasedContent;
}

/// Laboratory row fields for the shared preview adapter (presentation-only).
@immutable
final class AppClinicalLaboratoryResultContent {
  const AppClinicalLaboratoryResultContent({
    this.value,
    this.unit,
    this.referenceRange,
    this.flag = AppClinicalResultFlag.unknown,
    this.flagLabel,
  });

  final String? value;
  final String? unit;
  final String? referenceRange;
  final AppClinicalResultFlag flag;
  final String? flagLabel;
}

/// Radiology report fields for the shared preview adapter.
@immutable
final class AppClinicalRadiologyReportContent {
  const AppClinicalRadiologyReportContent({
    this.reportText,
    this.findings,
    this.impression,
    this.modality,
    this.bodyRegion,
  });

  final String? reportText;
  final String? findings;
  final String? impression;
  final String? modality;
  final String? bodyRegion;
}

/// Procedure documentation fields for the shared preview adapter.
@immutable
final class AppClinicalProcedureResultContent {
  const AppClinicalProcedureResultContent({
    this.findings,
    this.notes,
    this.performedBy,
  });

  final String? findings;
  final String? notes;
  final String? performedBy;
}

/// Clinical assessment fields for the shared preview adapter.
@immutable
final class AppClinicalAssessmentResultContent {
  const AppClinicalAssessmentResultContent({
    this.summary,
    this.impression,
    this.assessor,
  });

  final String? summary;
  final String? impression;
  final String? assessor;
}

/// Chronological, module-agnostic preview entry. Adapters map domain → this.
@immutable
final class AppClinicalResultPreviewEntry {
  const AppClinicalResultPreviewEntry({
    required this.id,
    required this.module,
    required this.title,
    required this.status,
    this.occurredAt,
    this.subtitle,
    this.body,
    this.encounterPublicId,
    this.laboratory,
    this.radiology,
    this.procedure,
    this.assessment,
    this.onOpen,
  });

  final Object id;
  final AppClinicalResultModule module;
  final String title;
  final AppClinicalResultStatus status;
  final DateTime? occurredAt;
  final String? subtitle;
  final String? body;
  final String? encounterPublicId;
  final AppClinicalLaboratoryResultContent? laboratory;
  final AppClinicalRadiologyReportContent? radiology;
  final AppClinicalProcedureResultContent? procedure;
  final AppClinicalAssessmentResultContent? assessment;
  final VoidCallback? onOpen;

  bool get hasModuleContent {
    return laboratory != null ||
        radiology != null ||
        procedure != null ||
        assessment != null ||
        (body != null && body!.trim().isNotEmpty);
  }
}

/// Chronological list of typed clinical result entries (adapter content).
///
/// Use as [AppClinicalResultsPreview.child]. Sorting is by [occurredAt]
/// descending unless [sortDescending] is false.
class AppClinicalResultsPreviewList extends StatelessWidget {
  const AppClinicalResultsPreviewList({
    required this.entries,
    this.sortDescending = true,
    this.dense = false,
    this.asTimeline = false,
    this.maxItems,
    this.emptyTitle,
    this.emptyBody,
    super.key,
  });

  final List<AppClinicalResultPreviewEntry> entries;
  final bool sortDescending;
  final bool dense;
  final bool asTimeline;
  final int? maxItems;
  final String? emptyTitle;
  final String? emptyBody;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<AppClinicalResultPreviewEntry> ordered = _orderedEntries();

    if (ordered.isEmpty) {
      return AppStateView(
        variant: AppStateViewVariant.empty,
        title: emptyTitle ?? l10n.clinicalResultsPreviewEmptyTitle,
        body: emptyBody ?? l10n.clinicalResultsPreviewEmptyBody,
      );
    }

    if (asTimeline) {
      return AppTimeline(
        sortDescending: sortDescending,
        maxItems: maxItems,
        dense: dense,
        items: <AppTimelineItem>[
          for (final AppClinicalResultPreviewEntry entry in ordered)
            AppTimelineItem(
              id: entry.id,
              title: entry.title,
              occurredAt: entry.occurredAt,
              subtitle: entry.subtitle,
              description: _timelineDescription(context, entry),
              icon: AppClinicalResultModuleDisplay.resolve(
                l10n,
                entry.module,
              ).icon,
              tone: AppClinicalResultStatusDisplay.resolve(
                l10n,
                entry.status,
              ).tone,
            ),
        ],
      );
    }

    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var index = 0; index < ordered.length; index += 1) ...<Widget>[
          AppClinicalResultEntryView(entry: ordered[index], dense: dense),
          if (index < ordered.length - 1) SizedBox(height: theme.spacing.sm),
        ],
      ],
    );
  }

  List<AppClinicalResultPreviewEntry> _orderedEntries() {
    final List<AppClinicalResultPreviewEntry> copy =
        List<AppClinicalResultPreviewEntry>.of(entries);
    copy.sort((
      AppClinicalResultPreviewEntry a,
      AppClinicalResultPreviewEntry b,
    ) {
      final DateTime left =
          a.occurredAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final DateTime right =
          b.occurredAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return sortDescending ? right.compareTo(left) : left.compareTo(right);
    });
    if (maxItems != null && copy.length > maxItems!) {
      return copy.take(maxItems!).toList(growable: false);
    }
    return copy;
  }

  static String? _timelineDescription(
    BuildContext context,
    AppClinicalResultPreviewEntry entry,
  ) {
    final AppLocalizations l10n = context.l10n;
    final AppClinicalResultStatusDisplay status =
        AppClinicalResultStatusDisplay.resolve(l10n, entry.status);
    final AppClinicalResultModuleDisplay module =
        AppClinicalResultModuleDisplay.resolve(l10n, entry.module);
    final String? body = entry.body?.trim();
    return <String>[
      module.label,
      status.label,
      if (body != null && body.isNotEmpty) body,
    ].join(' · ');
  }
}

/// Renders one typed preview entry using the matching module content adapter.
class AppClinicalResultEntryView extends StatelessWidget {
  const AppClinicalResultEntryView({
    required this.entry,
    this.dense = false,
    super.key,
  });

  final AppClinicalResultPreviewEntry entry;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final Locale locale = Localizations.localeOf(context);
    final AppClinicalResultStatusDisplay statusDisplay =
        AppClinicalResultStatusDisplay.resolve(l10n, entry.status);
    final AppClinicalResultModuleDisplay moduleDisplay =
        AppClinicalResultModuleDisplay.resolve(l10n, entry.module);
    final String? timestamp = entry.occurredAt == null
        ? null
        : AppFormatters.dateTime(entry.occurredAt!, locale);

    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Wrap(
          spacing: theme.spacing.sm,
          runSpacing: theme.spacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Icon(
              moduleDisplay.icon,
              size: theme.appTokens.listIconSize,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            Text(
              moduleDisplay.label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: AppFontWeight.emphasis,
              ),
            ),
            AppStatusBadge(
              label: statusDisplay.label,
              tone: statusDisplay.tone,
              icon: statusDisplay.icon,
            ),
            if (timestamp != null)
              Text(
                timestamp,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        SizedBox(height: theme.spacing.xs),
        Text(
          entry.title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: AppFontWeight.emphasis,
          ),
        ),
        if (entry.subtitle != null &&
            entry.subtitle!.trim().isNotEmpty) ...<Widget>[
          SizedBox(height: theme.spacing.xs),
          Text(
            entry.subtitle!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        SizedBox(height: dense ? theme.spacing.xs : theme.spacing.sm),
        _ModuleContentAdapter(entry: entry),
      ],
    );

    if (entry.onOpen == null) {
      return content;
    }

    return InkWell(
      onTap: entry.onOpen,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: theme.spacing.xs),
        child: content,
      ),
    );
  }
}

class _ModuleContentAdapter extends StatelessWidget {
  const _ModuleContentAdapter({required this.entry});

  final AppClinicalResultPreviewEntry entry;

  @override
  Widget build(BuildContext context) {
    if (entry.laboratory != null) {
      return _LaboratoryContentAdapter(content: entry.laboratory!);
    }
    if (entry.radiology != null) {
      return _RadiologyContentAdapter(content: entry.radiology!);
    }
    if (entry.procedure != null) {
      return _ProcedureContentAdapter(content: entry.procedure!);
    }
    if (entry.assessment != null) {
      return _AssessmentContentAdapter(content: entry.assessment!);
    }
    final String? body = entry.body?.trim();
    if (body == null || body.isEmpty) {
      return const SizedBox.shrink();
    }
    return Text(body, style: Theme.of(context).textTheme.bodyMedium);
  }
}

class _LaboratoryContentAdapter extends StatelessWidget {
  const _LaboratoryContentAdapter({required this.content});

  final AppClinicalLaboratoryResultContent content;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final AppClinicalResultFlagDisplay flagDisplay =
        AppClinicalResultFlagDisplay.resolve(
          l10n,
          content.flag,
          customLabel: content.flagLabel,
        );
    final String valueLabel = <String?>[
      content.value?.trim(),
      content.unit?.trim(),
    ].whereType<String>().where((String part) => part.isNotEmpty).join(' ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (valueLabel.isNotEmpty)
          Text(
            valueLabel,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: AppFontWeight.emphasis,
            ),
          ),
        if (content.referenceRange != null &&
            content.referenceRange!.trim().isNotEmpty) ...<Widget>[
          SizedBox(height: theme.spacing.xs),
          Text(
            l10n.clinicalResultsReferenceRangeLabel(content.referenceRange!),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        SizedBox(height: theme.spacing.xs),
        AppStatusBadge(
          label: flagDisplay.label,
          tone: flagDisplay.tone,
          icon: flagDisplay.icon,
        ),
      ],
    );
  }
}

class _RadiologyContentAdapter extends StatelessWidget {
  const _RadiologyContentAdapter({required this.content});

  final AppClinicalRadiologyReportContent content;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final String meta = <String?>[
      content.modality?.trim(),
      content.bodyRegion?.trim(),
    ].whereType<String>().where((String part) => part.isNotEmpty).join(' · ');
    final String narrative = content.reportText?.trim().isNotEmpty == true
        ? content.reportText!.trim()
        : <String?>[content.findings?.trim(), content.impression?.trim()]
              .whereType<String>()
              .where((String part) => part.isNotEmpty)
              .join('\n\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (meta.isNotEmpty)
          Text(
            meta,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: AppFontWeight.emphasis,
            ),
          ),
        if (narrative.isNotEmpty) ...<Widget>[
          if (meta.isNotEmpty) SizedBox(height: theme.spacing.xs),
          Text(narrative, style: theme.textTheme.bodyMedium),
        ] else
          Text(
            l10n.clinicalResultsPreviewEmptyBody,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _ProcedureContentAdapter extends StatelessWidget {
  const _ProcedureContentAdapter({required this.content});

  final AppClinicalProcedureResultContent content;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (content.findings != null && content.findings!.trim().isNotEmpty)
          Text(content.findings!, style: theme.textTheme.bodyMedium),
        if (content.notes != null &&
            content.notes!.trim().isNotEmpty) ...<Widget>[
          SizedBox(height: theme.spacing.xs),
          Text(
            content.notes!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (content.performedBy != null &&
            content.performedBy!.trim().isNotEmpty) ...<Widget>[
          SizedBox(height: theme.spacing.xs),
          Text(
            l10n.clinicalResultsPerformedByLabel(content.performedBy!),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _AssessmentContentAdapter extends StatelessWidget {
  const _AssessmentContentAdapter({required this.content});

  final AppClinicalAssessmentResultContent content;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (content.summary != null && content.summary!.trim().isNotEmpty)
          Text(content.summary!, style: theme.textTheme.bodyMedium),
        if (content.impression != null &&
            content.impression!.trim().isNotEmpty) ...<Widget>[
          SizedBox(height: theme.spacing.xs),
          Text(
            content.impression!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (content.assessor != null &&
            content.assessor!.trim().isNotEmpty) ...<Widget>[
          SizedBox(height: theme.spacing.xs),
          Text(
            l10n.clinicalResultsAssessorLabel(content.assessor!),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// Shared clinical-results preview chrome. Module adapters supply [child]
/// (typically [AppClinicalResultsPreviewList]) or typed entry content.
class AppClinicalResultsPreview extends StatelessWidget {
  const AppClinicalResultsPreview({
    required this.child,
    this.title,
    this.status,
    this.mode = AppClinicalResultsPreviewMode.inline,
    this.isLoading = false,
    this.isEmpty = false,
    this.isForbidden = false,
    this.failure,
    this.onRetry,
    this.printEligible = false,
    this.onPrint,
    this.actions = const <Widget>[],
    this.loadingTitle,
    this.loadingBody,
    this.emptyTitle,
    this.emptyBody,
    this.forbiddenTitle,
    this.forbiddenBody,
    this.semanticLabel,
    this.encounterPublicId,
    super.key,
  });

  final Widget child;
  final String? title;
  final AppClinicalResultStatus? status;
  final AppClinicalResultsPreviewMode mode;
  final bool isLoading;
  final bool isEmpty;
  final bool isForbidden;
  final AppFailure? failure;
  final VoidCallback? onRetry;

  /// Backend-authorized print eligibility. Do not bind to transient selection.
  final bool printEligible;
  final VoidCallback? onPrint;
  final List<Widget> actions;
  final String? loadingTitle;
  final String? loadingBody;
  final String? emptyTitle;
  final String? emptyBody;
  final String? forbiddenTitle;
  final String? forbiddenBody;
  final String? semanticLabel;

  /// Optional public encounter ID shown for encounter-scope clarity.
  final String? encounterPublicId;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final AppClinicalResultStatusDisplay? statusDisplay = status == null
        ? null
        : AppClinicalResultStatusDisplay.resolve(l10n, status!);

    final Widget body;
    if (isLoading) {
      body = AppStateView(
        variant: AppStateViewVariant.loading,
        title: loadingTitle ?? l10n.clinicalResultsPreviewLoadingTitle,
        body: loadingBody ?? l10n.clinicalResultsPreviewLoadingBody,
      );
    } else if (isForbidden) {
      body = AppStateView(
        variant: AppStateViewVariant.forbidden,
        title: forbiddenTitle ?? l10n.clinicalResultsPreviewForbiddenTitle,
        body: forbiddenBody ?? l10n.clinicalResultsPreviewForbiddenBody,
      );
    } else if (failure != null) {
      body = AppFailureStateView(
        failure: failure!,
        title: l10n.clinicalResultsPreviewErrorTitle,
        body: l10n.clinicalResultsPreviewErrorBody,
        onRetry: onRetry,
      );
    } else if (isEmpty) {
      body = AppStateView(
        variant: AppStateViewVariant.empty,
        title: emptyTitle ?? l10n.clinicalResultsPreviewEmptyTitle,
        body: emptyBody ?? l10n.clinicalResultsPreviewEmptyBody,
        action: onRetry == null
            ? null
            : AppButton.secondary(
                label: l10n.commonRetryActionLabel,
                leadingIcon: Icons.refresh,
                onPressed: onRetry,
              ),
      );
    } else {
      body = child;
    }

    final List<Widget> headerActions = <Widget>[
      ...actions,
      if (printEligible && onPrint != null)
        AppReportActionButton.print(
          label: l10n.clinicalResultsPreviewPrintAction,
          onPressed: onPrint,
        ),
    ];

    final String? encounterId = encounterPublicId?.trim();

    final Widget previewBody = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (encounterId != null && encounterId.isNotEmpty) ...<Widget>[
          Text(
            l10n.clinicalResultsEncounterScopeLabel(encounterId),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: theme.spacing.sm),
        ],
        if (statusDisplay != null || headerActions.isNotEmpty) ...<Widget>[
          Wrap(
            spacing: theme.spacing.sm,
            runSpacing: theme.spacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: <Widget>[
              if (statusDisplay != null)
                AppStatusBadge(
                  label: statusDisplay.label,
                  tone: statusDisplay.tone,
                  icon: statusDisplay.icon,
                ),
              if (headerActions.isNotEmpty)
                Wrap(
                  spacing: theme.spacing.xs,
                  runSpacing: theme.spacing.xs,
                  children: headerActions,
                ),
            ],
          ),
          SizedBox(height: theme.spacing.md),
        ],
        body,
      ],
    );

    // Modal hosts (e.g. AppDialog) already provide titled chrome — avoid a
    // nested AppReportPreviewPanel / collapsible section when [title] is unset.
    final Widget panel = title == null || title!.trim().isEmpty
        ? Semantics(
            container: true,
            label: semanticLabel,
            child: SelectionArea(child: previewBody),
          )
        : AppReportPreviewPanel(
            title: title,
            semanticLabel: semanticLabel ?? title,
            selectable: true,
            child: previewBody,
          );

    return switch (mode) {
      AppClinicalResultsPreviewMode.inline => panel,
      AppClinicalResultsPreviewMode.modal => panel,
      AppClinicalResultsPreviewMode.fullScreen => SizedBox.expand(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(theme.spacing.md),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: panel,
              ),
            ),
          ),
        ),
      ),
    };
  }
}

Future<T?> showAppClinicalResultsPreviewDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
  bool barrierDismissible = true,
  double maxWidth = 960,
}) {
  return showAppDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (BuildContext dialogContext) {
      return AppDialog(
        title: title == null ? null : Text(title),
        content: builder(dialogContext),
        scrollable: true,
        maxWidth: maxWidth,
      );
    },
  );
}

Future<T?> showAppClinicalResultsPreviewFullScreen<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
}) {
  return Navigator.of(context, rootNavigator: true).push<T>(
    MaterialPageRoute<T>(
      fullscreenDialog: true,
      builder: (BuildContext routeContext) {
        final ThemeData theme = Theme.of(routeContext);
        return Scaffold(
          appBar: AppBar(
            title: title == null ? null : Text(title),
            leading: IconButton(
              icon: const Icon(Icons.close),
              tooltip: MaterialLocalizations.of(
                routeContext,
              ).closeButtonTooltip,
              onPressed: () => Navigator.of(routeContext).maybePop(),
            ),
          ),
          body: ColoredBox(
            color: theme.colorScheme.surface,
            child: builder(routeContext),
          ),
        );
      },
    ),
  );
}
