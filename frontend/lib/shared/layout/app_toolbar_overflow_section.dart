import 'package:flutter/material.dart';

/// A labeled group of toolbar actions rendered inside the overflow menu.
@immutable
final class AppToolbarOverflowSection {
  const AppToolbarOverflowSection({
    this.headerLabel,
    this.actions = const <Widget>[],
    this.showsNotifications = false,
  });

  /// Presentational section title; omitted when null.
  final String? headerLabel;

  /// Toolbar action widgets belonging to this section.
  final List<Widget> actions;

  /// When true, the workspace summary-notifications submenu is rendered here.
  final bool showsNotifications;
}
