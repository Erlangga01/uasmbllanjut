class TransactionItem {
  final int productId;
  final int quantity;
  final String? name;
  final String? unit;
  final double? price;
  final double? totalPrice;
  final double discountPercent;

  TransactionItem({
    required this.productId,
    required this.quantity,
    this.name,
    this.unit,
    this.price,
    this.totalPrice,
    this.discountPercent = 0.0,
  });

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'quantity': quantity,
      'name': name,
      'satuan': unit ?? 'unit',
      'price': price,
      'total_price': totalPrice,
      'discount_percent': discountPercent,
    };
  }
}

class CreateTransactionDto {
  final String customerName;
  final String transactionDate;
  final double subTotal;
  final double vat;
  final List<TransactionItem> items;

  CreateTransactionDto({
    required this.customerName,
    required this.transactionDate,
    required this.subTotal,
    required this.items,
    this.vat = 10.0,
  });

  Map<String, dynamic> toJson() {
    return {
      'customer_name': customerName,
      'transaction_date': transactionDate,
      'grand_totalnya': subTotal,
      'tax':
          vat, // Sending as 'tax' (percent) or calculated amount? Usually API expects amount or rate. Assuming rate here based on user request "Global VAT".
      // Note: If API expects tax amount, I should calculate it. I'll stick to 'tax' key carrying percentage for now, or 'tax_percent'.
      // Let's assume standard field is 'tax' for percentage or 'tax_amount'.
      // The user just said "Global VAT (in percent)".
      // I will send 'tax' as the percentage value (e.g., 10).
      'items': items.map((i) => i.toJson()).toList(),
    };
  }
}

class TransactionDetailResponse {
  final int id;
  final int productId;
  final int quantity;
  final double price;
  final String productName;
  final String unit;
  final double discountPercent;
  final double totalPrice;

  TransactionDetailResponse({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.price,
    required this.productName,
    this.unit = '',
    this.discountPercent = 0.0,
    this.totalPrice = 0.0,
  });

  factory TransactionDetailResponse.fromJson(Map<String, dynamic> json) {
    return TransactionDetailResponse(
      id: json['id'] ?? 0,
      productId: json['product_id'] ?? 0,
      quantity: json['quantity'] ?? 0,
      price: double.tryParse((json['price'] ?? 0).toString()) ?? 0.0,
      productName:
          json['name'] ??
          ((json['product'] != null && json['product'] is Map)
              ? json['product']['name']
              : 'Unknown Product'),
      unit: json['satuan'] ?? '',
      discountPercent:
          double.tryParse((json['discount_percent'] ?? 0).toString()) ?? 0.0,
      totalPrice:
          double.tryParse(
            (json['total_price'] ?? json['subtotal'] ?? 0).toString(),
          ) ??
          0.0,
    );
  }

  @override
  String toString() {
    return 'TransactionDetailResponse(id: $id, product: $productName, unit: $unit, qty: $quantity, price: $price, disc: $discountPercent)';
  }
}

class TransactionResponse {
  final int id;
  final String customerName;
  final String transactionDate;
  final double totalAmount;
  final DateTime createdAt;
  final double
  tax; // Global VAT Percent or Amount? Assuming we receive 'tax' field from API which holds the percent or amount.
  // Based on previous step, we sent 'tax' as percent.
  // Ideally the API response should provide either tax_amount or calc data.
  // I will assume the API echoes back 'tax' (percent) or I can infer it.
  // Actually, usually in these systems, Total Amount is Grand Total.
  // If I want to reverse calc or if API provides it.
  // Let's add 'tax' field to response mapping.
  final List<TransactionDetailResponse> items;

  TransactionResponse({
    required this.id,
    required this.customerName,
    required this.transactionDate,
    required this.totalAmount,
    required this.createdAt,
    required this.items,
    this.tax = 0.0,
  });

  factory TransactionResponse.fromJson(Map<String, dynamic> json) {
    // Robustly check for relationship data under common keys used in Laravel
    var rawList =
        json['details'] ?? json['items'] ?? json['transaction_details'];
    var list = (rawList is List) ? rawList : [];
    List<TransactionDetailResponse> itemsList =
        list.map((i) => TransactionDetailResponse.fromJson(i)).toList();

    return TransactionResponse(
      id: json['id'] ?? 0,
      customerName: json['customer_name'] ?? 'Unknown',
      transactionDate: json['transaction_date'] ?? '',
      totalAmount:
          double.tryParse(
            (json['total_amount'] ?? json['grand_totalnya'] ?? 0).toString(),
          ) ??
          0.0,
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : DateTime.now(),
      tax: double.tryParse((json['tax'] ?? 0).toString()) ?? 0.0,
      items: itemsList,
    );
  }

  @override
  String toString() {
    return 'TransactionResponse(id: $id, customer: $customerName, total: $totalAmount, tax: $tax, items: $items)';
  }
}
