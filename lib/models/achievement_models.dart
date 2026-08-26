class AchievementItem {
  final int id;
  final String? setName;
  final String platform;
  final String? store;
  final String name;
  final String? description;
  final String? imageUrl;
  final String? tier;
  final double? rarityPercent;
  bool unlocked;

  AchievementItem({
    required this.id,
    this.setName,
    required this.platform,
    this.store,
    required this.name,
    this.description,
    this.imageUrl,
    this.tier,
    this.rarityPercent,
    required this.unlocked,
  });

  factory AchievementItem.fromJson(Map<String, dynamic> json) {
    return AchievementItem(
      id: json['id'] ?? json['Id'],
      setName: json['setName'] ?? json['SetName'],
      platform: json['platform'] ?? json['Platform'] ?? 'General',
      store: json['store'] ?? json['Store'],
      name: json['name'] ?? json['Name'] ?? 'Logro',
      description: json['description'] ?? json['Description'],
      imageUrl: json['imageUrl'] ?? json['ImageUrl'],
      tier: json['tier'] ?? json['Tier'] ?? 'Logro',
      rarityPercent: (json['rarityPercent'] ?? json['RarityPercent'])?.toDouble(),
      unlocked: json['unlocked'] ?? json['Unlocked'] ?? false,
    );
  }
}

class GlobalAchievementItem {
  final int id;
  final int gameId;
  final String gameName;
  final String name;
  final String? description;
  final String? imageUrl;
  final String platform;
  final String? store;
  final String? tier;
  final double? rarityPercent;
  bool unlocked;

  GlobalAchievementItem({
    required this.id,
    required this.gameId,
    required this.gameName,
    required this.name,
    this.description,
    this.imageUrl,
    required this.platform,
    this.store,
    this.tier,
    this.rarityPercent,
    required this.unlocked,
  });

  factory GlobalAchievementItem.fromJson(Map<String, dynamic> json) {
    return GlobalAchievementItem(
      id: json['id'] ?? json['Id'],
      gameId: json['gameId'] ?? json['GameId'],
      gameName: json['gameName'] ?? json['GameName'] ?? '',
      name: json['name'] ?? json['Name'] ?? 'Logro',
      description: json['description'] ?? json['Description'],
      imageUrl: json['imageUrl'] ?? json['ImageUrl'],
      platform: json['platform'] ?? json['Platform'] ?? '',
      store: json['store'] ?? json['Store'],
      tier: json['tier'] ?? json['Tier'] ?? 'Logro',
      rarityPercent: (json['rarityPercent'] ?? json['RarityPercent'])?.toDouble(),
      unlocked: json['unlocked'] ?? json['Unlocked'] ?? false,
    );
  }
}