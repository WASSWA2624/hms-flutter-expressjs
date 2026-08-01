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
///
/// Renders without a titled header strip. Zoom toolbar and document scroll
/// together inside [height]. Maximize (when provided) lives on the toolbar.
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

  /// Unused; retained for call-site compatibility. Title chrome was removed.
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
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AppLocalizations l10n = context.l10n;

    final Widget document = SizedBox(
      height: height,
      width: double.infinity,
      child: AppPrintHtmlPreview(
        html: html,
        scale: scale,
        fallbackChild: fallbackChild,
        viewTypePrefix: viewTypePrefix,
      ),
    );

    final Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (toolbarEnabled) ...<Widget>[
          AppPrintPreviewToolbar(
            scale: scale,
            maximized: maximized,
            enabled: maximizeEnabled,
            showMaximize: onMaximizeToggle != null,
            onZoomIn: onZoomIn,
            onZoomOut: onZoomOut,
            onZoomIncrease: onZoomIncrease,
            onZoomDecrease: onZoomDecrease,
            onFitPage: onFitPage,
            onMaximizeToggle: onMaximizeToggle,
          ),
          if (headerActions.isNotEmpty) ...<Widget>[
            SizedBox(height: theme.spacing.xs),
            Wrap(
              spacing: theme.spacing.xs,
              runSpacing: theme.spacing.xs,
              children: headerActions,
            ),
          ],
          SizedBox(height: theme.spacing.sm),
        ],
        document,
      ],
    );

    return Semantics(
      container: true,
      label: title ?? l10n.printPreviewPreviewPaneLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Scrollbar(
            child: SingleChildScrollView(
              primary: false,
              padding: EdgeInsets.all(theme.spacing.xs),
              child: body,
            ),
          ),
        ),
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

/// Toggle between split / sections-only / preview-only layouts via [AppTabStrip].
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

    final Widget strip = AppTabStrip(
      variant: AppTabStripVariant.nested,
      tabs: <AppTabItem>[
        AppTabItem(
          id: AppPrintPreviewPaneMode.split.name,
          icon: Icons.view_column_outlined,
          label: l10n.printPreviewSplitViewAction,
        ),
        AppTabItem(
          id: AppPrintPreviewPaneMode.sections.name,
          icon: Icons.checklist_outlined,
          label: l10n.printPreviewSectionsOnlyAction,
        ),
        AppTabItem(
          id: AppPrintPreviewPaneMode.preview.name,
          icon: Icons.article_outlined,
          label: l10n.printPreviewPreviewOnlyAction,
        ),
      ],
      selectedId: mode.name,
      onTabTapped: (String id) {
        if (!enabled) {
          return;
        }
        final AppPrintPreviewPaneMode next = AppPrintPreviewPaneMode.values
            .byName(id);
        if (next != mode) {
          onChanged(next);
        }
      },
    );

    if (enabled) {
      return strip;
    }
    return Opacity(opacity: 0.6, child: strip);
  }
}

/// Two-column print workspace with independently scrollable panes.
///
/// The parent dialog should set `scrollable: false` so only these columns
/// scroll — never the dialog shell and columns together. Prefer
/// `contentPadding: EdgeInsets.zero` on the host [AppDialog].
///
/// Pane-mode tabs sit with the sections column only. In preview-only mode a
/// compact strip remains so the user can switch back.
class AppPrintPreviewWorkspace extends StatelessWidget {
  const AppPrintPreviewWorkspace({
    required this.preview,
    this.height,
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

  /// When null, expands to the parent's max height (use inside an [Expanded]
  /// or dialog body with finite constraints).
  final double? height;
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
    if (height != null) {
      return SizedBox(
        height: height,
        width: double.infinity,
        child: _buildBody(context),
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double resolvedHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 420;
        return SizedBox(
          height: resolvedHeight,
          width: double.infinity,
          child: _buildBody(context),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final bool showSections =
        sectionPicker != null &&
        (paneMode == AppPrintPreviewPaneMode.split ||
            paneMode == AppPrintPreviewPaneMode.sections);
    final bool showPreview =
        paneMode == AppPrintPreviewPaneMode.split ||
        paneMode == AppPrintPreviewPaneMode.preview;

    Widget? modeStrip;
    if (onPaneModeChanged != null) {
      modeStrip = AppPrintPreviewPaneModeBar(
        mode: paneMode,
        enabled: paneModeEnabled,
        onChanged: onPaneModeChanged!,
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool sideBySide =
            constraints.maxWidth >= sideBySideBreakpoint &&
            showSections &&
            showPreview;

        final Widget? sectionsPane = showSections
            ? _buildSectionsColumn(
                context: context,
                theme: theme,
                l10n: l10n,
                modeStrip: modeStrip,
              )
            : null;
        final Widget? previewPane = showPreview
            ? _buildPreviewColumn(
                context: context,
                theme: theme,
                l10n: l10n,
                // Compact return path when sections are hidden.
                modeStrip: showSections ? null : modeStrip,
              )
            : null;

        if (sideBySide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(flex: sectionsFlex, child: sectionsPane!),
              SizedBox(width: theme.spacing.sm),
              Expanded(flex: previewFlex, child: previewPane!),
            ],
          );
        }

        if (sectionsPane != null && previewPane != null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(flex: 2, child: sectionsPane),
              SizedBox(height: theme.spacing.sm),
              Expanded(flex: 3, child: previewPane),
            ],
          );
        }

        return sectionsPane ?? previewPane ?? const SizedBox.shrink();
      },
    );
  }

  Widget _buildSectionsColumn({
    required BuildContext context,
    required ThemeData theme,
    required AppLocalizations l10n,
    required Widget? modeStrip,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ?modeStrip,
        if (leading != null) ...<Widget>[
          if (modeStrip != null) SizedBox(height: theme.spacing.xs),
          leading!,
        ],
        if (modeStrip != null || leading != null)
          SizedBox(height: theme.spacing.xs),
        Expanded(
          child: _ScrollPane(
            semanticLabel: l10n.printPreviewSectionsPaneLabel,
            scrollable: sectionsScrollable,
            child: sectionPicker!,
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewColumn({
    required BuildContext context,
    required ThemeData theme,
    required AppLocalizations l10n,
    required Widget? modeStrip,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (modeStrip != null) ...<Widget>[
          modeStrip,
          SizedBox(height: theme.spacing.xs),
        ],
        Expanded(
          // Preview panel owns chrome + scrolling (toolbar + document).
          child: Semantics(
            container: true,
            label: l10n.printPreviewPreviewPaneLabel,
            child: preview,
          ),
        ),
      ],
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
    final EdgeInsets resolvedPadding = EdgeInsets.all(theme.spacing.xs);

    final Widget body = scrollable
        ? Scrollbar(
            child: SingleChildScrollView(
              primary: false,
              padding: resolvedPadding,
              child: child,
            ),
          )
        : Padding(
            padding: resolvedPadding,
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
    final String printLabel = widget.printLabel ?? l10n.commonPrintActionLabel;

    return AppDialog(
      title: Text(widget.title),
      icon: Icon(widget.icon),
      pinActionsToBottom: true,
      contentPadding: EdgeInsets.zero,
      maxWidth: widget.maxWidth,
      closeEnabled: !_isPrinting,
      content: Padding(
        padding: EdgeInsets.symmetric(horizontal: theme.spacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (!_previewMaximized && widget.body != null) ...<Widget>[
              Padding(
                padding: EdgeInsets.fromLTRB(
                  theme.spacing.sm,
                  theme.spacing.sm,
                  theme.spacing.sm,
                  0,
                ),
                child: Text(
                  widget.body!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
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
