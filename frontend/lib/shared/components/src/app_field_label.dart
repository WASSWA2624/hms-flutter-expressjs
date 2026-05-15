String? appFieldLabel(String? label, {required bool isRequired}) {
  if (label == null || label.isEmpty || !isRequired) {
    return label;
  }

  return '$label *';
}
