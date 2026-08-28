import 'package:dio/dio.dart';
import '../core/api_config.dart';
import '../models/game_models.dart';
import '../models/series_models.dart';
import '../models/achievement_models.dart';

class ApiService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      headers: {'Content-Type': 'application/json'},
    ),
  );

  // Estadísticas KPI
  Future<Map<String, dynamic>> getStats() async {
    final res = await _dio.get('/library/stats');
    return res.data as Map<String, dynamic>;
  }

  // Juegos con Paginación
  Future<List<GameSummary>> getGames({
    String? search,
    String? status,
    int page = 1,
    int pageSize = 24,
  }) async {
    final res = await _dio.get('/library/games', queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
      if (status != null && status.isNotEmpty) 'status': status,
      'page': page,
      'pageSize': pageSize,
    });
    return (res.data as List).map((x) => GameSummary.fromJson(x)).toList();
  }

  Future<GameDetail> getGame(int id) async {
    final res = await _dio.get('/library/games/$id');
    return GameDetail.fromJson(res.data);
  }

  Future<int> createManualGame(String name, String? coverUrl, String status) async {
    final res = await _dio.post('/library/games', data: {
      'name': name,
      'coverUrl': coverUrl,
      'status': status,
      'notes': null,
    });
    return res.data['id'];
  }

  Future<void> updateGame(int id, {String? status, int? myRating, double? playTimeHours, String? notes}) async {
    await _dio.patch('/library/games/$id', data: {
      'status': status,
      'myRating': myRating,
      'playTimeHours': playTimeHours,
      'notes': notes,
    });
  }

  Future<void> deleteGame(int id) async {
    await _dio.delete('/library/games/$id');
  }

  Future<void> refreshIgdb(int id) async {
    await _dio.post('/library/games/$id/igdb/refresh');
  }

  // IGDB Search & Import
  Future<List<Map<String, dynamic>>> searchIgdb(String query, {bool byId = false}) async {
    final res = await _dio.get(
      byId ? '/igdb/search?id=$query' : '/igdb/search?q=$query',
    );
    return List<Map<String, dynamic>>.from(res.data);
  }

  Future<void> importIgdbGame(int igdbId) async {
    await _dio.post('/library/games/import', data: {'igdbId': igdbId});
  }

  // Catálogos
  Future<List<Map<String, dynamic>>> getCatalog(String type) async {
    final res = await _dio.get('/library/catalog/$type');
    return List<Map<String, dynamic>>.from(res.data['items'] ?? []);
  }

  // Copias
  Future<void> addCollectionEntry(int gameId, int platformId, int storeId, String edition, String format) async {
    await _dio.post('/library/games/$gameId/collection', data: {
      'platformId': platformId,
      'storeId': storeId,
      'edition': edition,
      'owned': true,
      'format': format,
    });
  }

  Future<void> deleteCollectionEntry(int id) async {
    await _dio.delete('/library/collection/$id');
  }

  Future<List<OwnedCollectionItem>> getCollection({String? search}) async {
    final res = await _dio.get('/library/collection', queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
    });
    return (res.data as List).map((x) => OwnedCollectionItem.fromJson(x)).toList();
  }

  // DLC Link / Unlink
  Future<void> linkDlcToCopy(int copyId, int dlcId) async {
    await _dio.post('/library/collection/$copyId/dlcs/$dlcId', data: {'owned': true});
  }

  Future<void> unlinkDlc(int copyId, int dlcId) async {
    await _dio.delete('/library/collection/$copyId/dlcs/$dlcId');
  }

  // Series
  Future<List<SeriesSummary>> getSeries() async {
    final res = await _dio.get('/library/series');
    return (res.data as List).map((x) => SeriesSummary.fromJson(x)).toList();
  }

  Future<SeriesDetail> getSeriesDetail(int id) async {
    final res = await _dio.get('/library/series/$id');
    return SeriesDetail.fromJson(res.data);
  }

  // Logros
  Future<List<AchievementItem>> getGameAchievements(int gameId) async {
    final res = await _dio.get('/library/games/$gameId/achievements');
    return (res.data as List).map((x) => AchievementItem.fromJson(x)).toList();
  }

  Future<List<GlobalAchievementItem>> getAllAchievements({String? search, int? gameId, int? platformId, bool? unlocked}) async {
    final res = await _dio.get('/library/achievements', queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
      if (gameId != null) 'gameId': gameId,
      if (platformId != null) 'platformId': platformId,
      if (unlocked != null) 'unlocked': unlocked,
    });
    return (res.data as List).map((x) => GlobalAchievementItem.fromJson(x)).toList();
  }

  Future<void> toggleAchievement(int id, bool unlocked) async {
    await _dio.patch('/library/achievements/$id', data: {'unlocked': unlocked});
  }

  Future<void> importAchievementsJson(int gameId, Map<String, dynamic> jsonPayload) async {
    await _dio.post('/library/games/$gameId/achievements/import-json', data: jsonPayload);
  }

  Future<List<Map<String, dynamic>>> searchTrophiesHunter(String game, String platform) async {
    final res = await _dio.get('/achievement-sources/trophieshunter/search', queryParameters: {
      'game': game,
      'platform': platform,
    });
    return List<Map<String, dynamic>>.from(res.data);
  }

  Future<int> translateExistingAchievements(int gameId) async {
    final res = await _dio.post('/library/games/$gameId/achievements/translate');
    return res.data['translated'] ?? 0;
  }

  Future<int> importTrophiesHunterUrl(int gameId, int platformId, String sourceUrl) async {
    final res = await _dio.post('/library/games/$gameId/achievements/import', data: {
      'platformId': platformId,
      'sourceUrl': sourceUrl,
      'storeId': null,
    });
    return res.data['imported'] ?? 0;
  }
}