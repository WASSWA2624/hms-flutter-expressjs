import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/shared/components/components.dart';

import 'component_test_app.dart';

void main() {
  testWidgets('AppStateView renders loading content with progress semantics', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppStateView(
        variant: AppStateViewVariant.loading,
        title: 'Loading',
        body: 'Preparing content.',
      ),
    );

    expect(find.text('Loading'), findsOneWidget);
    expect(find.text('Preparing content.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('AppStateScaffold renders app bar and action content', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      AppStateScaffold(
        appBarTitle: 'Template',
        variant: AppStateViewVariant.error,
        title: 'Could not load',
        body: 'Try the request again.',
        action: AppButton.primary(label: 'Retry', onPressed: () {}),
      ),
    );

    expect(find.text('Template'), findsOneWidget);
    expect(find.text('Could not load'), findsOneWidget);
    expect(find.text('Try the request again.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('AppFailureStateView renders localized retryable failures', (
    WidgetTester tester,
  ) async {
    var retryCount = 0;

    await pumpComponent(
      tester,
      AppFailureStateView(
        failure: const AppFailure.timeout(),
        onRetry: () {
          retryCount += 1;
        },
      ),
    );

    expect(find.text('Request timed out'), findsOneWidget);
    expect(find.text('The request took too long. Try again.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);

    await tester.tap(find.text('Try again'));
    expect(retryCount, 1);
  });

  testWidgets('AppFailureStateView hides retry for non-retryable failures', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppFailureStateView(failure: AppFailure.forbidden()),
    );

    expect(find.text('Access denied'), findsOneWidget);
    expect(find.text('You do not have permission.'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('AsyncStateScaffold maps typed result failures to error views', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      AsyncStateScaffold<String>(
        value: const AsyncData<Result<String>>(
          Result<String>.failure(AppFailure.offline()),
        ),
        loadingTitle: 'Loading',
        loadingBody: 'Preparing content.',
        onRetry: () {},
        dataBuilder: (_, value) => Text(value),
      ),
    );

    expect(find.text('No connection'), findsOneWidget);
    expect(find.text('Connect to the internet and try again.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Loading'), findsNothing);
  });

  testWidgets('AsyncStateScaffold renders typed empty data consistently', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      AsyncStateScaffold<List<String>>(
        value: const AsyncData<Result<List<String>>>(
          Result<List<String>>.success(<String>[]),
        ),
        loadingTitle: 'Loading',
        loadingBody: 'Preparing content.',
        emptyPredicate: (List<String> items) => items.isEmpty,
        emptyTitle: 'No results',
        emptyBody: 'Adjust filters and try again.',
        dataBuilder: (_, items) => Text('Loaded ${items.length}'),
      ),
    );

    expect(find.text('No results'), findsOneWidget);
    expect(find.text('Adjust filters and try again.'), findsOneWidget);
    expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    expect(find.text('Loaded 0'), findsNothing);
  });
}
