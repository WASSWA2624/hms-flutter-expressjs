const String subscriptionPlanBaseCurrencyCode = 'USD';

const Set<String> _zeroDecimalCurrencies = <String>{
  'BIF',
  'CLP',
  'DJF',
  'GNF',
  'ISK',
  'JPY',
  'KES',
  'KMF',
  'KRW',
  'PYG',
  'RWF',
  'UGX',
  'TZS',
  'VND',
  'VUV',
  'XAF',
  'XOF',
  'XPF',
  'ZMW',
};

int decimalDigitsForCurrency(String currencyCode) {
  final String normalized = currencyCode.trim().toUpperCase();
  if (_zeroDecimalCurrencies.contains(normalized)) {
    return 0;
  }
  return 2;
}

double roundConvertedAmount(double value, String currencyCode) {
  final int digits = decimalDigitsForCurrency(currencyCode);
  if (digits == 0) {
    return value.roundToDouble();
  }
  const double factor = 100;
  return (value * factor).roundToDouble() / factor;
}

String formatConvertedAmount(double value, String currencyCode) {
  final int digits = decimalDigitsForCurrency(currencyCode);
  return value.toStringAsFixed(digits);
}
