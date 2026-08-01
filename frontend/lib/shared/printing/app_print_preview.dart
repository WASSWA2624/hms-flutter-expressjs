import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/printing/app_print_html_preview.dart';

/// Which panes are visible in a print workspace.
enum AppPrintPreviewPaneMode {
  /// Section picker and preview side by side.
  split,

  /// Section picker only.
  sections,

  /// Print preview only.
  preview,
}

/// Shared HTML print-preview surface with a print-style toolbar.
class AppPrintPreviewPanel extends StatelessWidget {
  const AppPrintPreviewPanel({
    required this.html,
    required this.fallbackChild,
    this.title,
    this.height = 420,
    this.scale = 1,
    this.maximized = false,
    this.onMaximizeToggle,
    this.onZoomIn,
    this.onZoomOut,
    this.onZoomIncrease,
    this.onZoomDecrease,
    this.onFitPage,
    this.maximizeEnabled = true,
    this.toolbarEnabled = true,
    this.headerActions = const <Widget>[],
    this.viewTypePrefix = 'app-print-html-preview',
    super.key,
  });

  final String html;
  final Widget fallbackChild;
  final String? title;
  final double height;
  final double scale;
  final bool maximized;
  final VoidCallback? onMaximizeToggle;
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;
  final VoidCallback? onZoomIncrease;
  final VoidCallback? onZoomDecrease;
  final VoidCallback? onFitPage;
  final bool maximizeEnabled;
  final bool toolbarEnabled;
  final List<Widget> headerActions;
  final String viewTypePrefix;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String maximizeLabel = maximized
        ? l10n.printPreviewRestoreAction
        : l10n.printPreviewMaximizeAction;

    return AppReportPreviewPanel(
      title: title ?? l10n.printPreviewTitle,
      collapsible: false,
      maxBodyHeight: height,
      scrollBody: false,
      contentPadding: EdgeInsets.all(theme.spacing.sm),
      headerActions: <Widget>[
        if (onMaximizeToggle != null)
          AppButton(
            iconOnly: true,
            leadingIcon: maximized
                ? Icons.fullscreen_exit
                : Icons.fullscreen,
            label: maximizeLabel,
            semanticLabel: maximizeLabel,
            tooltip: maximizeLabel,
            onPressed: maximizeEnabled ? onMaximizeToggle : null,
          ),
        ...headerActions,
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (toolbarEnabled) ...<Widget>[
            AppPrintPreviewToolbar(
              scale: scale,
              maximized: maximized,
              enabled: maximizeEnabled,
              showMaximize: false,
              onZoomIn: onZoomIn,
              onZoomOut: onZoomOut,
              onZoomIncrease: onZoomIncrease,
              onZoomDecrease: onZoomDecrease,
              onFitPage: onFitPage,
            ),
            SizedBox(height: theme.spacing.sm),
          ],
          Expanded(
            child: AppPrintHtmlPreview(
              html: html,
              scale: scale,
              fallbackChild: fallbackChild,
              viewTypePrefix: viewTypePrefix,
            ),
          ),
        ],
      ),
    );
  }
}

/// Zoom / fit / maximize controls for print previews.
class AppPrintPreviewToolbar extends StatelessWidget {
  const AppPrintPreviewToolbar({
    required this.scale,
    this.maximized = false,
    this.enabled = true,
    this.showMaximize = true,
    this.onZoomOut,
    this.onZoomIn,
    this.onZoomDecrease,
    this.onZoomIncrease,
    this.onFitPage,
    this.onMaximizeToggle,
    super.key,
  });

  final double scale;
  final bool maximized;
  final bool enabled;
  final bool showMaximize;
  final VoidCallback? onZoomOut;
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomDecrease;
  final VoidCallback? onZoomIncrease;
  final VoidCallback? onFitPage;
  final VoidCallback? onMaximizeToggle;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String maximizeLabel = maximized
        ? l10n.printPreviewRestoreAction
        : l10n.printPreviewMaximizeAction;
    final String zoomLabel = l10n.printPreviewZoomPercentLabel(
      (scale * 100).round(),
    );

