import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';

@immutable
final class AppThemePalette {
  const AppThemePalette({
    required this.colorScheme,
    required this.statusColors,
    required this.scaffoldBackgroundColor,
    required this.canvasColor,
    required this.hoverColor,
    required this.splashColor,
    required this.highlightColor,
    required this.bodyTextColor,
    required this.displayTextColor,
    required this.borderColor,
    required this.disabledBorderColor,
    required this.focusedBorderColor,
    required this.inputFillColor,
    required this.inputHoverColor,
    required this.inputHintColor,
    required this.inputLabelColor,
    required this.inputFloatingLabelColor,
    required this.appBarBackgroundColor,
    required this.appBarForegroundColor,
    required this.appBarSurfaceTintColor,
    required this.dividerColor,
    required this.drawerBackgroundColor,
  });

  final ColorScheme colorScheme;
  final AppStatusColors statusColors;
  final Color scaffoldBackgroundColor;
  final Color canvasColor;
  final Color hoverColor;
  final Color splashColor;
  final Color highlightColor;
  final Color bodyTextColor;
  final Color displayTextColor;
  final Color borderColor;
  final Color disabledBorderColor;
  final Color focusedBorderColor;
  final Color inputFillColor;
  final Color inputHoverColor;
  final Color inputHintColor;
  final Color inputLabelColor;
  final Color inputFloatingLabelColor;
  final Color appBarBackgroundColor;
  final Color appBarForegroundColor;
  final Color appBarSurfaceTintColor;
  final Color dividerColor;
  final Color drawerBackgroundColor;
}
