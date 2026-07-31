import 'package:flutter/material.dart';

/// Maps vital type codes / display labels to consistent Material icons.
IconData appVitalTypeIcon(String? vitalType) {
  final String key = (vitalType ?? '')
      .trim()
      .toUpperCase()
      .replaceAll(RegExp(r'[\s\-]+'), '_');
  if (key.isEmpty) {
    return Icons.monitor_heart_outlined;
  }
  if (key.contains('BLOOD_PRESSURE') ||
      key == 'BP' ||
      key.contains('SYSTOLIC') ||
      key.contains('DIASTOLIC')) {
    return Icons.favorite_outline;
  }
  if (key.contains('TEMP')) {
    return Icons.thermostat_outlined;
  }
  if (key.contains('HEART') || key.contains('PULSE') || key == 'HR') {
    return Icons.monitor_heart_outlined;
  }
  if (key.contains('RESP') || key == 'RR') {
    return Icons.air;
  }
  if (key.contains('OXYGEN') ||
      key.contains('SPO2') ||
      key.contains('SATURATION') ||
      key.contains('SPO₂')) {
    return Icons.bloodtype_outlined;
  }
  if (key.contains('WEIGHT') || key.contains('BMI')) {
    return Icons.monitor_weight_outlined;
  }
  if (key.contains('HEIGHT')) {
    return Icons.height_outlined;
  }
  if (key.contains('PAIN')) {
    return Icons.healing_outlined;
  }
  if (key.contains('GLUCOSE') || key.contains('SUGAR')) {
    return Icons.water_drop_outlined;
  }
  return Icons.monitor_heart_outlined;
}
