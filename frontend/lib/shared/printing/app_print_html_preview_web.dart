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
}) {
  return _AppPrintHtmlPreviewWeb(
    html: html,
    scale: scale,
    viewTypePrefix: viewTypePrefix,
  );
}

class _AppPrintHtmlPreviewWeb extends StatefulWidget {
  const _AppPrintHtmlPreviewWeb({
    required this.html,
    required this.scale,
    required this.viewTypePrefix,
  });

  final String html;
  final double scale;
  final String viewTypePrefix;

  @override
  State<_AppPrintHtmlPreviewWeb> createState() =>
      _AppPrintHtmlPreviewWebState();
}

class _AppPrintHtmlPreviewWebState extends State<_AppPrintHtmlPreviewWeb> {
  late final String _viewType;
  late final web.HTMLIFrameElement _iframe;
  bool _factoryRegistered = false;

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
    _registerFactory();
    _writeHtml(widget.html, widget.scale);
  }

  @override
  void didUpdateWidget(covariant _AppPrintHtmlPreviewWeb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html || oldWidget.scale != widget.scale) {
      _writeHtml(widget.html, widget.scale);
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