    Widget tool({
      required IconData icon,
      required String label,
      required VoidCallback? onPressed,
    }) {
      return AppButton(
        iconOnly: true,
        leadingIcon: icon,
        label: label,
        semanticLabel: label,
        tooltip: label,
        onPressed: enabled ? onPressed : null,
      );
    }

    return Wrap(
      spacing: theme.spacing.xs,
      runSpacing: theme.spacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        tool(
          icon: Icons.zoom_out,
          label: l10n.printPreviewZoomOutAction,
          onPressed: onZoomOut,
        ),
        tool(
          icon: Icons.remove,
          label: l10n.printPreviewDecreaseAction,
          onPressed: onZoomDecrease ?? onZoomOut,
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: theme.spacing.xs),
          child: Text(
            zoomLabel,
            style: theme.textTheme.labelMedium?.copyWith(
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ),
        tool(
          icon: Icons.add,
          label: l10n.printPreviewIncreaseAction,
          onPressed: onZoomIncrease ?? onZoomIn,
        ),
        tool(
          icon: Icons.zoom_in,
          label: l10n.printPreviewZoomInAction,
          onPressed: onZoomIn,
        ),
        tool(
          icon: Icons.fit_screen_outlined,
          label: l10n.printPreviewFitPageAction,
          onPressed: onFitPage,
        ),
        if (showMaximize && onMaximizeToggle != null)
          tool(
            icon: maximized ? Icons.fullscreen_exit : Icons.fullscreen,
            label: maximizeLabel,
            onPressed: onMaximizeToggle,
          ),
      ],
    );
  }
}

/// Toggle between split / sections-only / preview-only layouts.
class AppPrintPreviewPaneModeBar extends StatelessWidget {
  const AppPrintPreviewPaneModeBar({
    required this.mode,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final AppPrintPreviewPaneMode mode;
  final ValueChanged<AppPrintPreviewPaneMode> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    Widget modeButton({
      required AppPrintPreviewPaneMode value,
      required IconData icon,
      required String label,
    }) {
      final bool selected = mode == value;
      return AppButton(
        iconOnly: true,
        leadingIcon: icon,
        label: label,
        semanticLabel: label,
        tooltip: label,
        variant: selected
            ? AppButtonVariant.secondary
            : AppButtonVariant.tertiary,
        onPressed: !enabled
            ? null
            : () {
                if (!selected) {
                  onChanged(value);
                }
              },
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            modeButton(
              value: AppPrintPreviewPaneMode.split,
              icon: Icons.view_column_outlined,
              label: l10n.printPreviewSplitViewAction,
            ),
            modeButton(
              value: AppPrintPreviewPaneMode.sections,
              icon: Icons.checklist_outlined,
              label: l10n.printPreviewSectionsOnlyAction,
            ),
            modeButton(
              value: AppPrintPreviewPaneMode.preview,
              icon: Icons.article_outlined,
              label: l10n.printPreviewPreviewOnlyAction,
            ),
          ],
        ),
      ),
    );
  }
}

/// Two-column print workspace with independently scrollable panes.
///
/// The parent dialog should set `scrollable: false` so only these columns
/// scroll — never the dialog shell and columns together.
class AppPrintPreviewWorkspace extends StatelessWidget {
  const AppPrintPreviewWorkspace({
    required this.height,
    required this.preview,
    this.sectionPicker,
    this.leading,
    this.paneMode = AppPrintPreviewPaneMode.split,
    this.onPaneModeChanged,
    this.paneModeEnabled = true,
    this.sideBySideBreakpoint = 720,
    this.sectionsFlex = 2,
    this.previewFlex = 3,
    this.sectionsScrollable = true,
    super.key,
  });

  final double height;
  final Widget preview;
  final Widget? sectionPicker;
  final Widget? leading;
  final AppPrintPreviewPaneMode paneMode;
  final ValueChanged<AppPrintPreviewPaneMode>? onPaneModeChanged;
  final bool paneModeEnabled;
  final double sideBySideBreakpoint;
  final int sectionsFlex;
  final int previewFlex;

