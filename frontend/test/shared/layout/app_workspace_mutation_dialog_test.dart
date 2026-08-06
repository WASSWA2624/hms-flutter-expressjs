import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/app_workspace_mutation_dialog.dart';

import '../components/component_test_app.dart';

void main() {
  testWidgets('mutation dialog pins footer actions to the bottom', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      Builder(
        builder: (BuildContext context) {
          return TextButton(
            onPressed: () {
              showAppWorkspaceMutationDialog(
                context: context,
                title: const Text('Short form'),
                submitLabel: 'Save',
                cancelLabel: 'Close',
                submitIcon: Icons.save_outlined,
                cancelIcon: Icons.close_outlined,
                buildFields:
                    (
                      BuildContext context,
                      GlobalKey<FormState> formKey,
                      bool isSubmitting, [
                      _,
                    ]) {
                      return const AppFormSection(
                        children: <Widget>[
                          AppTextField(labelText: 'Name', isRequired: true),
                        ],
                      );
                    },
                onSubmit: () async => null,
              );
            },
            child: const Text('Open mutation dialog'),
          );
        },
      ),
      size: const Size(900, 640),
    );

    await tester.tap(find.text('Open mutation dialog'));
    await tester.pumpAndSettle();

    final Offset saveTop = tester.getTopLeft(find.text('Save'));
    final Offset nameTop = tester.getTopLeft(find.text('Name *'));
    final double dialogBottom = tester.getBottomLeft(find.byType(Dialog)).dy;
    final double saveBottom = tester.getBottomLeft(find.text('Save')).dy;

    expect(saveTop.dy, greaterThan(nameTop.dy + 200));
    expect(dialogBottom - saveBottom, lessThan(140));
  });
}
