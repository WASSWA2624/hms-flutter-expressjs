import 'package:flutter/material.dart';

/// Signals that descendants are inside an [AppListTable] data cell and should
/// wrap long text instead of truncating with ellipsis.
class AppListTableTextPolicy extends InheritedWidget {
  const AppListTableTextPolicy({required super.child, super.key});

  static bool wrapOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<AppListTableTextPolicy>() !=
        null;
  }

  @override
  bool updateShouldNotify(AppListTableTextPolicy oldWidget) => false;
}
