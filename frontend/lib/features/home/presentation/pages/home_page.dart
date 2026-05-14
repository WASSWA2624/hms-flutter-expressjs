import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_template/app/theme/app_theme_extensions.dart';
import 'package:flutter_template/core/responsive/app_breakpoints.dart';
import 'package:flutter_template/features/home/domain/entities/home_readiness_snapshot.dart';
import 'package:flutter_template/features/home/presentation/controllers/home_controller.dart';
import 'package:flutter_template/l10n/app_localizations.dart';
import 'package:flutter_template/l10n/app_localizations_x.dart';
import 'package:flutter_template/shared/components/components.dart';
import 'package:flutter_template/shared/layout/responsive_page.dart';

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
          _StarterFeatureGrid(features: _starterFeatures(l10n)),
          SizedBox(height: spacing.md),
          const _SupportedPlatformList(),
        ],
      ),
    );
  }
}

class _StarterFeatureGrid extends StatelessWidget {
  const _StarterFeatureGrid({required this.features});

  final List<_StarterFeature> features;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSpacingTokens spacing = theme.spacing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          context.l10n.homeStarterFeaturesLabel,
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
                    for (final _StarterFeature feature in features)
                      SizedBox(
                        width: itemWidth,
                        child: _StarterFeatureItem(feature: feature),
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

class _StarterFeatureItem extends StatelessWidget {
  const _StarterFeatureItem({required this.feature});

  final _StarterFeature feature;

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
              feature.icon,
              color: colorScheme.primary,
              size: theme.appTokens.listIconSize,
            ),
            SizedBox(width: theme.spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(feature.title, style: theme.textTheme.titleSmall),
                  SizedBox(height: theme.spacing.xs),
                  Text(
                    feature.body,
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

List<_StarterFeature> _starterFeatures(AppLocalizations l10n) {
  return <_StarterFeature>[
    _StarterFeature(
      icon: Icons.devices_outlined,
      title: l10n.homeFeatureResponsiveTitle,
      body: l10n.homeFeatureResponsiveBody,
    ),
    _StarterFeature(
      icon: Icons.route_outlined,
      title: l10n.homeFeatureNavigationTitle,
      body: l10n.homeFeatureNavigationBody,
    ),
    _StarterFeature(
      icon: Icons.translate_outlined,
      title: l10n.homeFeatureLocalizationTitle,
      body: l10n.homeFeatureLocalizationBody,
    ),
    _StarterFeature(
      icon: Icons.tune_outlined,
      title: l10n.homeFeatureSettingsTitle,
      body: l10n.homeFeatureSettingsBody,
    ),
  ];
}

final class _StarterFeature {
  const _StarterFeature({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

class _SupportedPlatformList extends StatelessWidget {
  const _SupportedPlatformList();

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
        Text(l10n.homeSupportedPlatformsLabel, style: textTheme.titleMedium),
        SizedBox(height: spacing.sm),
        for (final String platform in l10n.supportedStarterPlatforms)
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
                Expanded(child: Text(platform, style: textTheme.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }
}
