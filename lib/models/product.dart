class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String location;
  final String? imageId;
  final String profileId;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.location,
    this.imageId,
    required this.profileId,
  });

  factory Product.fromMap(Map<String, dynamic> map, String id) {
    return Product(
      id: id,
      name: map['name'],
      description: map['description'],
      price: (map['price'] as num).toDouble(),
      location: map['location'],
      imageId: map['imageId'],
      profileId: map['profile_id'],
    );
  }
}
