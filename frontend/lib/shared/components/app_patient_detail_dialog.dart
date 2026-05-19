import 'package:flutter/material.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_dialog.dart';

class AppPatientDetailDialog extends StatelessWidget {
  const AppPatientDetailDialog({
    required this.title,
    required this.semanticLabel,
    required this.content,
    required this.closeLabel,
    this.icon = const Icon(Icons.badge_outlined),
    this.maxWidth = 1040,
    this.actions = const <Widget>[],
    super.key,
  });

  final String title;
  final String semanticLabel;
  final Widget content;
  final String closeLabel;
  final Widget icon;
  final double maxWidth;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: Text(title),
      icon: icon,
      semanticLabel: semanticLabel,
      scrollable: true,
      maxWidth: maxWidth,
      content: content,
      actions: <Widget>[
        ...actions,
        AppButton.secondary(
          label: closeLabel,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}
