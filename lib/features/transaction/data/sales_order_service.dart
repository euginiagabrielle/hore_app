import '../../../core/utils/price_calculator.dart';

class SalesOrderService {
  // Singleton pattern, so the order state will endure as long as the app is running
  static final SalesOrderService _instance = SalesOrderService._internal();
  factory SalesOrderService() => _instance;
  SalesOrderService._internal();

  // Keep order product list { product_id: { data_produk, quantity }}
  final Map<int, Map<String, dynamic>> _currentOrderItems = {};
  List<Map<String, dynamic>> get currentItems => _currentOrderItems.values.toList();

  // Current total price
  double get totalPrice  {
    double total = 0;
    for (var item in _currentOrderItems.values) {
      // final price = (item['product']['product_price'] as num).toDouble();
      // final qty = item['quantity'] as int;
      // total += (price * qty);
      total += item['subtotal'];
    }
    return total;
  }

  // Item qty total
  int get totalItemCount {
    int count = 0;
    for (var item in _currentOrderItems.values) {
      count += item['quantity'] as int;
    }
    return count;
  }

  int? currentEmployeeId;
  String? currentEmployeeName;
  int? currentCustomerId;
  String? currentCustomerName;
  String? currentCustomerPhone;

  // Set data kasir
  void setEmployee(int id, String name) {
    currentEmployeeId = id;
    currentEmployeeName = name;
  }

  // Set data pelanggan
  void setCustomer(int? id, String? name, String? phone) {
    currentCustomerId = id;
    currentCustomerName = name;
    currentCustomerPhone = phone;
  }

  // Add item to order
  void addItem(Map<String, dynamic> product, {int quantity = 1}) {
    final int productId = product['product_id'];

    final double originalPrice = (product['product_price'] as num).toDouble();
    final double finalPrice = PriceCalculator.getFinalPrice(product);
    final bool isDiscounted = PriceCalculator.hasActiveDiscount(product);

    final double discountAmount = isDiscounted ? (originalPrice - finalPrice) : 0.0;

    if (_currentOrderItems.containsKey(productId))  {
      // if the product is already in the list, increase quantity
      _currentOrderItems[productId]!['quantity'] += quantity;
      _currentOrderItems[productId]!['subtotal'] = _currentOrderItems[productId]!['quantity'] * finalPrice;
    } else {
      // if the product is not in the list, add as new item
      _currentOrderItems[productId] = {
        'product': product,
        'quantity': quantity,
        'original_price': originalPrice,
        'price': finalPrice,
        'discount_id': isDiscounted ? product['discounts']['discount_id'] : null,
        'discount_amount': discountAmount,
        'subtotal': finalPrice * quantity,
      };
    }
  }

  // Remove item from order
  void removeItem(int productId) {
    if (_currentOrderItems.containsKey(productId)) {
      if (_currentOrderItems[productId]!['quantity'] > 1) {
        _currentOrderItems[productId]!['quantity'] -= 1;

        final double currentPrice = _currentOrderItems[productId]!['price'];
        _currentOrderItems[productId]!['subtotal'] = _currentOrderItems[productId]!['quantity'] * currentPrice;
      } else {
        _currentOrderItems.remove(productId);
      }
    }
  }

  // Empty order (after send to cashier/cancel)
  void clearOrder() {
    _currentOrderItems.clear();
    currentCustomerId = null;
    currentCustomerName = null;
  }
}