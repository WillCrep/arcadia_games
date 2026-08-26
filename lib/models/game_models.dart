import 'dart:convert';

class GameSummary {
  final int id;
  final String name;
  final String? coverUrl;
  final String status;
  final int? myRating;
  final DateTime? releaseDate;
  final double? playTimeHours;
  final String? seriesName;
  final int ownedCopies;
  final int achievementTotal;
  final int achievementUnlocked;
  final List<String> genres;

  GameSummary({
    required this.id,
    required this.name,
    this.coverUrl,
    required this.status,
    this.myRating,
    this.releaseDate,
    this.playTimeHours,
    this.seriesName,
    this.ownedCopies = 0,
    this.achievementTotal = 0,
    this.achievementUnlocked = 0,
    this.genres = const [],
  });

  factory GameSummary.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) return raw.map((e) => e.toString()).toList();
      try {
        final parsed = jsonDecode(raw);
        if (parsed is List) return parsed.map((e) => e.toString()).toList();
      } catch (_) {}
      return [];
    }

    return GameSummary(
      id: json['id'] ?? json['Id'],
      name: json['name'] ?? json['Name'] ?? 'Sin nombre',
      coverUrl: json['coverUrl'] ?? json['CoverUrl'],
      status: json['status'] ?? json['Status'] ?? 'Nuevo',
      myRating: json['myRating'] ?? json['MyRating'],
      releaseDate: json['releaseDate'] != null ? DateTime.tryParse(json['releaseDate']) : null,
      playTimeHours: (json['playTimeHours'] ?? json['PlayTimeHours'])?.toDouble(),
      seriesName: json['seriesName'] ?? json['SeriesName'],
      ownedCopies: json['ownedCopies'] ?? json['OwnedCopies'] ?? 0,
      achievementTotal: json['achievementTotal'] ?? json['AchievementTotal'] ?? 0,
      achievementUnlocked: json['achievementUnlocked'] ?? json['AchievementUnlocked'] ?? 0,
      genres: parseList(json['genres'] ?? json['Genres']),
    );
  }

  double get progressPercent => achievementTotal > 0 ? (achievementUnlocked / achievementTotal) : 0.0;
}

class GameDetail {
  final int id;
  final String name;
  final int? igdbId;
  final String? summary;
  final String? coverUrl;
  final String? igdbUrl;
  final DateTime? releaseDate;
  final double? igdbRating;
  final int? myRating;
  final String status;
  final double? playTimeHours;
  final String? notes;
  final int? seriesId;
  final String? seriesName;
  final List<String> genres;
  final List<String> developers;
  final List<String> publishers;
  final List<String> franchises;
  final List<String> screenshots;
  final List<CollectionEntryItem> collection;
  final List<DlcItem> dlcs;

  GameDetail({
    required this.id,
    required this.name,
    this.igdbId,
    this.summary,
    this.coverUrl,
    this.igdbUrl,
    this.releaseDate,
    this.igdbRating,
    this.myRating,
    required this.status,
    this.playTimeHours,
    this.notes,
    this.seriesId,
    this.seriesName,
    this.genres = const [],
    this.developers = const [],
    this.publishers = const [],
    this.franchises = const [],
    this.screenshots = const [],
    this.collection = const [],
    this.dlcs = const [],
  });

  factory GameDetail.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) return raw.map((e) => e.toString()).toList();
      try {
        final parsed = jsonDecode(raw);
        if (parsed is List) return parsed.map((e) => e.toString()).toList();
      } catch (_) {}
      return [];
    }

    return GameDetail(
      id: json['id'] ?? json['Id'],
      name: json['name'] ?? json['Name'] ?? 'Sin nombre',
      igdbId: json['igdbId'] ?? json['IgdbId'],
      summary: json['summary'] ?? json['Summary'],
      coverUrl: json['coverUrl'] ?? json['CoverUrl'],
      igdbUrl: json['igdbUrl'] ?? json['IgdbUrl'],
      releaseDate: json['releaseDate'] != null ? DateTime.tryParse(json['releaseDate']) : null,
      igdbRating: (json['igdbRating'] ?? json['IgdbRating'])?.toDouble(),
      myRating: json['myRating'] ?? json['MyRating'],
      status: json['status'] ?? json['Status'] ?? 'Nuevo',
      playTimeHours: (json['playTimeHours'] ?? json['PlayTimeHours'])?.toDouble(),
      notes: json['notes'] ?? json['Notes'],
      seriesId: json['seriesId'] ?? json['SeriesId'],
      seriesName: json['seriesName'] ?? json['SeriesName'],
      genres: parseList(json['genres'] ?? json['Genres']),
      developers: parseList(json['developers'] ?? json['Developers']),
      publishers: parseList(json['publishers'] ?? json['Publishers']),
      franchises: parseList(json['franchises'] ?? json['Franchises']),
      screenshots: parseList(json['screenshots'] ?? json['Screenshots']),
      collection: (json['collection'] as List? ?? json['Collection'] as List? ?? [])
          .map((x) => CollectionEntryItem.fromJson(x))
          .toList(),
      dlcs: (json['dlcs'] as List? ?? json['Dlcs'] as List? ?? [])
          .map((x) => DlcItem.fromJson(x))
          .toList(),
    );
  }
}

