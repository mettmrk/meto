
class RoomTier {
  final int level;
  final int cost;
  final int maxMembers;
  final int maxModerators;
  final int maxCoOwners;
  final int seats;
  final String title;

  const RoomTier({
    required this.level,
    required this.cost,
    required this.maxMembers,
    required this.maxModerators,
    required this.maxCoOwners,
    required this.seats,
    required this.title,
  });
}

class RoomTierSystem {
  static const List<RoomTier> tiers = [
    RoomTier(
      level: 0,
      cost: 0,
      maxMembers: 20,
      maxModerators: 1,
      maxCoOwners: 0,
      seats: 5,
      title: 'المستوى الأساسي',
    ),
    RoomTier(
      level: 1,
      cost: 150000,
      maxMembers: 70,
      maxModerators: 3,
      maxCoOwners: 0,
      seats: 5,
      title: 'متفوق',
    ),
    RoomTier(
      level: 2,
      cost: 250000,
      maxMembers: 150,
      maxModerators: 4,
      maxCoOwners: 0,
      seats: 5,
      title: 'فاخر',
    ),
    RoomTier(
      level: 3,
      cost: 350000, // Estimated
      maxMembers: 250,
      maxModerators: 4,
      maxCoOwners: 1,
      seats: 5,
      title: 'مميز',
    ),
    RoomTier(
      level: 4,
      cost: 400000,
      maxMembers: 500,
      maxModerators: 6,
      maxCoOwners: 2,
      seats: 5,
      title: 'ملكي',
    ),
    RoomTier(
      level: 5,
      cost: 600000,
      maxMembers: 1000,
      maxModerators: 7,
      maxCoOwners: 3,
      seats: 5,
      title: 'أسطوري',
    ),
  ];

  static RoomTier getTier(int level) {
    if (level < 0) return tiers[0];
    if (level >= tiers.length) return tiers.last;
    return tiers[level];
  }
}
