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

/// Counts and clamps print-template pages in preview HTML.
abstract final class AppPrintPreviewPages {
  static final RegExp _pageArticlePattern = RegExp(
    r'''<article\b[^>]*\bclass\s*=\s*["'][^"']*\bprint-template-page\b''',
    caseSensitive: false,
  );

  /// Counts explicit `article.print-template-page` nodes. Always at least 1.
  static int countFromHtml(String html) {
    final int count = _pageArticlePattern.allMatches(html).length;
    return count < 1 ? 1 : count;
  }

  static int clampPage(int page, int pageCount) {
    final int total = pageCount < 1 ? 1 : pageCount;
    if (page < 1) {
      return 1;
    }
    if (page > total) {
      return total;
    }
    return page;
  }
}

/// Shared HTML print-preview document surface.
///
/// Prefer [toolbarEnabled] `false` when the parent owns [AppPrintPreviewToolbar]
/// (workspace strip or simple dialog chrome).
class AppPrintPreviewPanel extends StatelessWidget {
  const AppPrintPreviewPanel({
    required this.html,
    required this.fallbackChild,
    this.title,
    this.height,
    this.scale = 1,
    this.focusedPage,
    this.onZoomIn,
    this.onZoomOut,
    this.onZoomIncrease,
    this.onZoomDecrease,
    this.onFitPage,
    this.currentPage = 1,
    this.pageCount = 1,
    this.onPagePrevious,
    this.onPageNext,
    this.toolbarEnabled = true,
    this.headerActions = const <Widget>[],
    this.viewTypePrefix = 'app-print-html-preview',
    super.key,
  });

  final String html;
  final Widget fallbackChild;

  /// Unused; retained for call-site compatibility. Title chrome was removed.
  final String? title;

  /// Fixed preview height. When null and [toolbarEnabled] is false, the panel
  /// expands to fill its parent (preferred in workspace layouts).
  final double? height;
  final double scale;

  /// 1-based page to focus in the HTML preview.
  final int? focusedPage;
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;
  final VoidCallback? onZoomIncrease;
  final VoidCallback? onZoomDecrease;
  final VoidCallback? onFitPage;
  final int currentPage;
  final int pageCount;
  final VoidCallback? onPagePrevious;
  final VoidCallback? onPageNext;
  final bool toolbarEnabled;
  final List<Widget> headerActions;
  final String viewTypePrefix;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AppLocalizations l10n = context.l10n;
    final int resolvedPage =
        focusedPage ?? AppPrintPreviewPages.clampPage(currentPage, pageCount);

    final Widget document = AppPrintHtmlPreview(
      html: html,
      scale: scale,
      focusedPage: resolvedPage,
      fallbackChild: fallbackChild,
      viewTypePrefix: viewTypePrefix,
    );

    Widget framed(Widget child) {
      return Semantics(
        container: true,
        label: title ?? l10n.printPreviewPreviewPaneLabel,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest,
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: child,
        ),
      );
    }

    if (!toolbarEnabled) {
      final Widget padded = Padding(
        padding: EdgeInsets.all(theme.spacing.xs),
        child: document,
      );
      if (height != null) {
        return framed(
          SizedBox(height: height, width: double.infinity, child: padded),
        );
      }
      return framed(SizedBox.expand(child: padded));
    }

    final double resolvedHeight = height ?? 420;
    final Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AppPrintPreviewToolbar(
          scale: scale,
          currentPage: currentPage,
          pageCount: pageCount,
          onZoomIn: onZoomIn,
          onZoomOut: onZoomOut,
          onZoomIncrease: onZoomIncrease,
          onZoomDecrease: onZoomDecrease,
          onFitPage: onFitPage,
          onPagePrevious: onPagePrevious,
          onPageNext: onPageNext,
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
        SizedBox(
          height: resolvedHeight,
          width: double.infinity,
          child: document,
        ),
      ],
    );

    return framed(
      SizedBox(
        height: resolvedHeight,
        width: double.infinity,
        child: Scrollbar(
          child: SingleChildScrollView(
            primary: false,
            padding: EdgeInsets.all(theme.spacing.xs),
            child: body,
          ),
        ),
      ),
    );
  }
}

/// Zoom / page / fit controls for print previews.
///
/// Dialog/window maximize stays on [AppDialog] chrome. Use the Preview pane
/// tab for a preview-only layout — this toolbar does not include a maximize
/// control.
class AppPrintPreviewToolbar extends StatelessWidget {
  const AppPrintPreviewToolbar({
    required this.scale,
    this.enabled = true,
    this.showPageControls = true,
    this.currentPage = 1,
    this.pageCount = 1,
    this.onZoomOut,
    this.onZoomIn,
    this.onZoomDecrease,
    this.onZoomIncrease,
    this.onFitPage,
    this.onPagePrevious,
    this.onPageNext,
    super.key,
  });

