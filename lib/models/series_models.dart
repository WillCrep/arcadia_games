class SeriesSummary {
  final int id;
  final String name;
  final int? igdbId;
  final int totalGames;
  final int ownedGames;
  final int completedGames;
  final double completionPercent;

  SeriesSummary({
    required this.id,
    required this.name,
    this.igdbId,
    required this.totalGames,
    required this.ownedGames,
    required this.completedGames,
    required this.completionPercent,
  });

  factory SeriesSummary.fromJson(Map<String, dynamic> json) {
    return SeriesSummary(
      id: json['id'] ?? json['Id'],
      name: json['name'] ?? json['Name'] ?? 'Serie',
      igdbId: json['igdbId'] ?? json['IgdbId'],
      totalGames: json['totalGames'] ?? json['TotalGames'] ?? 0,
      ownedGames: json['ownedGames'] ?? json['OwnedGames'] ?? 0,
      completedGames: json['completedGames'] ?? json['CompletedGames'] ?? 0,
      completionPercent: (json['completionPercent'] ?? json['CompletionPercent'] ?? 0).toDouble(),
    );
  }
}

class SeriesDetail {
  final int id;
  final String name;
  final int totalGames;
  final int ownedGames;
  final int completedGames;
  final double completionPercent;
  final List<SeriesGameItem> games;

  SeriesDetail({
    required this.id,
    required this.name,
    required this.totalGames,
    required this.ownedGames,
    required this.completedGames,
    required this.completionPercent,
    required this.games,
  });

  factory SeriesDetail.fromJson(Map<String, dynamic> json) {
    return SeriesDetail(
      id: json['id'] ?? json['Id'],
      name: json['name'] ?? json['Name'] ?? 'Serie',
      totalGames: json['totalGames'] ?? json['TotalGames'] ?? 0,
      ownedGames: json['ownedGames'] ?? json['OwnedGames'] ?? 0,
      completedGames: json['completedGames'] ?? json['CompletedGames'] ?? 0,
      completionPercent: (json['completionPercent'] ?? json['CompletionPercent'] ?? 0).toDouble(),
      games: (json['games'] as List? ?? json['Games'] as List? ?? [])
          .map((x) => SeriesGameItem.fromJson(x))
          .toList(),
    );
  }
}

class SeriesGameItem {
  final int id;
  final String name;
  final String? coverUrl;
  final String status;
  final bool owned;

  SeriesGameItem({
    required this.id,
    required this.name,
    this.coverUrl,
    required this.status,
    required this.owned,
  });

  factory SeriesGameItem.fromJson(Map<String, dynamic> json) {
    return SeriesGameItem(
      id: json['id'] ?? json['Id'] ?? 0,
      name: json['name'] ?? json['Name'] ?? 'Juego',
      coverUrl: json['coverUrl'] ?? json['CoverUrl'],
      status: json['status'] ?? json['Status'] ?? 'Nuevo',
      owned: json['owned'] ?? json['Owned'] ?? false,
    );
  }
}