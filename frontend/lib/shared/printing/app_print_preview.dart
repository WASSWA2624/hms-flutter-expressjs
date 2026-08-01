import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/printing/app_print_html_preview.dart';

/// Shared HTML print-preview surface (maximize + iframe/fallback).
///
/// Use this for every print dialog so previews match the printed
/// [PrintFormTemplate] chrome.
class AppPrintPreviewPanel extends StatelessWidget {
  const AppPrintPreviewPanel({
    required this.html,
    required this.fallbackChild,
    this.title,
    this.height = 420,
    this.maximized = false,
    this.onMaximizeToggle,
    this.maximizeEnabled = true,
    this.viewTypePrefix = 'app-print-html-preview',
    super.key,
  });

  final String html;
  final Widget fallbackChild;
  final String? title;
  final double height;
  final bool maximized;
  final VoidCallback? onMaximizeToggle;
  final bool maximizeEnabled;
  final String viewTypePrefix;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final bool canMaximize = onMaximizeToggle != null;
    final String maximizeLabel = maximized
        ? l10n.printPreviewRestoreAction
        : l10n.printPreviewMaximizeAction;

    return AppReportPreviewPanel(
      title: title ?? l10n.printPreviewTitle,
      collapsible: false,
      maxBodyHeight: height,
      scrollBody: false,
      contentPadding: EdgeInsets.all(theme.spacing.sm),
      headerActions: canMaximize
          ? <Widget>[
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
            ]
          : const <Widget>[],
      child: AppPrintHtmlPreview(
        html: html,
        fallbackChild: fallbackChild,
        viewTypePrefix: viewTypePrefix,
      ),
    );
  }
}

/// Side-by-side / stacked layout used by section-picker print dialogs.
class AppPrintPreviewLayout extends StatelessWidget {
  const AppPrintPreviewLayout({
    required this.preview,
    this.leading,
    this.sectionPicker,
    this.buildSectionPicker,
    this.previewMaximized = false,
    this.sideBySideBreakpoint = 640,
    super.key,
  }) : assert(
         sectionPicker == null || buildSectionPicker == null,
         'Provide sectionPicker or buildSectionPicker, not both.',
       );

  final Widget preview;
  final Widget? leading;
  final Widget? sectionPicker;
  final Widget Function(BuildContext context, {required bool sideBySide})?
  buildSectionPicker;
  final bool previewMaximized;
  final double sideBySideBreakpoint;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (previewMaximized) {
      return preview;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (leading != null) ...<Widget>[
          leading!,
          SizedBox(height: theme.spacing.md),
        ],
        if (sectionPicker == null && buildSectionPicker == null)
          preview
        else
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool sideBySide =
                  constraints.maxWidth >= sideBySideBreakpoint;
              final Widget picker =
                  sectionPicker ??
                  buildSectionPicker!(context, sideBySide: sideBySide);
              if (!sideBySide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    picker,
                    SizedBox(height: theme.spacing.md),
                    preview,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(flex: 2, child: picker),
                  SizedBox(width: theme.spacing.md),
                  Expanded(flex: 3, child: preview),
                ],
              );
            },
          ),
      ],
    );
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
  static const double _previewHeight = 420;

  bool _isPrinting = false;
  bool _previewMaximized = false;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final double viewportHeight = MediaQuery.sizeOf(context).height;
    final double maximizedPreviewHeight = (viewportHeight * 0.72).clamp(
      360.0,
      900.0,
    );
    final String printLabel = widget.printLabel ?? l10n.commonPrintActionLabel;

    return AppDialog(
      title: Text(widget.title),
      icon: Icon(widget.icon),
      scrollable: !_previewMaximized,
      pinActionsToBottom: true,
      maxWidth: widget.maxWidth,
      closeEnabled: !_isPrinting,
      content: AppPrintPreviewLayout(
        previewMaximized: _previewMaximized,
        leading: _previewMaximized || widget.body == null
            ? null
            : Text(
                widget.body!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
        preview: AppPrintPreviewPanel(
          html: widget.documentHtml,
          title: widget.previewTitle,
          height: _previewMaximized
              ? maximizedPreviewHeight
              : _previewHeight,
          maximized: _previewMaximized,
          maximizeEnabled: !_isPrinting,
          onMaximizeToggle: () {
            setState(() => _previewMaximized = !_previewMaximized);
          },
          fallbackChild:
              widget.fallbackChild ??
              SelectableText(
                widget.fallbackText ?? widget.title,
                style: theme.textTheme.bodyMedium,
              ),
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
