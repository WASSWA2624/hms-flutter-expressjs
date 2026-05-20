import 'package:flutter/widgets.dart';

class AppActionLabelScope extends InheritedWidget {
  const AppActionLabelScope({
    required this.showLabels,
    required this.forceIconOnly,
    required super.child,
    super.key,
  });

  final bool showLabels;
  final bool forceIconOnly;

  static AppActionLabelScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppActionLabelScope>();
  }

  @override
  bool updateShouldNotify(AppActionLabelScope oldWidget) {
    return showLabels != oldWidget.showLabels ||
        forceIconOnly != oldWidget.forceIconOnly;
  }
}
