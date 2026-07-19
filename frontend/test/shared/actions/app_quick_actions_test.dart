import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  testWidgets('renders and invokes feature-provided actions', (tester) async {
    var pressed = 0;

    await tester.pumpWidget(
      wrap(
        AppQuickActions(
          title: 'Quick actions',
          presentation: AppQuickActionsPresentation.plain,
          actions: <AppActionItem>[
            AppActionItem(
              label: 'Register patient',
              leadingIcon: Icons.person_add_outlined,
              onPressed: () => pressed += 1,
            ),
          ],
        ),
      ),
    );

    expect(find.text('Quick actions'), findsOneWidget);
    expect(find.text('Register patient'), findsOneWidget);

    await tester.tap(find.text('Register patient'));
    await tester.pump();

    expect(pressed, 1);
  });

  testWidgets('supports an explicit empty state', (tester) async {
    await tester.pumpWidget(
      wrap(
        const AppQuickActions(
          title: 'Quick actions',
          hideWhenEmpty: false,
          emptyState: Text('No actions available'),
        ),
      ),
    );

    expect(find.text('Quick actions'), findsOneWidget);
    expect(find.text('No actions available'), findsOneWidget);
  });

  testWidgets('hides an empty group by default', (tester) async {
    await tester.pumpWidget(
      wrap(const AppQuickActions(title: 'Quick actions')),
    );

    expect(find.text('Quick actions'), findsNothing);
  });

  testWidgets('supports extraActions alongside empty action lists', (
    tester,
  ) async {
    var pressed = 0;

    await tester.pumpWidget(
      wrap(
        AppQuickActions(
          title: 'Quick actions',
          presentation: AppQuickActionsPresentation.plain,
          extraActions: <Widget>[
            TextButton(
              onPressed: () => pressed += 1,
              child: const Text('Extra'),
            ),
          ],
        ),
      ),
    );

    expect(find.text('Quick actions'), findsOneWidget);
    await tester.tap(find.text('Extra'));
    await tester.pump();
    expect(pressed, 1);
  });
}
