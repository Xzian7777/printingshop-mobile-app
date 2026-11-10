/// Place Order limits shared with the website's submit checks and Flask API.
class OrderValidation {
  static String? validatePayment(String method, String reference) {
    final normalized = method.toLowerCase().trim();
    if (!['gcash', 'gcash online', 'cash on pickup'].contains(normalized)) {
      return 'Choose GCash or Cash on Pickup.';
    }
    if (normalized.contains('gcash') &&
        !RegExp(r'^[0-9]{8,16}$').hasMatch(reference.trim())) {
      return 'Enter a valid GCash reference number (8–16 digits, usually 13).';
    }
    return null;
  }

  static String? validate({
    required String quantity,
    required String pages,
    required bool usesPages,
    required bool isTarpaulin,
    required String width,
    required String height,
    required double total,
    required String paymentMethod,
    required String gcashReference,
    required String note,
  }) {
    final qty = int.tryParse(quantity.trim());
    if (!RegExp(r'^[0-9]+$').hasMatch(quantity.trim()) ||
        qty == null ||
        qty <= 0 ||
        qty > 100000) {
      return 'Quantity must be a whole number from 1 to 100,000.';
    }
    if (usesPages) {
      final pageCount = int.tryParse(pages.trim());
      if (!RegExp(r'^[0-9]+$').hasMatch(pages.trim()) ||
          pageCount == null ||
          pageCount <= 0 ||
          pageCount > 5000) {
        return 'Pages must be a whole number from 1 to 5,000.';
      }
    }
    if (isTarpaulin) {
      for (final dimension in {'Width': width, 'Height': height}.entries) {
        final value = double.tryParse(dimension.value.trim());
        if (value == null || !value.isFinite || value <= 0 || value > 100) {
          return '${dimension.key} must be greater than 0 and at most 100 feet.';
        }
      }
    }
    if (!total.isFinite || total <= 0 || total > 5000000) {
      return 'Order total must be greater than ₱0 and at most ₱5,000,000.';
    }
    final paymentError = validatePayment(paymentMethod, gcashReference);
    if (paymentError != null) return paymentError;
    if (note.trim().runes.length > 500) {
      return 'Special instructions must not exceed 500 characters.';
    }
    return null;
  }
}
