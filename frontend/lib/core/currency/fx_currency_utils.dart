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
  final String fixed = value.toStringAsFixed(digits);
  final List<String> parts = fixed.split('.');
  final String groupedInteger = _groupIntegerWithCommas(parts.first);
  if (parts.length == 2 && digits > 0) {
    return '$groupedInteger.${parts.last}';
  }
  return groupedInteger;
}

String _groupIntegerWithCommas(String value) {
  if (value.length <= 3) {
    return value;
  }

  final StringBuffer buffer = StringBuffer();
  for (int index = 0; index < value.length; index += 1) {
    final int remaining = value.length - index;
    buffer.write(value[index]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}
