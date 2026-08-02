/// Tracks which create-form fields still need staff confirmation after scan/OCR.
final class AppSuggestedFieldSet {
  AppSuggestedFieldSet([Iterable<String> keys = const <String>[]])
    : _pending = Set<String>.from(keys);

  final Set<String> _pending;

  bool get hasPending => _pending.isNotEmpty;

  int get pendingCount => _pending.length;

  bool isSuggested(String key) => _pending.contains(key);

  void markAll(Iterable<String> keys) {
    _pending
      ..clear()
      ..addAll(keys.where((String key) => key.trim().isNotEmpty));
  }

  void accept(String key) {
    _pending.remove(key);
  }

  void acceptAll() {
    _pending.clear();
  }

  /// Edit clears suggested state so the staff-owned value is no longer highlighted.
  void edit(String key) {
    _pending.remove(key);
  }

  Set<String> get pendingKeys => Set<String>.unmodifiable(_pending);
}

/// Field keys used by pharmacy drug create scan prefill.
abstract final class PharmacyDrugSuggestedFields {
  static const String brandName = 'brand_name';
  static const String genericName = 'generic_name';
  static const String code = 'code';
  static const String form = 'form';
  static const String strength = 'strength';
  static const String batchNumber = 'batch_number';
  static const String manufacturedAt = 'manufactured_at';
  static const String expiryDate = 'expiry_date';
}
