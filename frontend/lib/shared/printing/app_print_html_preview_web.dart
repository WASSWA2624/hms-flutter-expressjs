import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

Widget buildAppPrintHtmlPreview({
  required BuildContext context,
  required String html,
  required Widget fallbackChild,
  required String viewTypePrefix,
  double scale = 1,
  int? focusedPage,
}) {
  return _AppPrintHtmlPreviewWeb(
    html: html,
    scale: scale,
    focusedPage: focusedPage,
    viewTypePrefix: viewTypePrefix,
  );
}

class _AppPrintHtmlPreviewWeb extends StatefulWidget {
  const _AppPrintHtmlPreviewWeb({
    required this.html,
    required this.scale,
    required this.viewTypePrefix,
    this.focusedPage,
  });

  final String html;
  final double scale;
  final int? focusedPage;
  final String viewTypePrefix;

  @override
  State<_AppPrintHtmlPreviewWeb> createState() =>
      _AppPrintHtmlPreviewWebState();
}

class _AppPrintHtmlPreviewWebState extends State<_AppPrintHtmlPreviewWeb> {
  late final String _viewType;
  late final web.HTMLIFrameElement _iframe;
  bool _factoryRegistered = false;
  web.EventListener? _loadListener;

  @override
  void initState() {
    super.initState();
    _viewType = '${widget.viewTypePrefix}-${identityHashCode(this)}';
    _iframe = web.HTMLIFrameElement()
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.backgroundColor = '#f3f4f6'
      ..setAttribute('sandbox', 'allow-same-origin');
    _loadListener = ((web.Event _) {
      _scrollToFocusedPage();
    }).toJS;
    _iframe.addEventListener('load', _loadListener!);
    _registerFactory();
    _writeHtml(widget.html, widget.scale);
  }

  @override
  void dispose() {
    final web.EventListener? listener = _loadListener;
    if (listener != null) {
      _iframe.removeEventListener('load', listener);
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _AppPrintHtmlPreviewWeb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html) {
      _writeHtml(widget.html, widget.scale);
      return;
    }
    if (oldWidget.scale != widget.scale) {
      _applyZoom(widget.scale);
    }
    if (oldWidget.focusedPage != widget.focusedPage) {
      _scrollToFocusedPage();
    }
  }

  void _registerFactory() {
    if (_factoryRegistered) {
      return;
    }
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _iframe,
    );
    _factoryRegistered = true;
  }

  void _writeHtml(String html, double scale) {
    final String baseHref = _escapeHtml(web.window.location.href);
    final String zoom = scale.clamp(0.4, 2.5).toStringAsFixed(3);
    final String documentHtml =
        '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <base href="$baseHref">
  <style>
    html, body {
      margin: 0;
      padding: 0;
      background: #f3f4f6;
      height: 100%;
      overflow: auto;
    }
    body {
      zoom: $zoom;
    }
  </style>
</head>
<body>
$html
</body>
</html>
''';
    _iframe.srcdoc = documentHtml.toJS;
  }

  void _applyZoom(double scale) {
    final web.Document? doc = _iframe.contentDocument;
    final web.HTMLElement? body = doc?.body;
    if (body == null) {
      return;
    }
    body.style.zoom = scale.clamp(0.4, 2.5).toStringAsFixed(3);
  }

  void _scrollToFocusedPage() {
    final int? page = widget.focusedPage;
    if (page == null || page < 1) {
      return;
    }
    final web.Document? doc = _iframe.contentDocument;
    if (doc == null) {
      return;
    }
    final web.NodeList pages = doc.querySelectorAll(
      'article.print-template-page',
    );
    final int index = page - 1;
    if (index < 0 || index >= pages.length) {
      return;
    }
    final web.Element? target = pages.item(index) as web.Element?;
    target?.scrollIntoView();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}

String _escapeHtml(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}
