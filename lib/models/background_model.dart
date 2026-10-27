class RoomBackground {
  final String id;
  final String name;
  final String image; // URL or Asset path
  final String? lottieUrl;
  final int price;
  final bool isPremium;
  final bool isNew;

  const RoomBackground({
    required this.id,
    required this.name,
    required this.image,
    this.lottieUrl,
    this.price = 0,
    this.isPremium = false,
    this.isNew = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'image': image,
      'lottieUrl': lottieUrl,
      'price': price,
      'isPremium': isPremium,
      'isNew': isNew,
    };
  }

  factory RoomBackground.fromMap(Map<String, dynamic> map, String id) {
    return RoomBackground(
      id: id,
      name: map['name']?.toString() ?? 'خلفية بدون اسم',
      image: map['image']?.toString() ?? map['imageUrl']?.toString() ?? '',
      lottieUrl: map['lottieUrl']?.toString(),
      price: int.tryParse(map['price']?.toString() ?? '0') ?? 0,
      isPremium: map['isPremium'] ?? false,
      isNew: map['isNew'] ?? false,
    );
  }
}

// Initial defaults
final List<RoomBackground> predefinedBackgrounds = [
  const RoomBackground(
    id: 'default_cosmic',
    name: 'الكون العميق',
    image: 'default',
    price: 0,
  ),
  const RoomBackground(
    id: 'royal_oasis',
    name: 'الواحة الملكية',
    image: 'default',
    price: 0,
    isNew: true,
  ),
  const RoomBackground(
    id: 'crystal_glow',
    name: 'بريق الكريستال',
    image: 'default',
    price: 0,
    isNew: true,
  ),
  const RoomBackground(
    id: 'royal_horizon',
    name: 'الأفق الملكي',
    image: 'default',
    price: 0,
    isNew: true,
  ),
];
