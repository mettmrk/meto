enum GiftCategory { love, thanks, greeting, premium }

enum Currency { diamonds, meto, gold }

class Gift {
  final String id;
  final String name;
  final String icon; // Icon name or emoji (backup)
  final String? image; // Optional image URL
  final String? lottieUrl; // URL for animated gifts (SVGA or Lottie)
  final int price;
  final GiftCategory category;
  final Currency currency;

  const Gift({
    required this.id,
    required this.name,
    required this.icon,
    this.image,
    this.lottieUrl,
    required this.price,
    this.category = GiftCategory.premium,
    this.currency = Currency.diamonds,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'image': image,
      'lottieUrl': lottieUrl,
      'price': price,
      'category': category.index,
      'currency': currency.name,
    };
  }

  factory Gift.fromMap(Map<String, dynamic> map) {
    int catIndex = 0;
    if (map['category'] != null) {
      catIndex = int.tryParse(map['category'].toString()) ?? 0;
    }
    if (catIndex < 0 || catIndex >= GiftCategory.values.length) {
      catIndex = 0;
    }

    Currency currency = Currency.diamonds;
    if (map['currency'] != null) {
      final currencyStr = map['currency'].toString();
      if (currencyStr == 'meto' || currencyStr == 'coins') {
        currency = Currency.meto;
      } else if (currencyStr == 'gold') {
        currency = Currency.gold;
      }
    }

    return Gift(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'هدية بدون اسم',
      icon: map['icon']?.toString() ?? '🎁',
      image: map['image']?.toString(),
      lottieUrl: map['lottieUrl']?.toString(),
      price: int.tryParse(map['price']?.toString() ?? '0') ?? 0,
      category: GiftCategory.values[catIndex],
      currency: currency,
    );
  }
}

const List<Gift> predefinedGifts = [
  // --- Category: Thanks ---
  Gift(
    id: 'gift_svga_rose_thanks',
    name: 'وردة الثناء',
    icon: '🌹',
    image: 'https://img.icons8.com/color/96/rose.png',
    lottieUrl:
        'https://cdn.jsdelivr.net/gh/yyued/SVGA-Samples@master/rose.svga',
    price: 300,
    category: GiftCategory.thanks,
  ),

  // --- Category: Premium (مؤثرات - SVGA Gallery) ---
  Gift(
    id: 'gift_svga_ferrari_red',
    name: 'سيارة فيراري الرياضية',
    icon: '🏎️',
    image: 'https://img.icons8.com/color/96/car.png',
    lottieUrl:
        'https://cdn.jsdelivr.net/gh/yyued/SVGA-Samples@master/posche.svga',
    price: 15000,
    category: GiftCategory.premium,
  ),

  Gift(
    id: 'gift_svga_crown_legend',
    name: 'التاج الأسطوري',
    icon: '👑',
    image: 'https://img.icons8.com/color/96/crown.png',
    lottieUrl:
        'https://cdn.jsdelivr.net/gh/yyued/SVGA-Samples@master/kingset.svga',
    price: 18000,
    category: GiftCategory.premium,
  ),

  Gift(
    id: 'gift_svga_empty_state',
    name: 'الهدية الهادئة',
    icon: '✨',
    image: 'https://img.icons8.com/color/96/sparkling.png',
    lottieUrl:
        'https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/EmptyState.svga',
    price: 1200,
    category: GiftCategory.premium,
  ),
  Gift(
    id: 'gift_svga_hamburger_arrow',
    name: 'سهم الانتقال',
    icon: '➡️',
    image: 'https://img.icons8.com/color/96/right.png',
    lottieUrl:
        'https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/HamburgerArrow.svga',
    price: 1500,
    category: GiftCategory.premium,
  ),
  Gift(
    id: 'gift_svga_pin_jump',
    name: 'قفزة المرح',
    icon: '📍',
    image: 'https://img.icons8.com/color/96/marker.png',
    lottieUrl:
        'https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/PinJump.svga',
    price: 2000,
    category: GiftCategory.premium,
  ),
  Gift(
    id: 'gift_svga_walkthrough',
    name: 'مرشد الأحلام',
    icon: '🗺️',
    image: 'https://img.icons8.com/color/96/map.png',
    lottieUrl:
        'https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/Walkthrough.svga',
    price: 3500,
    category: GiftCategory.premium,
  ),
  Gift(
    id: 'gift_svga_halloween_special',
    name: 'رعب الهالوين',
    icon: '🎃',
    image: 'https://img.icons8.com/color/96/pumpkin.png',
    lottieUrl:
        'https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/halloween.svga',
    price: 8000,
    category: GiftCategory.premium,
  ),

  Gift(
    id: 'gift_lottie_lionjump',
    name: 'قفزة الأسد',
    icon: '🦁',
    image: 'https://img.icons8.com/color/96/lion.png',
    lottieUrl: 'assets/lottie/lionjump.json',
    price: 60000, // Price it as a premium effect
    category: GiftCategory.premium,
  ),
];
