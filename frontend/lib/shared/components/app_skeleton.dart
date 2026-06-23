import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';

/// Lightweight pulse skeleton used while async content is loading.
class AppSkeletonBox extends StatefulWidget {
  const AppSkeletonBox({
    this.width,
    this.height = 14,
    this.borderRadius,
    super.key,
  });

  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  State<AppSkeletonBox> createState() => _AppSkeletonBoxState();
}

class _AppSkeletonBoxState extends State<AppSkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.34, end: 0.62).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final BorderRadius radius =
        widget.borderRadius ?? BorderRadius.circular(theme.radius.xs);

    return FadeTransition(
      opacity: _opacity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.onSurface.withValues(alpha: 0.08),
          borderRadius: radius,
        ),
        child: SizedBox(
          width: widget.width,
          height: widget.height,
        ),
      ),
    );
  }
}

/// Skeleton layout that mirrors the patient detail modal structure.
class AppPatientDetailSkeleton extends StatelessWidget {
  const AppPatientDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSpacingTokens spacing = theme.spacing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: spacing.sm,
          runSpacing: spacing.sm,
          children: List<Widget>.generate(
            6,
            (_) => const AppSkeletonBox(width: 112, height: 36),
          ),
        ),
        SizedBox(height: spacing.lg),
        for (var index = 0; index < 4; index++) ...<Widget>[
          _SkeletonSection(),
          if (index < 3) SizedBox(height: spacing.md),
        ],
      ],
    );
  }
}

class _SkeletonSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSpacingTokens spacing = theme.spacing;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const AppSkeletonBox(width: 180, height: 18),
            SizedBox(height: spacing.sm),
            const AppSkeletonBox(height: 12),
            SizedBox(height: spacing.xs),
            const AppSkeletonBox(width: 280, height: 12),
            SizedBox(height: spacing.xs),
            const AppSkeletonBox(width: 220, height: 12),
          ],
        ),
      ),
    );
  }
}
