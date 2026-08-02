import 'package:dio/dio.dart';
import 'package:hosspi_hms/shared/scan/drug_pack_field_parser.dart';

/// Free/public barcode → drug field lookup. Soft-fail only; never required.
abstract class DrugPackBarcodeLookup {
  Future<DrugPackFieldCandidates?> lookup(String barcode);
}

/// Always returns null (tests / offline default).
final class DrugPackNoOpBarcodeLookup implements DrugPackBarcodeLookup {
  const DrugPackNoOpBarcodeLookup();

  @override
  Future<DrugPackFieldCandidates?> lookup(String barcode) async => null;
}

/// Tries providers in order; first non-empty identity result wins.
final class CompositeDrugPackBarcodeLookup implements DrugPackBarcodeLookup {
  const CompositeDrugPackBarcodeLookup(this.providers);

  final List<DrugPackBarcodeLookup> providers;

  @override
  Future<DrugPackFieldCandidates?> lookup(String barcode) async {
    final String code = barcode.trim();
    if (code.isEmpty) {
      return null;
    }
    for (final DrugPackBarcodeLookup provider in providers) {
      try {
        final DrugPackFieldCandidates? result = await provider.lookup(code);
        if (result != null && result.hasAnyIdentityField) {
          return result.copyWithBarcode(code);
        }
      } catch (_) {
        // Soft-fail: try next provider.
      }
    }
    return null;
  }
}

/// Open Food Facts product API (free; some OTC/pharma packs).
final class OpenFoodFactsDrugPackBarcodeLookup
    implements DrugPackBarcodeLookup {
  OpenFoodFactsDrugPackBarcodeLookup({Dio? dio})
    : _dio = dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
              headers: <String, String>{
                'User-Agent': 'HosspiHMS/1.0 (pharmacy pack assist)',
              },
            ),
          );

  final Dio _dio;
  static const DrugPackFieldParser _parser = DrugPackFieldParser();

  @override
  Future<DrugPackFieldCandidates?> lookup(String barcode) async {
    final String code = barcode.trim();
    if (code.isEmpty) {
      return null;
    }
    final Response<dynamic> response = await _dio.get<dynamic>(
      'https://world.openfoodfacts.org/api/v2/product/$code.json',
    );
    final Object? data = response.data;
    if (data is! Map) {
      return null;
    }
    if (data['status'] != 1) {
      return null;
    }
    final Object? product = data['product'];
    if (product is! Map) {
      return null;
    }
    final String name = _stringOf(product['product_name']).trim();
    final String brands = _stringOf(product['brands']).trim();
    final String quantity = _stringOf(product['quantity']).trim();
    final String categories = _stringOf(product['categories']).trim();
    final String raw = <String>[
      if (brands.isNotEmpty) brands.split(',').first.trim(),
      if (name.isNotEmpty) name,
      if (quantity.isNotEmpty) quantity,
      if (categories.isNotEmpty) categories,
    ].join('\n');
    if (raw.trim().isEmpty) {
      return null;
    }
    return _parser.parse(barcode: code, ocrText: raw).copyWithBarcode(code);
  }

  static String _stringOf(Object? value) {
    if (value == null) {
      return '';
    }
    return value.toString();
  }
}

/// openFDA label search by UPC when the barcode looks retail-length.
final class OpenFdaUpcDrugPackBarcodeLookup implements DrugPackBarcodeLookup {
  OpenFdaUpcDrugPackBarcodeLookup({Dio? dio})
    : _dio = dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
            ),
          );

  final Dio _dio;
  static const DrugPackFieldParser _parser = DrugPackFieldParser();

  @override
  Future<DrugPackFieldCandidates?> lookup(String barcode) async {
    final String code = barcode.trim();
    if (code.length < 8 || code.length > 14 || int.tryParse(code) == null) {
      return null;
    }
    final Response<dynamic> response = await _dio.get<dynamic>(
      'https://api.fda.gov/drug/label.json',
      queryParameters: <String, dynamic>{
        'search': 'openfda.upc:"$code"',
        'limit': 1,
      },
    );
    final Object? data = response.data;
    if (data is! Map) {
      return null;
    }
    final Object? results = data['results'];
    if (results is! List || results.isEmpty) {
      return null;
    }
    final Object? first = results.first;
    if (first is! Map) {
      return null;
    }
    final Object? openFda = first['openfda'];
    String brand = '';
    String generic = '';
    if (openFda is Map) {
      brand = _firstString(openFda['brand_name']);
      generic = _firstString(openFda['generic_name']);
    }
    final String raw = <String>[
      if (brand.isNotEmpty) brand,
      if (generic.isNotEmpty) generic,
    ].join('\n');
    if (raw.isEmpty) {
      return null;
    }
    return _parser.parse(barcode: code, ocrText: raw).copyWithBarcode(code);
  }

  static String _firstString(Object? value) {
    if (value is List && value.isNotEmpty) {
      return value.first.toString().trim();
    }
    if (value is String) {
      return value.trim();
    }
    return '';
  }
}

extension on DrugPackFieldCandidates {
  DrugPackFieldCandidates copyWithBarcode(String barcode) {
    return DrugPackFieldCandidates(
      brandName: brandName,
      genericName: genericName,
      form: form,
      strength: strength,
      code: code ?? barcode,
      batchNumber: batchNumber,
      expiryDate: expiryDate,
      manufacturedAt: manufacturedAt,
      barcode: barcode,
      rawText: rawText,
    );
  }
}

DrugPackBarcodeLookup createDefaultDrugPackBarcodeLookup() {
  return CompositeDrugPackBarcodeLookup(<DrugPackBarcodeLookup>[
    OpenFoodFactsDrugPackBarcodeLookup(),
    OpenFdaUpcDrugPackBarcodeLookup(),
  ]);
}
