import 'package:flutter/material.dart';

class AppFieldErrorText extends StatelessWidget {
  const AppFieldErrorText({required this.errorText, super.key});

  final String? errorText;

  @override
  Widget build(BuildContext context) {
    if (errorText == null || errorText!.isEmpty) {
      return const SizedBox.shrink();
    }

    final ThemeData theme = Theme.of(context);

    return Text(
      errorText!,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.error,
      ),
    );
  }
}
