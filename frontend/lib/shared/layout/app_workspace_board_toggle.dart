import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';

/// Patient/bed board mode toggle shared by IPD, ICU, and similar workspaces.
class AppWorkspaceBoardToggle<T extends Object> extends StatelessWidget {
  const AppWorkspaceBoardToggle({
    required this.value,
    required this.segments,
    required this.onChanged,
    super.key,
  });

  final T value;
  final List<ButtonSegment<T>> segments;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppRadiusTokens radius = theme.radius;
    final BorderRadius borderRadius = BorderRadius.circular(radius.sm);

    return SegmentedButton<T>(
      showSelectedIcon: false,
      segments: segments,
      selected: <T>{value},
      style:
          SegmentedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(borderRadius: borderRadius),
          ).copyWith(
            side: WidgetStateProperty.resolveWith<BorderSide?>((
              Set<WidgetState> states,
            ) {
              return theme.borders.side(color: theme.colorScheme.outlineVariant, width: states.contains(WidgetState.selected) ? 1.25 : 1,
              );
            }),
          ),
      onSelectionChanged: (Set<T> selection) {
        if (selection.isNotEmpty) {
          onChanged(selection.first);
        }
      },
    );
  }
}
