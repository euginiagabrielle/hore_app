class PriceCalculator {
  static double getFinalPrice(Map<String, dynamic> product) {
    final double originalPrice = (product['product_price'] as num).toDouble();

    if (product['discounts'] != null && product['discounts']['is_discount_active'] == true) {
      final double discountNominal = (product['discounts']['discount_value'] as num).toDouble();

      double finalPrice = originalPrice - discountNominal;
      return finalPrice < 0 ? 0 : finalPrice;
    }
    return originalPrice;
  }

  static bool hasActiveDiscount(Map<String, dynamic> product) {
    return product['discounts'] != null && product['discounts']['is_discount_active'] == true;
  }
}