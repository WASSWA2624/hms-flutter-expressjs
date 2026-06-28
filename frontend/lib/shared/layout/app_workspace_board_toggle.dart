import 'package:flutter/material.dart';

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
    return SegmentedButton<T>(
      showSelectedIcon: false,
      segments: segments,
      selected: <T>{value},
      onSelectionChanged: (Set<T> selection) {
        if (selection.isNotEmpty) {
          onChanged(selection.first);
        }
      },
    );
  }
}
