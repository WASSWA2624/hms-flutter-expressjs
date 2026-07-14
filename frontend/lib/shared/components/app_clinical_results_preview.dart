import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_dialog.dart';
import 'package:hosspi_hms/shared/components/app_report_actions.dart';
import 'package:hosspi_hms/shared/components/app_state_view.dart';
import 'package:hosspi_hms/shared/components/app_status_badge.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

enum AppClinicalResultsPreviewMode { inline, modal, fullScreen }

enum AppClinicalResultStatus {
  preliminary,
  verified,
  corrected,
  unavailable,
}

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

/// Shared clinical-results preview chrome. Module adapters supply [child].
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

    final Widget panel = AppReportPreviewPanel(
      title: title,
      semanticLabel: semanticLabel ?? title,
      selectable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
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
      ),
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
              tooltip: MaterialLocalizations.of(routeContext).closeButtonTooltip,
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
