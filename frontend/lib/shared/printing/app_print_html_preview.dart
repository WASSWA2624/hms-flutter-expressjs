import 'package:flutter/widgets.dart';
import 'package:hosspi_hms/shared/printing/app_print_html_preview_stub.dart'
    if (dart.library.html) 'package:hosspi_hms/shared/printing/app_print_html_preview_web.dart';

/// Renders print-template HTML inside a scrollable preview surface.
///
/// On web this embeds the HTML document (same chrome as print). On other
/// platforms / tests it falls back to [fallbackChild].
class AppPrintHtmlPreview extends StatelessWidget {
  const AppPrintHtmlPreview({
    required this.html,
    required this.fallbackChild,
    this.scale = 1,
    this.focusedPage,
    this.viewTypePrefix = 'app-print-html-preview',
    super.key,
  });

  final String html;
  final Widget fallbackChild;
  final double scale;

  /// 1-based page to scroll into view inside the HTML document, when pages
  /// are marked with `article.print-template-page`.
  final int? focusedPage;
  final String viewTypePrefix;

  @override
  Widget build(BuildContext context) {
    return buildAppPrintHtmlPreview(
      context: context,
      html: html,
      fallbackChild: fallbackChild,
      scale: scale,
      focusedPage: focusedPage,
      viewTypePrefix: viewTypePrefix,
    );
  }
}
