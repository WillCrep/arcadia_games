import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/game_models.dart';
import '../models/series_models.dart';
import '../models/achievement_models.dart';

class LibraryProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  // Estados de carga y paginación
  bool isLoading = false;
  bool isLoadingMore = false;
  bool hasMoreGames = true;
  int _currentPage = 1;
  static const int _pageSize = 24;

  Map<String, dynamic> stats = {};
  List<GameSummary> games = [];
  List<OwnedCollectionItem> collectionList = [];
  List<SeriesSummary> seriesList = [];
  List<GlobalAchievementItem> globalAchievements = [];
  
  List<Map<String, dynamic>> platforms = [];
  List<Map<String, dynamic>> stores = [];

  String searchQuery = '';
  String statusFilter = '';

  Future<void> init() async {
    await Future.wait([
      loadStats(),
      loadGames(refresh: true),
      loadCatalogs(),
    ]);
  }

  Future<void> loadStats() async {
    try {
      stats = await _api.getStats();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadCatalogs() async {
    try {
      final res = await Future.wait([
        _api.getCatalog('platforms'),
        _api.getCatalog('stores'),
      ]);
      platforms = res[0];
      stores = res[1];
      notifyListeners();
    } catch (_) {}
  }

  // Carga inicial o reseteo
  Future<void> loadGames({bool refresh = true}) async {
    if (refresh) {
      _currentPage = 1;
      hasMoreGames = true;
      isLoading = true;
      notifyListeners();
    }

    try {
      final newGames = await _api.getGames(
        search: searchQuery,
        status: statusFilter,
        page: _currentPage,
        pageSize: _pageSize,
      );

      if (newGames.length < _pageSize) {
        hasMoreGames = false;
      }

      if (refresh) {
        games = newGames;
      } else {
        games.addAll(newGames);
      }
      _currentPage++;
    } catch (e) {
      debugPrint('Error cargando juegos: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // Carga de la siguiente página al hacer scroll
  Future<void> loadMoreGames() async {
    if (isLoading || isLoadingMore || !hasMoreGames) return;

    isLoadingMore = true;
    notifyListeners();

    try {
      final newGames = await _api.getGames(
        search: searchQuery,
        status: statusFilter,
        page: _currentPage,
        pageSize: _pageSize,
      );

      if (newGames.length < _pageSize) {
        hasMoreGames = false;
      }

      games.addAll(newGames);
      _currentPage++;
    } catch (e) {
      debugPrint('Error cargando más juegos: $e');
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  void setFilter(String status) {
    statusFilter = status;
    loadGames(refresh: true);
  }

  void setSearch(String query) {
    searchQuery = query;
    loadGames(refresh: true);
  }

  Future<void> loadCollection([String? search]) async {
    isLoading = true;
    notifyListeners();
    try {
      collectionList = await _api.getCollection(search: search);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadSeries() async {
    isLoading = true;
    notifyListeners();
    try {
      seriesList = await _api.getSeries();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadGlobalAchievements({String? search, int? gameId, int? platformId, bool? unlocked}) async {
    isLoading = true;
    notifyListeners();
    try {
      globalAchievements = await _api.getAllAchievements(
        search: search,
        gameId: gameId,
        platformId: platformId,
        unlocked: unlocked,
      );
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleAchievement(int id, bool unlocked) async {
    try {
      await _api.toggleAchievement(id, unlocked);
      loadStats();
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> deleteGame(int id) async {
    await _api.deleteGame(id);
    await loadStats();
    await loadGames(refresh: true);
  }

  Future<void> deleteCollectionEntry(int id) async {
    await _api.deleteCollectionEntry(id);
    await loadCollection();
    await loadStats();
  }

  Future<void> addCollectionEntry(int gameId, int platformId, int storeId, String edition, String format) async {
    await _api.addCollectionEntry(gameId, platformId, storeId, edition, format);
    await loadCollection(); // 👈 Refresca la lista de copias en memoria
    await loadStats();      // 👈 Refresca los contadores de copias
  }
}