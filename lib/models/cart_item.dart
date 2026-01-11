import 'product.dart';

class CartItem {
  final Product product;
  String name;
  double price;
  int quantity;
  String unit;
  double discountPercent;

  CartItem({
    required this.product,
    required this.quantity,
    required this.unit,
    String? name,
    double? price,
    this.discountPercent = 0.0,
  }) : name = name ?? product.name,
       price = price ?? product.price.toDouble();

  double get totalPrice {
    double baseTotal = price * quantity;
    return baseTotal - (baseTotal * (discountPercent / 100));
  }
}
