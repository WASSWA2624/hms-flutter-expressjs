import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/utils/app_media_url.dart';

void main() {
  final Uri apiBase = Uri.parse('http://127.0.0.1:3000');

  test('returns null for empty values', () {
    expect(resolveAppMediaUrl(null, apiBase), isNull);
    expect(resolveAppMediaUrl('  ', apiBase), isNull);
  });

  test('keeps absolute http urls', () {
    expect(
      resolveAppMediaUrl('https://cdn.example.com/a.png', apiBase),
      'https://cdn.example.com/a.png',
    );
  });

  test('prefixes storage keys with /uploads against the API origin', () {
    expect(
      resolveAppMediaUrl('logo-4869585d.png?v=9', apiBase),
      'http://127.0.0.1:3000/uploads/logo-4869585d.png?v=9',
    );
  });

  test('keeps /uploads paths and resolves against the API origin', () {
    expect(
      resolveAppMediaUrl('/uploads/logo-4869585d.png', apiBase),
      'http://127.0.0.1:3000/uploads/logo-4869585d.png',
    );
  });
}
