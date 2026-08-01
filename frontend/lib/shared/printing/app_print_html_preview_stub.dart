import 'package:flutter/widgets.dart';

Widget buildAppPrintHtmlPreview({
  required BuildContext context,
  required Widget fallbackChild,
  required String viewTypePrefix,
  String html = '',
  double scale = 1,
  int? focusedPage,
}) {
  if ((scale - 1).abs() < 0.001) {
    return fallbackChild;
  }
  return Transform.scale(
    scale: scale,
    alignment: Alignment.topCenter,
    child: fallbackChild,
  );
}
