class Product {
  final int id;
  final String name;
  final double price;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ProductMaterial> materials;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.createdAt,
    required this.updatedAt,
    required this.materials,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['name'],
      price: double.tryParse(json['price'].toString()) ?? 0.0,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      materials: (json['materials'] as List? ?? [])
          .map((i) => ProductMaterial.fromJson(i))
          .toList(),
    );
  }
}

class ProductMaterial {
  final int id;
  final String name;
  final double stock;
  final double quantityNeeded;

  ProductMaterial({
    required this.id,
    required this.name,
    required this.stock,
    required this.quantityNeeded,
  });

  factory ProductMaterial.fromJson(Map<String, dynamic> json) {
    return ProductMaterial(
      id: json['id'],
      name: json['name'],
      stock: double.tryParse(json['stock'].toString()) ?? 0.0,
      quantityNeeded: json['pivot'] != null 
        ? (double.tryParse(json['pivot']['quantity_needed'].toString()) ?? 0.0)
        : 0.0,
    );
  }
}
