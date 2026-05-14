import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_readiness_snapshot.dart';
import 'package:hosspi_hms/features/home/presentation/controllers/home_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/responsive_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readiness = ref.watch(homeControllerProvider);
    final l10n = context.l10n;

    return AsyncStateScaffold<HomeReadinessSnapshot>(
      value: readiness,
      loadingTitle: l10n.homeLoadingTitle,
      loadingBody: l10n.homeLoadingBody,
      maxWidth: PageMaxWidth.reading,
      centerVertically: false,
      onRetry: () {
        ref.read(homeControllerProvider.notifier).refresh();
      },
      dataBuilder: (context, snapshot) {
        if (!snapshot.isReady) {
          return const _HomeLoadingView();
        }

        return const _HomeReadyContent();
      },
    );
  }
}

class _HomeReadyContent extends StatelessWidget {
  const _HomeReadyContent();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;
    final AppSpacingTokens spacing = theme.spacing;
    final l10n = context.l10n;

    return ResponsivePage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppLogo(size: theme.appTokens.statusIconSize),
          SizedBox(height: spacing.md),
          Text(l10n.appTitle, style: textTheme.headlineMedium),
          SizedBox(height: spacing.sm),
          Text(l10n.homeReadyTitle, style: textTheme.titleLarge),
          SizedBox(height: spacing.sm),
          Text(
            l10n.homeReadyBody,
            style: textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: spacing.xl),
          _HomeEntryPointGrid(entryPoints: _homeEntryPoints(l10n)),
          SizedBox(height: spacing.md),
          const _ServiceAreaList(),
        ],
      ),
    );
  }
}

class _HomeEntryPointGrid extends StatelessWidget {
  const _HomeEntryPointGrid({required this.entryPoints});

  final List<_HomeEntryPoint> entryPoints;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSpacingTokens spacing = theme.spacing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          context.l10n.homeEntryPointsLabel,
          style: theme.textTheme.titleMedium,
        ),
        SizedBox(height: spacing.md),
        ResponsiveBuilder(
          builder: (BuildContext context, AppBreakpoint breakpoint) {
            final bool singleColumn = breakpoint.isMobile;

            return LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double itemWidth = singleColumn
                    ? constraints.maxWidth
                    : (constraints.maxWidth - spacing.md) / 2;

                return Wrap(
                  spacing: spacing.md,
                  runSpacing: spacing.md,
                  children: <Widget>[
                    for (final _HomeEntryPoint entryPoint in entryPoints)
                      SizedBox(
                        width: itemWidth,
                        child: _HomeEntryPointItem(entryPoint: entryPoint),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _HomeEntryPointItem extends StatelessWidget {
  const _HomeEntryPointItem({required this.entryPoint});

  final _HomeEntryPoint entryPoint;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              entryPoint.icon,
              color: colorScheme.primary,
              size: theme.appTokens.listIconSize,
            ),
            SizedBox(width: theme.spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(entryPoint.title, style: theme.textTheme.titleSmall),
                  SizedBox(height: theme.spacing.xs),
                  Text(
                    entryPoint.body,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeLoadingView extends StatelessWidget {
  const _HomeLoadingView();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return ResponsivePage(
      maxWidth: PageMaxWidth.form,
      centerVertically: true,
      child: AppStateView(
        variant: AppStateViewVariant.loading,
        title: l10n.homeLoadingTitle,
        body: l10n.homeLoadingBody,
      ),
    );
  }
}

List<_HomeEntryPoint> _homeEntryPoints(AppLocalizations l10n) {
  return <_HomeEntryPoint>[
    _HomeEntryPoint(
      icon: Icons.assignment_ind_outlined,
      title: l10n.homeFeatureResponsiveTitle,
      body: l10n.homeFeatureResponsiveBody,
    ),
    _HomeEntryPoint(
      icon: Icons.medical_services_outlined,
      title: l10n.homeFeatureNavigationTitle,
      body: l10n.homeFeatureNavigationBody,
    ),
    _HomeEntryPoint(
      icon: Icons.receipt_long_outlined,
      title: l10n.homeFeatureLocalizationTitle,
      body: l10n.homeFeatureLocalizationBody,
    ),
    _HomeEntryPoint(
      icon: Icons.business_outlined,
      title: l10n.homeFeatureSettingsTitle,
      body: l10n.homeFeatureSettingsBody,
    ),
  ];
}

final class _HomeEntryPoint {
  const _HomeEntryPoint({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

class _ServiceAreaList extends StatelessWidget {
  const _ServiceAreaList();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;
    final AppDesignTokens appTokens = theme.appTokens;
    final AppSpacingTokens spacing = theme.spacing;
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(l10n.homeServiceAreasLabel, style: textTheme.titleMedium),
        SizedBox(height: spacing.sm),
        for (final String serviceArea in l10n.homeServiceAreas)
          Padding(
            padding: EdgeInsets.only(bottom: spacing.xs),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.check_circle_outline,
                  color: theme.statusColors.success,
                  size: appTokens.listIconSize,
                ),
                SizedBox(width: spacing.xs),
                Expanded(child: Text(serviceArea, style: textTheme.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }
}
