import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/app_permission_catalog_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_en.dart';

void main() {
  final AppLocalizationsEn l10n = AppLocalizationsEn();

  group('permissionCatalogDescriptionForCode', () {
    test('generates domain/action descriptions like backend metadata', () {
      expect(
        l10n.permissionCatalogDescriptionForCode('patient:read'),
        'Allows read access within patient.',
      );
      expect(
        l10n.permissionCatalogDescriptionForCode('roster:publish'),
        'Allows publish access within roster.',
      );
    });

    test('uses override descriptions for elevated permissions', () {
      expect(
        l10n.permissionCatalogDescriptionForCode('platform:admin'),
        'Full platform administration across tenants and global settings.',
      );
      expect(
        l10n.permissionCatalogDescriptionForCode('break_glass:request'),
        'Request temporary elevated access to restricted patient records.',
      );
    });

    test('does not return the display-name label', () {
      expect(
        l10n.permissionCatalogDescriptionForCode('patient:read'),
        isNot(l10n.permissionCatalogLabelForCode('patient:read')),
      );
    });
  });
}
