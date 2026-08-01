import 'package:flutter/widgets.dart';

Widget buildAppPrintHtmlPreview({
  required BuildContext context,
  required String html,
  required Widget fallbackChild,
  required String viewTypePrefix,
  double scale = 1,
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
