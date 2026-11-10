import 'package:flutter/material.dart';
import '../theme/dashboard_theme.dart';
import 'customer_order_card.dart' show orderAmount;
import '../services/store_price.dart';

class StoreProductCard extends StatelessWidget {
  final String name;
  final double price;
  final int stock;
  final Widget image;
  final bool admin;
  final VoidCallback onOpen;
  const StoreProductCard(
      {super.key,
      required this.name,
      required this.price,
      required this.stock,
      required this.image,
      required this.onOpen,
      this.admin = false});

  @override
  Widget build(BuildContext context) {
    final out = stock <= 0;
    final low = stock > 0 && stock <= 12;
    return Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFDCE5DF))),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        child: Stack(children: [
                      Positioned.fill(
                          child: Container(
                              decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F3),
                                  borderRadius: BorderRadius.circular(10)),
                              child: image)),
                      Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 4),
                              decoration: BoxDecoration(
                                  color: out
                                      ? const Color(0xFFFFF1F2)
                                      : low
                                          ? const Color(0xFFFEF3C7)
                                          : const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(7)),
                              child: Text(
                                  out
                                      ? 'Out of Stock'
                                      : low
                                          ? 'Low Stock'
                                          : 'In Stock',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: out
                                          ? const Color(0xFF9F1239)
                                          : low
                                              ? const Color(0xFF92400E)
                                              : DashboardTheme.green)))),
                    ])),
                    const SizedBox(height: 10),
                    Text(name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: DashboardTheme.ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('${out ? 0 : stock} available',
                        style: const TextStyle(
                            color: DashboardTheme.muted, fontSize: 12)),
                    const SizedBox(height: 4),
                    FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                            storePrice(price) == null
                                ? 'Price unavailable'
                                : orderAmount(price),
                            style: const TextStyle(
                                color: DashboardTheme.ink,
                                fontSize: 17,
                                fontWeight: FontWeight.w800))),
                    if (admin) const SizedBox(height: 10),
                    if (admin)
                      SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                              onPressed: onOpen,
                              child: const Text('Edit / Restock')))
                  ]),
            )));
  }
}
