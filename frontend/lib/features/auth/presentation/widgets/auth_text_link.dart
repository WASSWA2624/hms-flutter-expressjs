import 'package:flutter/material.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';

class AuthTextLink extends StatelessWidget {
  const AuthTextLink({
    required this.label,
    required this.onPressed,
    this.alignment = Alignment.center,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: AppButton.tertiary(
        label: label,
        onPressed: onPressed,
        semanticLabel: label,
      ),
    );
  }
}
