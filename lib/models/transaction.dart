class TransactionItem {
  final int productId;
  final int quantity;

  TransactionItem({required this.productId, required this.quantity});

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'quantity': quantity,
    };
  }
}

class CreateTransactionDto {
  final String customerName;
  final String transactionDate;
  final List<TransactionItem> items;

  CreateTransactionDto({
    required this.customerName,
    required this.transactionDate,
    required this.items,
  });

  Map<String, dynamic> toJson() {
    return {
      'customer_name': customerName,
      'transaction_date': transactionDate,
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

  TransactionDetailResponse({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.price,
    required this.productName,
  });

  factory TransactionDetailResponse.fromJson(Map<String, dynamic> json) {
    return TransactionDetailResponse(
      id: json['id'] ?? 0,
      productId: json['product_id'] ?? 0,
      quantity: json['quantity'] ?? 0,
      price: double.tryParse((json['price'] ?? 0).toString()) ?? 0.0,
      productName: (json['product'] != null && json['product'] is Map) ? json['product']['name'] : 'Unknown Product',
    );
  }

  @override
  String toString() {
    return 'TransactionDetailResponse(id: $id, product: $productName, qty: $quantity, price: $price)';
  }
}

class TransactionResponse {
  final int id;
  final String customerName;
  final String transactionDate;
  final double totalAmount;
  final DateTime createdAt;
  final List<TransactionDetailResponse> items;

  TransactionResponse({
    required this.id,
    required this.customerName,
    required this.transactionDate,
    required this.totalAmount,
    required this.createdAt,
    required this.items,
  });

  factory TransactionResponse.fromJson(Map<String, dynamic> json) {
    // Robustly check for relationship data under common keys used in Laravel
    var rawList = json['details'] ?? json['items'] ?? json['transaction_details'];
    var list = (rawList is List) ? rawList : [];
    List<TransactionDetailResponse> itemsList = list.map((i) => TransactionDetailResponse.fromJson(i)).toList();

    return TransactionResponse(
      id: json['id'] ?? 0,
      customerName: json['customer_name'] ?? 'Unknown',
      transactionDate: json['transaction_date'] ?? '',
      totalAmount: double.tryParse((json['total_amount'] ?? 0).toString()) ?? 0.0,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      items: itemsList,
    );
  }

  @override
  String toString() {
    return 'TransactionResponse(id: $id, customer: $customerName, total: $totalAmount, items: $items)';
  }
}
