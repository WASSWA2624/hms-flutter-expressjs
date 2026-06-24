import 'package:flutter/foundation.dart';

enum AppTextScaleLevel {
  normal(100),
  large(115),
  extraLarge(130);

  const AppTextScaleLevel(this.storageValue);

  final int storageValue;

  double get factor => storageValue / 100;

  static AppTextScaleLevel fromStorage(int? value) {
    return switch (value) {
      115 => AppTextScaleLevel.large,
      130 => AppTextScaleLevel.extraLarge,
      _ => AppTextScaleLevel.normal,
    };
  }
}

@immutable
final class AppAccessibilityPreferences {
  const AppAccessibilityPreferences({
    this.reduceMotion = false,
    this.boldText = false,
    this.textScaleLevel = AppTextScaleLevel.normal,
  });

  final bool reduceMotion;
  final bool boldText;
  final AppTextScaleLevel textScaleLevel;

  double get textScaleFactor => textScaleLevel.factor;

  AppAccessibilityPreferences copyWith({
    bool? reduceMotion,
    bool? boldText,
    AppTextScaleLevel? textScaleLevel,
  }) {
    return AppAccessibilityPreferences(
      reduceMotion: reduceMotion ?? this.reduceMotion,
      boldText: boldText ?? this.boldText,
      textScaleLevel: textScaleLevel ?? this.textScaleLevel,
    );
  }
}
