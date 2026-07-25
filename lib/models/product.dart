class Product {
  final int id;
  final String name;
  final int sizeMm;
  final int bundleLengthLm;
  final int stockQuantity;
  final double price;
  final List<String> imageUrls;

  Product({
    required this.id,
    required this.name,
    required this.sizeMm,
    required this.bundleLengthLm,
    required this.stockQuantity,
    required this.price,
    required this.imageUrls,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    List<String> images = [];
    if (json['all_images'] != null && json['all_images'].toString().isNotEmpty) {
      images = json['all_images'].toString().split(',');
    } else if (json['image_url'] != null) {
      images = [json['image_url']];
    }

    return Product(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      name: json['name'] ?? '',
      imageUrls: images,
      sizeMm: json['size_mm'] is int ? json['size_mm'] : int.parse(json['size_mm'].toString()),
      bundleLengthLm: json['bundle_length_lm'] is int ? json['bundle_length_lm'] : int.parse(json['bundle_length_lm'].toString()),
      stockQuantity: json['stock_quantity'] is int ? json['stock_quantity'] : int.parse(json['stock_quantity'].toString()),
      price: json['price'] is double ? json['price'] : double.parse(json['price'].toString()),
    );
  }
}