import 'dart:js_interop';

import 'package:web/web.dart' as web;

void printCurrentWindow() {
  web.window.print();
}

void printHtmlDocument(String html) {
  final String document =
      '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>Patient report</title>
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
