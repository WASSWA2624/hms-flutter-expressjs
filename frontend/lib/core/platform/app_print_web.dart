import 'dart:js_interop';

import 'package:web/web.dart' as web;

void printCurrentWindow() {
  web.window.print();
}

void printHtmlDocument(String html, {String title = 'Print document'}) {
  final String escapedTitle = _escapeHtml(title);
  final String baseHref = _escapeHtml(web.window.location.href);
  final String document =
      '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <base href="$baseHref">
  <title>$escapedTitle</title>
</head>
<body>
$html
<script>
  window.addEventListener('load', function () {
    window.focus();
    window.print();
  });
</script>
</body>
</html>
''';
  final web.Window? printWindow = web.window.open('', '_blank');
  if (printWindow == null) {
    return;
  }
  printWindow.document.open();
  printWindow.document.write(document.toJS);
  printWindow.document.close();
  printWindow.focus();
}

String _escapeHtml(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}
