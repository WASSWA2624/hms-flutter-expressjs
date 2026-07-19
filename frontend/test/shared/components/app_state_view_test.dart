import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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
    expect(find.byType(AppLoadingIndicator), findsOneWidget);
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

    expect(find.text('Could not load'), findsOneWidget);
    expect(find.text('Try the request again.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('AppStateView exposes validation state content', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppStateView(
        variant: AppStateViewVariant.validation,
        title: 'Review required fields',
        body: 'Fix highlighted fields before continuing.',
      ),
    );

    expect(find.text('Review required fields'), findsOneWidget);
    expect(
      find.text('Fix highlighted fields before continuing.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.fact_check_outlined), findsOneWidget);
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

  testWidgets('AppFailureStateView centers icon and title in one row', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppFailureStateView(failure: AppFailure.timeout()),
    );

    final Offset iconCenter = tester.getCenter(
      find.byIcon(Icons.error_outline),
    );
    final Offset titleCenter = tester.getCenter(find.text('Request timed out'));

    expect(iconCenter.dy, closeTo(titleCenter.dy, 1));
    expect(titleCenter.dx, greaterThan(iconCenter.dx));
  });

  testWidgets('AppFailureStateView keeps async retry single-flight', (
    WidgetTester tester,
  ) async {
    final List<Completer<void>> attempts = <Completer<void>>[];

    await pumpComponent(
      tester,
      AppFailureStateView(
        failure: const AppFailure.timeout(),
        onRetry: () {
          final Completer<void> attempt = Completer<void>();
          attempts.add(attempt);
          return attempt.future;
        },
      ),
    );
    final Size idleSize = tester.getSize(find.byType(AppButton));

    await tester.tap(find.text('Try again'));
    await tester.pump();

    expect(attempts, hasLength(1));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<AppButton>(find.byType(AppButton)).isLoading, isTrue);
    expect(tester.getSize(find.byType(AppButton)), idleSize);
    final SemanticsNode retrySemantics = tester.getSemantics(
      find.byType(AppButton),
    );
    expect(retrySemantics.hasFlag(SemanticsFlag.isLiveRegion), isTrue);
    expect(retrySemantics.hasFlag(SemanticsFlag.isEnabled), isFalse);

    await tester.tap(find.text('Try again'));
    expect(attempts, hasLength(1));

    attempts.single.complete();
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.widget<AppButton>(find.byType(AppButton)).isLoading, isFalse);

    await tester.tap(find.text('Try again'));
    expect(attempts, hasLength(2));
    attempts.last.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('AppFailureStateScaffold centers failure content vertically', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppFailureStateScaffold(failure: AppFailure.timeout()),
    );

    expect(
      tester.getCenter(find.byType(AppFailureStateView)).dy,
      closeTo(300, 1),
    );
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
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('AppFailureStateView renders retryable conflict failures', (
    WidgetTester tester,
  ) async {
    var retryCount = 0;

    await pumpComponent(
      tester,
      AppFailureStateView(
        failure: AppFailure.conflict(),
        onRetry: () {
          retryCount += 1;
        },
      ),
    );

    expect(find.text('Update conflict'), findsOneWidget);
    expect(
      find.text('This record changed. Refresh and try again.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.sync_problem_outlined), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    expect(retryCount, 1);
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
    expect(find.byIcon(Icons.wifi_off_outlined), findsOneWidget);
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

  testWidgets('AsyncStateScaffold keeps previous data visible during refresh', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      AsyncStateScaffold<String>(
        value: const AsyncLoading<Result<String>>().copyWithPrevious(
          const AsyncData<Result<String>>(
            Result<String>.success('Organization'),
          ),
        ),
        keepPreviousDataDuringRefresh: true,
        loadingTitle: 'Loading',
        loadingBody: 'Preparing content.',
        dataBuilder: (_, value) => Text('Dashboard: $value'),
      ),
    );

    expect(find.text('Dashboard: Organization'), findsOneWidget);
    expect(find.text('Loading'), findsNothing);
  });
}
