import 'package:flutter/widgets.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';

/// Relative importance of an `AppDialog` footer action.
///
/// Drives which actions stay on the inline footer row and which collapse into
/// the "More actions" menu when the labeled row cannot fit.
enum AppDialogActionPriority {
  /// Confirm / submit. Always stays inline.
  primary,

  /// Dismiss (Close / Cancel). Always stays inline.
  dismiss,

  /// Supporting action. First to move into the overflow menu.
  secondary,
}

/// Optional wrapper that overrides the priority inferred from a footer action.
///
/// Most call sites need nothing: [resolveAppDialogActionPriority] already reads
/// [AppButton.close] as [AppDialogActionPriority.dismiss] and
/// [AppButtonVariant.primary] as [AppDialogActionPriority.primary]. Wrap an
/// action only when the inferred priority is wrong — for example a secondary
/// button that must never leave the inline row:
///
/// ```dart
/// AppDialogAction(
///   priority: AppDialogActionPriority.primary,
///   child: AppButton.secondary(label: 'Post', onPressed: onPost),
/// )
/// ```
class AppDialogAction extends StatelessWidget {
  const AppDialogAction({
    required this.priority,
    required this.child,
    super.key,
  });

  final AppDialogActionPriority priority;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// Unwraps [AppDialogAction] so containers can inspect the underlying control.
Widget unwrapAppDialogAction(Widget action) {
  return action is AppDialogAction ? action.child : action;
}

/// Priority for [action].
///
/// An explicit [AppDialogAction] wins. Otherwise the priority is inferred from
/// the underlying [AppButton]: the dismiss control and primary-variant buttons
/// stay inline, everything else is overflow-eligible. Non-[AppButton] actions
/// default to [AppDialogActionPriority.secondary].
AppDialogActionPriority resolveAppDialogActionPriority(Widget action) {
  if (action is AppDialogAction) {
    return action.priority;
  }
  if (action is AppButton) {
    if (action.isDismissAction) {
      return AppDialogActionPriority.dismiss;
    }
    if (action.variant == AppButtonVariant.primary) {
      return AppDialogActionPriority.primary;
    }
  }
  return AppDialogActionPriority.secondary;
}

/// Whether [action] may be moved into the overflow menu.
///
/// Only an inspectable [AppButton] can be re-rendered faithfully as a menu row
/// (icon, label, enabled state). Anything else — a permission gate that builds
/// its child lazily, a custom control, a widget that hides itself when denied —
/// stays on the inline row, where it renders exactly as its author intended.
/// Wrapping such an action in [AppDialogAction] opts it back in explicitly.
bool isAppDialogActionOverflowEligible(Widget action) {
  if (action is AppDialogAction) {
    return action.priority == AppDialogActionPriority.secondary;
  }
  if (action is! AppButton) {
    return false;
  }
  return resolveAppDialogActionPriority(action) ==
      AppDialogActionPriority.secondary;
}
