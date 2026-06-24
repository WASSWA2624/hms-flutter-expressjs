/// Application font configuration.
///
/// Bundled Roboto files are registered under [primary] instead of `Roboto`
/// because reusing the Material default family name on Flutter web overrides
/// the engine's font resolution and can prevent all text from rendering.
abstract final class AppFontFamily {
  static const String primary = 'HosspiSans';

  static const List<String> fallback = <String>[
    'Segoe UI',
    'Arial',
    'Helvetica Neue',
    'sans-serif',
  ];
}
