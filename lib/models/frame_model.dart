class ProfileFrame {
  final String id;
  final String name;
  final String asset; // Local asset path
  final String? image; // Remote image URL
  final String? lottieUrl; // URL for animated frames
  final int price;
  final String color;
  final bool isAnimated;
  final String category; // 'static', 'animated', 'sticker'

  const ProfileFrame({
    required this.id,
    required this.name,
    required this.asset,
    this.image,
    this.lottieUrl,
    this.price = 99,
    this.color = 'gold',
    this.isAnimated = false,
    this.category = 'static',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'asset': asset,
      'image': image,
      'lottieUrl': lottieUrl,
      'price': price,
      'color': color,
      'isAnimated': isAnimated,
      'category': category,
    };
  }

  factory ProfileFrame.fromMap(Map<String, dynamic> map, String docId) {
    return ProfileFrame(
      id: map['id']?.toString() ?? docId,
      name: map['name']?.toString() ?? 'إطار بدون اسم',
      asset: map['asset']?.toString() ?? '',
      image: map['image']?.toString(),
      lottieUrl: map['lottieUrl']?.toString(),
      price: int.tryParse(map['price']?.toString() ?? '99') ?? 99,
      color: map['color']?.toString() ?? 'gold',
      isAnimated: map['isAnimated'] ?? (map['lottieUrl'] != null),
      category: map['category']?.toString() ?? 'static',
    );
  }
}

// Default list based on existing hardcoded frames
final List<ProfileFrame> predefinedFrames = [
  ProfileFrame(
    id: 'frame_3',
    name: 'تاج الإمبراطور',
    color: 'gold',
    asset: 'assets/images/frame_gold_crown.png',
  ),
  ProfileFrame(
    id: 'frame_2',
    name: 'الماس السماوي',
    color: 'blue',
    asset: 'assets/images/frame_silver_sapphire.png',
  ),
  ProfileFrame(
    id: 'frame_1',
    name: 'القبلية البرونزية',
    color: 'bronze',
    asset: 'assets/images/frame_bronze_tribal.png',
  ),
  // Etar Frames are temporarily removed until the assets are provided
];