class CollectionEntryItem {
  final int id;
  final String platform;
  final String store;
  final String edition;
  final bool owned;
  final String? format;

  CollectionEntryItem({
    required this.id,
    required this.platform,
    required this.store,
    required this.edition,
    required this.owned,
    this.format,
  });

  factory CollectionEntryItem.fromJson(Map<String, dynamic> json) {
    return CollectionEntryItem(
      id: json['id'] ?? json['Id'],
      platform: json['platform'] ?? json['Platform'] ?? 'Plataforma',
      store: json['store'] ?? json['Store'] ?? 'Tienda',
      edition: json['edition'] ?? json['Edition'] ?? 'Base',
      owned: json['owned'] ?? json['Owned'] ?? true,
      format: json['format'] ?? json['Format'] ?? 'Digital',
    );
  }
}

class DlcItem {
  final int id;
  final int? igdbId;
  final String name;
  final String? type;
  final List<DlcLinkedCopy> copies;

  DlcItem({
    required this.id,
    this.igdbId,
    required this.name,
    this.type,
    this.copies = const [],
  });

  factory DlcItem.fromJson(Map<String, dynamic> json) {
    return DlcItem(
      id: json['id'] ?? json['Id'],
      igdbId: json['igdbId'] ?? json['IgdbId'],
      name: json['name'] ?? json['Name'] ?? 'DLC',
      type: json['type'] ?? json['Type'] ?? 'DLC',
      copies: (json['copies'] as List? ?? json['Copies'] as List? ?? [])
          .map((x) => DlcLinkedCopy.fromJson(x))
          .toList(),
    );
  }
}

class DlcLinkedCopy {
  final int collectionEntryId;
  final String platform;
  final String store;

  DlcLinkedCopy({
    required this.collectionEntryId,
    required this.platform,
    required this.store,
  });

  factory DlcLinkedCopy.fromJson(Map<String, dynamic> json) {
    return DlcLinkedCopy(
      collectionEntryId: json['collectionEntryId'] ?? json['CollectionEntryId'],
      platform: json['platform'] ?? json['Platform'] ?? '',
      store: json['store'] ?? json['Store'] ?? '',
    );
  }
}

class OwnedCollectionItem {
  final int id;
  final int gameId;
  final String gameName;
  final String? coverUrl;
  final String platform;
  final String store;
  final String edition;
  final String? format;
  final bool owned;
  final String status;

  OwnedCollectionItem({
    required this.id,
    required this.gameId,
    required this.gameName,
    this.coverUrl,
    required this.platform,
    required this.store,
    required this.edition,
    this.format,
    required this.owned,
    required this.status,
  });

  factory OwnedCollectionItem.fromJson(Map<String, dynamic> json) {
    return OwnedCollectionItem(
      id: json['id'] ?? json['Id'],
      gameId: json['gameId'] ?? json['GameId'],
      gameName: json['gameName'] ?? json['GameName'] ?? '',
      coverUrl: json['coverUrl'] ?? json['CoverUrl'],
      platform: json['platform'] ?? json['Platform'] ?? '',
      store: json['store'] ?? json['Store'] ?? '',
      edition: json['edition'] ?? json['Edition'] ?? 'Base',
      format: json['format'] ?? json['Format'] ?? 'Digital',
      owned: json['owned'] ?? json['Owned'] ?? true,
      status: json['status'] ?? json['Status'] ?? 'Nuevo',
    );
  }
}