  /// When false, the sections column fills height and lets its child scroll.
  final bool sectionsScrollable;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final bool showSections =
        sectionPicker != null &&
        (paneMode == AppPrintPreviewPaneMode.split ||
            paneMode == AppPrintPreviewPaneMode.sections);
    final bool showPreview =
        paneMode == AppPrintPreviewPaneMode.split ||
        paneMode == AppPrintPreviewPaneMode.preview;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (leading != null) Expanded(child: leading!),
              if (onPaneModeChanged != null) ...<Widget>[
                if (leading != null) SizedBox(width: theme.spacing.sm),
                AppPrintPreviewPaneModeBar(
                  mode: paneMode,
                  enabled: paneModeEnabled,
                  onChanged: onPaneModeChanged!,
                ),
              ],
            ],
          ),
          if (leading != null || onPaneModeChanged != null)
            SizedBox(height: theme.spacing.sm),
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool sideBySide =
                    constraints.maxWidth >= sideBySideBreakpoint &&
                    showSections &&
                    showPreview;

                final Widget? sectionsPane = showSections
                    ? _ScrollPane(
                        semanticLabel: l10n.printPreviewSectionsPaneLabel,
                        scrollable: sectionsScrollable,
                        child: sectionPicker!,
                      )
                    : null;
                final Widget? previewPane = showPreview
                    ? _ScrollPane(
                        semanticLabel: l10n.printPreviewPreviewPaneLabel,
                        // Preview HTML scrolls inside the iframe; keep Flutter
                        // pane non-nested by expanding to fill.
                        scrollable: false,
                        child: preview,
                      )
                    : null;

                if (sideBySide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(flex: sectionsFlex, child: sectionsPane!),
                      SizedBox(width: theme.spacing.md),
                      Expanded(flex: previewFlex, child: previewPane!),
                    ],
                  );
                }

                if (sectionsPane != null && previewPane != null) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(flex: 2, child: sectionsPane),
                      SizedBox(height: theme.spacing.md),
                      Expanded(flex: 3, child: previewPane),
                    ],
                  );
                }

                return sectionsPane ?? previewPane ?? const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ScrollPane extends StatelessWidget {
  const _ScrollPane({
    required this.child,
    required this.semanticLabel,
    this.scrollable = true,
  });

  final Widget child;
  final String semanticLabel;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    final Widget body = scrollable
        ? Scrollbar(
            child: SingleChildScrollView(
              primary: false,
              padding: EdgeInsets.all(theme.spacing.sm),
              child: child,
            ),
          )
        : Padding(
            padding: EdgeInsets.all(theme.spacing.sm),
            child: SizedBox.expand(child: child),
          );

    return Semantics(
      container: true,
      label: semanticLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: ClipRect(child: body),
      ),
    );
  }
}

/// Shared zoom helpers for print preview surfaces.
abstract final class AppPrintPreviewZoom {
  static const double min = 0.5;
  static const double max = 2;
  static const double step = 0.1;
  static const double coarseStep = 0.25;
  static const double pageWidthPx = 820;

  static double clamp(double value) => value.clamp(min, max).toDouble();

  static double zoomIn(double scale) => clamp(scale + step);

  static double zoomOut(double scale) => clamp(scale - step);

  static double increase(double scale) => clamp(scale + coarseStep);

  static double decrease(double scale) => clamp(scale - coarseStep);

  static double fitPage(double availableWidth) {
    if (!availableWidth.isFinite || availableWidth <= 0) {
      return 1;
    }
    return clamp(availableWidth / pageWidthPx);
  }
}

