import 'package:flutter/material.dart';

class AppDialog extends StatelessWidget {
  const AppDialog({
    this.title,
    this.content,
    this.actions = const <Widget>[],
    this.icon,
    this.semanticLabel,
    this.scrollable = false,
    super.key,
  });

  final Widget? title;
  final Widget? content;
  final List<Widget> actions;
  final Widget? icon;
  final String? semanticLabel;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    Widget dialog = AlertDialog(
      icon: icon,
      title: title,
      content: content,
      actions: actions,
      scrollable: scrollable,
    );

    if (semanticLabel != null) {
      dialog = Semantics(
        namesRoute: true,
        scopesRoute: true,
        explicitChildNodes: true,
        label: semanticLabel,
        child: dialog,
      );
    }

    return FocusTraversalGroup(child: dialog);
  }
}

Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  TraversalEdgeBehavior traversalEdgeBehavior =
      TraversalEdgeBehavior.closedLoop,
  bool requestFocus = true,
  RouteSettings? routeSettings,
}) async {
  final FocusNode? previousFocus = FocusManager.instance.primaryFocus;
  final T? result = await showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    traversalEdgeBehavior: traversalEdgeBehavior,
    requestFocus: requestFocus,
    routeSettings: routeSettings,
    builder: (BuildContext context) {
      return FocusTraversalGroup(child: builder(context));
    },
  );

  if (previousFocus case final FocusNode node
      when node.context != null && node.canRequestFocus) {
    node.requestFocus();
  }

  return result;
}
