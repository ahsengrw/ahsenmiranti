class User {
  final int id;
  final String name;
  final String email;
  final String role;
  final String? phone;
  final String? address;
  final double? lat;
  final double? lng;
  final String? vanNumber;
  final bool isVerified;
  final String? profileImage;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.address,
    this.lat,
    this.lng,
    this.vanNumber,
    this.isVerified = false,
    this.profileImage,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'customer',
      phone: json['phone'],
      address: json['address'],
      lat: json['lat'] != null ? double.parse(json['lat'].toString()) : null,
      lng: json['lng'] != null ? double.parse(json['lng'].toString()) : null,
      vanNumber: json['van_number'],
      isVerified: (json['is_verified'] == 1 || json['is_verified'] == true),
      profileImage: json['profile_image'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'phone': phone,
      'address': address,
      'lat': lat,
      'lng': lng,
      'van_number': vanNumber,
      'is_verified': isVerified ? 1 : 0,
      'profile_image': profileImage,
    };
  }
}
