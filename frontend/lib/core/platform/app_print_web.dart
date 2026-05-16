import 'dart:convert';

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
  final String url = Uri.dataFromString(
    document,
    mimeType: 'text/html',
    encoding: utf8,
  ).toString();
  web.window.open(url, '_blank');
}
