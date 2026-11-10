/// Compatibility labels stored by earlier application versions.
String systemDisplayText(dynamic value) {
  const labels = {
    'Walang napiling file': 'No file selected',
    'Walang in-attach na file': 'No file attached',
  };
  final text = value?.toString() ?? '';
  return labels[text] ?? text;
}