  final double scale;
  final bool enabled;
  final bool showPageControls;
  final int currentPage;
  final int pageCount;
  final VoidCallback? onZoomOut;
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomDecrease;
  final VoidCallback? onZoomIncrease;
  final VoidCallback? onFitPage;
  final VoidCallback? onPagePrevious;
  final VoidCallback? onPageNext;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String zoomLabel = l10n.printPreviewZoomPercentLabel(
      (scale * 100).round(),
    );
    final int total = pageCount < 1 ? 1 : pageCount;
    final int page = AppPrintPreviewPages.clampPage(currentPage, total);
    final String pageLabel = l10n.printPreviewPageOfLabel(page, total);

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
        if (showPageControls) ...<Widget>[
          SizedBox(width: theme.spacing.xs),
          tool(
            icon: Icons.keyboard_arrow_left,
            label: l10n.printPreviewPreviousPageAction,
            onPressed: page <= 1 ? null : onPagePrevious,
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: theme.spacing.xs),
            child: Text(
              pageLabel,
              style: theme.textTheme.labelMedium?.copyWith(
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ),
          tool(
            icon: Icons.keyboard_arrow_right,
            label: l10n.printPreviewNextPageAction,
            onPressed: page >= total ? null : onPageNext,
          ),
        ],
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
/// Pane-mode tabs and optional [toolbar] sit in the left (sections) column
/// only, so the preview document can use the full right-pane height.
/// Preview-only mode keeps a compact tabs + toolbar strip above the document.
class AppPrintPreviewWorkspace extends StatelessWidget {
  const AppPrintPreviewWorkspace({
    required this.preview,
    this.height,
    this.sectionPicker,
    this.leading,
    this.toolbar,
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

  /// Zoom/page chrome under the pane tabs in the left column.
  final Widget? toolbar;
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
    final bool showToolbar = toolbar != null && showPreview;

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
                showToolbar: showToolbar,
              )
            : null;
        final Widget? previewPane = showPreview
            ? _buildPreviewColumn(
                context: context,
                theme: theme,
                l10n: l10n,
                // Compact return path when sections are hidden.
                modeStrip: showSections ? null : modeStrip,
                showToolbar: showSections ? false : showToolbar,
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
    required bool showToolbar,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ?modeStrip,
        if (modeStrip != null && showToolbar) SizedBox(height: theme.spacing.xs),
        if (showToolbar) ...<Widget>[
          toolbar!,
          SizedBox(height: theme.spacing.xs),
        ] else if (modeStrip != null || leading != null)
          SizedBox(height: theme.spacing.xs),
        if (leading != null) ...<Widget>[
          leading!,
          SizedBox(height: theme.spacing.xs),
        ],
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
    required bool showToolbar,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ?modeStrip,
        if (modeStrip != null && showToolbar) SizedBox(height: theme.spacing.xs),
        if (showToolbar) ...<Widget>[
          toolbar!,
          SizedBox(height: theme.spacing.xs),
        ] else if (modeStrip != null)
          SizedBox(height: theme.spacing.xs),
        Expanded(
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
  double _scale = 1;
  int _currentPage = 1;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String printLabel = widget.printLabel ?? l10n.commonPrintActionLabel;
    final int pageCount = AppPrintPreviewPages.countFromHtml(
      widget.documentHtml,
    );
    final int currentPage = AppPrintPreviewPages.clampPage(
      _currentPage,
      pageCount,
    );

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
            if (widget.body != null) ...<Widget>[
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
            Padding(
              padding: EdgeInsets.fromLTRB(
                theme.spacing.xs,
                theme.spacing.xs,
                theme.spacing.xs,
                0,
              ),
              child: AppPrintPreviewToolbar(
                scale: _scale,
                enabled: !_isPrinting,
                currentPage: currentPage,
                pageCount: pageCount,
                onZoomIn: () {
                  setState(() => _scale = AppPrintPreviewZoom.zoomIn(_scale));
                },
                onZoomOut: () {
                  setState(() => _scale = AppPrintPreviewZoom.zoomOut(_scale));
                },
                onZoomIncrease: () {
                  setState(() => _scale = AppPrintPreviewZoom.increase(_scale));
                },
                onZoomDecrease: () {
                  setState(() => _scale = AppPrintPreviewZoom.decrease(_scale));
                },
                onFitPage: () {
                  setState(() {
                    _scale = AppPrintPreviewZoom.fitPage(
                      widget.maxWidth - theme.spacing.lg * 2,
                    );
                  });
                },
                onPagePrevious: () {
                  setState(() {
                    _currentPage = AppPrintPreviewPages.clampPage(
                      currentPage - 1,
                      pageCount,
                    );
                  });
                },
                onPageNext: () {
                  setState(() {
                    _currentPage = AppPrintPreviewPages.clampPage(
                      currentPage + 1,
                      pageCount,
                    );
                  });
                },
              ),
            ),
            SizedBox(height: theme.spacing.xs),
            Expanded(
              child: AppPrintPreviewPanel(
                html: widget.documentHtml,
                title: widget.previewTitle,
                scale: _scale,
                toolbarEnabled: false,
                focusedPage: currentPage,
                currentPage: currentPage,
                pageCount: pageCount,
                fallbackChild:
                    widget.fallbackChild ??
                    SelectableText(
                      widget.fallbackText ?? widget.title,
                      style: theme.textTheme.bodyMedium,
                    ),
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
