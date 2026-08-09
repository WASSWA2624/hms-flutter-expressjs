import 'package:flutter/widgets.dart';

class AppActionLabelScope extends InheritedWidget {
  const AppActionLabelScope({
    required this.showLabels,
    required this.forceIconOnly,
    this.plainChrome = false,
    this.dense = false,
    required super.child,
    super.key,
  });

  final bool showLabels;
  final bool forceIconOnly;

  /// When true, [AppButton] descendants omit resting fill and borders
  /// (section header actions).
  final bool plainChrome;

  /// When true, [AppButton] descendants use dense padding/min height.
  final bool dense;

  static AppActionLabelScope? maybeOf(BuildContext context) {
    // Use get (not dependOn) so descendants do not keep InheritedElement
    // dependents alive across shell/router rebuilds after session rehydrate.
    return context.getInheritedWidgetOfExactType<AppActionLabelScope>();
  }

  @override
  bool updateShouldNotify(AppActionLabelScope oldWidget) {
    return showLabels != oldWidget.showLabels ||
        forceIconOnly != oldWidget.forceIconOnly ||
        plainChrome != oldWidget.plainChrome ||
        dense != oldWidget.dense;
  }
}
