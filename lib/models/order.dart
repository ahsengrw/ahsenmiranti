class Order {
  final int id;
  final double totalAmount;
  final String status;
  final String? customerName;
  final String? customerAddress;
  final String? paymentMethod;
  final String createdAt;
  final int? driverId;
  final String? driverName;
  final String? driverVan;
  final bool driverVerified;
  final String? driverImage;
  final double? deliveryLat;
  final double? deliveryLng;
  final double? driverLat;
  final double? driverLng;
  final bool isExpress;
  final bool outsideAma;
  final String? itemsSummary;
  final String? codNote;

  Order({
    required this.id,
    required this.totalAmount,
    required this.status,
    this.customerName,
    this.customerAddress,
    this.paymentMethod,
    required this.createdAt,
    this.driverId,
    this.driverName,
    this.driverVan,
    this.driverVerified = false,
    this.driverImage,
    this.deliveryLat,
    this.deliveryLng,
    this.driverLat,
    this.driverLng,
    this.isExpress = false,
    this.outsideAma = false,
    this.itemsSummary,
    this.codNote,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      totalAmount: json['total_amount'] is double ? json['total_amount'] : double.parse(json['total_amount'].toString()),
      status: json['status'] ?? 'pending',
      customerName: json['customer_name'],
      customerAddress: json['customer_address'],
      paymentMethod: json['payment_method'],
      codNote: json['cod_note'],
      createdAt: json['created_at'] ?? '',
      driverId: json['driver_id'] != null ? int.parse(json['driver_id'].toString()) : null,
      driverName: json['driver_name'],
      driverVan: json['driver_van'],
      driverVerified: json['driver_verified'] == 1 || json['driver_verified'] == true,
      driverImage: json['driver_image'],
      deliveryLat: json['delivery_lat'] != null ? double.parse(json['delivery_lat'].toString()) : null,
      deliveryLng: json['delivery_lng'] != null ? double.parse(json['delivery_lng'].toString()) : null,
      driverLat: json['driver_lat'] != null ? double.parse(json['driver_lat'].toString()) : null,
      driverLng: json['driver_lng'] != null ? double.parse(json['driver_lng'].toString()) : null,
      isExpress: json['is_express'] == 1 || json['is_express'] == true,
      outsideAma: json['outside_ama'] == 1 || json['outside_ama'] == true,
      itemsSummary: json['items_summary'],
    );
  }
}
