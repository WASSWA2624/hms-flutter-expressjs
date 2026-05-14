# Example App Structure

## Scope
Shows the expected shape of the root app widget. This file is an example, not a place for business logic.

## Example
```dart
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeControllerProvider);
    final locale = ref.watch(localeControllerProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
    );
  }
}
```

## Rules
- Keep `App` small.
- Do not initialize services inside `App.build`.
- Watch only app-level providers here.
- Keep route config, theme config, localization config, and startup work outside widget business logic.
- Keep theme mode and locale reactive.
- Keep `MaterialApp.router` as the single root app widget.

## Related rules
- [`startup_flow.md`](./startup_flow.md)
- [`navigation.md`](./navigation.md)
- [`theming.md`](./theming.md)
- [`localization_i18n.md`](./localization_i18n.md)
- [`state_management.md`](./state_management.md)
