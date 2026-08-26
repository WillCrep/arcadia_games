import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/app_theme.dart';
import '../providers/library_provider.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/interactive_game_card.dart';
import 'game_detail_screen.dart';
import 'stats_dashboard_screen.dart';

class LibraryTab extends StatefulWidget {
  const LibraryTab({super.key});

  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    // Listener para detectar cuando el usuario se acerca al final de la lista
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 300) {
      context.read<LibraryProvider>().loadMoreGames();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LibraryProvider>();
    final allGames = provider.games;
    final stats = provider.stats;
    final screenWidth = MediaQuery.of(context).size.width;

    // Conteo dinámico
    final statusCounts = <String, int>{
      '': allGames.length,
      'Jugando': 0,
      'Por jugar': 0,
      'Completado': 0,
      'Pausado': 0,
    };

    for (final g in allGames) {
      if (statusCounts.containsKey(g.status)) {
        statusCounts[g.status] = (statusCounts[g.status] ?? 0) + 1;
      }
    }

    // Columnas responsivas
    int crossAxisCount = 2;
    if (screenWidth >= 1200) {
      crossAxisCount = 6;
    } else if (screenWidth >= 900) {
      crossAxisCount = 4;
    } else if (screenWidth >= 600) {
      crossAxisCount = 3;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteca de Juegos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined, color: AppTheme.cyan),
            tooltip: 'Estadísticas y Gráficos',
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsDashboardScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.textMuted),
            tooltip: 'Recargar biblioteca',
            onPressed: () {
              HapticFeedback.lightImpact();
              provider.loadStats();
              provider.loadGames(refresh: true);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.accent,
        backgroundColor: AppTheme.panel,
        onRefresh: () async {
          HapticFeedback.lightImpact();
          await provider.loadStats();
          await provider.loadGames(refresh: true);
        },
        child: CustomScrollView(
          controller: _scrollCtrl,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 1. BANNER RESUMEN
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsDashboardScreen()));
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.accent.withOpacity(0.22),
                          AppTheme.lime.withOpacity(0.12),
                          AppTheme.panel,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.accent.withOpacity(0.35)),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _summaryMetric('JUEGOS', '${stats['games'] ?? allGames.length}', Icons.sports_esports, AppTheme.text),
                        Container(height: 28, width: 1, color: Colors.white12),
                        _summaryMetric('JUGANDO', '${statusCounts['Jugando']}', Icons.play_arrow_rounded, AppTheme.cyan),
                        Container(height: 28, width: 1, color: Colors.white12),
                        _summaryMetric('COMPLETADOS', '${statusCounts['Completado']}', Icons.check_circle, AppTheme.lime),
                        Container(height: 28, width: 1, color: Colors.white12),
                        _summaryMetric('POR JUGAR', '${statusCounts['Por jugar']}', Icons.bookmark_border_rounded, AppTheme.warning),
                      ],
                    ),
                  ),
                ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1, end: 0),
              ),
            ),

            // 2. BUSCADOR
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (val) => provider.setSearch(val.trim()),
                  decoration: InputDecoration(
                    hintText: 'Buscar juego por título o saga...',
                    hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted, size: 20),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18, color: AppTheme.textMuted),
                            onPressed: () {
                              _searchCtrl.clear();
                              provider.setSearch('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppTheme.panel,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                  ),
                ),
              ),
            ),

            // 3. FILTRO POR ESTADO
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _statusFilterChip(provider, '', 'Todos', Icons.all_inclusive, AppTheme.text, statusCounts[''] ?? 0),
                    _statusFilterChip(provider, 'Jugando', 'Jugando', Icons.play_arrow_rounded, AppTheme.cyan, statusCounts['Jugando'] ?? 0),
                    _statusFilterChip(provider, 'Por jugar', 'Por jugar', Icons.bookmark_border_rounded, AppTheme.warning, statusCounts['Por jugar'] ?? 0),
                    _statusFilterChip(provider, 'Completado', 'Completados', Icons.check_circle_outline, AppTheme.lime, statusCounts['Completado'] ?? 0),
                    _statusFilterChip(provider, 'Pausado', 'Pausados', Icons.pause_circle_outline, const Color(0xFF6366F1), statusCounts['Pausado'] ?? 0),
                  ],
                ),
              ),
            ),

            // 4. INDICADOR DE RESULTADOS
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${allGames.length} ${allGames.length == 1 ? 'juego cargado' : 'juegos cargados'}',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    if (provider.statusFilter.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          provider.setFilter('');
                        },
                        child: const Text('Quitar filtro ✕', style: TextStyle(color: AppTheme.cyan, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 6)),

            // 5. GRID DE VIDEOJUEGOS
            if (provider.isLoading)
              SliverToBoxAdapter(child: GameGridShimmer(crossAxisCount: crossAxisCount))
            else if (allGames.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sports_esports_outlined, size: 48, color: AppTheme.textMuted),
                      SizedBox(height: 10),
                      Text('No se encontraron juegos.', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 0.68,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final game = allGames[index];
                      return InteractiveGameCard(
                        game: game,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => GameDetailScreen(gameId: game.id)),
                          );
                        },
                      );
                    },
                    childCount: allGames.length,
                  ),
                ),
              ),

            // 6. SPINNER DE CARGA INFINITA AL FINAL DE LA LISTA
            if (provider.isLoadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.accent,
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
  }

  Widget _summaryMetric(String label, String value, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
      ],
    );
  }

  Widget _statusFilterChip(
    LibraryProvider provider,
    String statusKey,
    String label,
    IconData icon,
    Color color,
    int count,
  ) {
    final isSelected = provider.statusFilter == statusKey;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        avatar: Icon(icon, size: 15, color: isSelected ? Colors.white : color),
        label: Text('$label ($count)'),
        selected: isSelected,
        selectedColor: color.withOpacity(0.35),
        backgroundColor: AppTheme.panel,
        checkmarkColor: Colors.white,
        side: BorderSide(color: isSelected ? color : AppTheme.border),
        labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          color: isSelected ? Colors.white : AppTheme.textMuted,
        ),
        onSelected: (_) {
          HapticFeedback.selectionClick();
          provider.setFilter(statusKey);
        },
      ),
    );
  }
}