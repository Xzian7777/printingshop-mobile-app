/// Mirrors the website order form's calculation using the shared base price.
double catalogTotal(
    {required String serviceId,
    required double basePrice,
    required int quantity,
    required int pages,
    double width = 0,
    double height = 0,
    double? photoPrice}) {
  switch (serviceId) {
    case 'tarpaulins':
      return basePrice * width * height * quantity;
    case 'booklets':
      return basePrice * quantity * pages / 4;
    case 'photoCanvas':
      return (photoPrice ?? basePrice) * quantity;
    case 'businessCards':
    case 'flyers':
    case 'stickers':
    case 'invitations':
    case 'shirt':
    case 'mug':
      return basePrice * quantity;
    default:
      return basePrice * pages * quantity;
  }
}
