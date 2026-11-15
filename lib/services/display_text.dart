/// Compatibility labels stored by earlier application versions.
String orderStatusLabel(dynamic value) {
  final status = value?.toString().trim() ?? 'Order Submitted';
  return const {'printing', 'preparing', 'processing'}
          .contains(status.toLowerCase())
      ? 'Processing'
      : status;
}

bool isProcessingOrderStatus(dynamic value) => const {
      'approved',
      'printing',
      'preparing',
      'processing'
    }.contains(value?.toString().trim().toLowerCase());

bool isStoppedOrderStatus(dynamic value) =>
    RegExp('cancel|reject', caseSensitive: false).hasMatch('$value');

String systemDisplayText(dynamic value) {
  const labels = {
    'Walang napiling file': 'No file selected',
    'Walang in-attach na file': 'No file attached',
  };
  final text = value?.toString() ?? '';
  return labels[text] ?? text;
}