/// Opens the standard HTML print-preview dialog used by simple print flows.
Future<void> showAppPrintPreviewDialog({
  required BuildContext context,
  required String title,
  required String documentHtml,
  required Future<void> Function() onPrint,
  String? body,
  Widget? fallbackChild,
  String? fallbackText,
  String? previewTitle,
  String? printLabel,
  IconData icon = Icons.print_outlined,
  double maxWidth = 960,
  bool popAfterPrint = true,
}) {
  return showAppDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _AppPrintPreviewDialog(
      title: title,
      body: body,
      documentHtml: documentHtml,
      fallbackChild: fallbackChild,
      fallbackText: fallbackText,
      previewTitle: previewTitle,
      printLabel: printLabel,
      icon: icon,
      maxWidth: maxWidth,
      popAfterPrint: popAfterPrint,
      onPrint: onPrint,
    ),
  );
}

class _AppPrintPreviewDialog extends StatefulWidget {
  const _AppPrintPreviewDialog({
    required this.title,
    required this.documentHtml,
    required this.onPrint,
    this.body,
    this.fallbackChild,
    this.fallbackText,
    this.previewTitle,
    this.printLabel,
    this.icon = Icons.print_outlined,
    this.maxWidth = 960,
    this.popAfterPrint = true,
  });

  final String title;
  final String? body;
  final String documentHtml;
  final Widget? fallbackChild;
  final String? fallbackText;
  final String? previewTitle;
  final String? printLabel;
  final IconData icon;
  final double maxWidth;
  final bool popAfterPrint;
  final Future<void> Function() onPrint;

  @override
  State<_AppPrintPreviewDialog> createState() => _AppPrintPreviewDialogState();
}

class _AppPrintPreviewDialogState extends State<_AppPrintPreviewDialog> {
  bool _isPrinting = false;
  bool _previewMaximized = false;
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final double viewportHeight = MediaQuery.sizeOf(context).height;
    final double workspaceHeight = (viewportHeight * 0.68).clamp(360.0, 820.0);
    final String printLabel = widget.printLabel ?? l10n.commonPrintActionLabel;

    return AppDialog(
      title: Text(widget.title),
      icon: Icon(widget.icon),
      scrollable: false,
      pinActionsToBottom: true,
      maxWidth: widget.maxWidth,
      closeEnabled: !_isPrinting,
      content: SizedBox(
        height: workspaceHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (!_previewMaximized && widget.body != null) ...<Widget>[
              Text(
                widget.body!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: theme.spacing.sm),
            ],
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  return AppPrintPreviewPanel(
                    html: widget.documentHtml,
                    title: widget.previewTitle,
                    height: constraints.maxHeight,
                    scale: _scale,
                    maximized: _previewMaximized,
                    maximizeEnabled: !_isPrinting,
                    onZoomIn: () {
                      setState(
                        () => _scale = AppPrintPreviewZoom.zoomIn(_scale),
                      );
                    },
                    onZoomOut: () {
                      setState(
                        () => _scale = AppPrintPreviewZoom.zoomOut(_scale),
                      );
                    },
                    onZoomIncrease: () {
                      setState(
                        () => _scale = AppPrintPreviewZoom.increase(_scale),
                      );
                    },
                    onZoomDecrease: () {
                      setState(
                        () => _scale = AppPrintPreviewZoom.decrease(_scale),
                      );
                    },
                    onFitPage: () {
                      setState(() {
                        _scale = AppPrintPreviewZoom.fitPage(
                          constraints.maxWidth - theme.spacing.lg * 2,
                        );
                      });
                    },
                    onMaximizeToggle: () {
                      setState(() => _previewMaximized = !_previewMaximized);
                    },
                    fallbackChild:
                        widget.fallbackChild ??
                        SelectableText(
                          widget.fallbackText ?? widget.title,
                          style: theme.textTheme.bodyMedium,
                        ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCloseActionLabel,
          enabled: !_isPrinting,
          onPressed: _isPrinting ? null : () => Navigator.of(context).pop(),
        ),
        AppReportActionButton.print(
          label: printLabel,
          enabled: !_isPrinting,
          isLoading: _isPrinting,
          onPressed: _isPrinting ? null : () => _print(),
        ),
      ],
    );
  }

  Future<void> _print() async {
    setState(() => _isPrinting = true);
    try {
      await widget.onPrint();
      if (!mounted) {
        return;
      }
      if (widget.popAfterPrint) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }
}
