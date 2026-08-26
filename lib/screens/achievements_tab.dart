import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/app_theme.dart';
import '../providers/library_provider.dart';

class AchievementsTab extends StatefulWidget {
  const AchievementsTab({super.key});

  @override
  State<AchievementsTab> createState() => _AchievementsTabState();
}

class _AchievementsTabState extends State<AchievementsTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  int? _selectedGameId;
  int? _selectedPlatformId;
  bool? _selectedStatus; // null: todos, true: desbloqueados, false: pendientes

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyFilters();
    });
  }

  void _applyFilters() {
    context.read<LibraryProvider>().loadGlobalAchievements(
          search: _searchCtrl.text.trim(),
          gameId: _selectedGameId,
          platformId: _selectedPlatformId,
          unlocked: _selectedStatus,
        );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LibraryProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Logros Globales')),
      body: Column(
        children: [
          // Barra de Búsqueda
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => _applyFilters(),
              decoration: InputDecoration(
                hintText: 'Buscar logro por nombre...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted),
                filled: true,
                fillColor: AppTheme.panel,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
              ),
            ),
          ),

          // Filtros Desplegables (Juego, Plataforma, Estado)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Filtro Estado
                DropdownButton<bool?>(
                  value: _selectedStatus,
                  dropdownColor: AppTheme.panel,
                  style: const TextStyle(fontSize: 12, color: AppTheme.text),
                  hint: const Text('Estado: Todos', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Todos los estados')),
                    DropdownMenuItem(value: true, child: Text('Desbloqueados')),
                    DropdownMenuItem(value: false, child: Text('Pendientes')),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedStatus = val);
                    _applyFilters();
                  },
                ),
                const SizedBox(width: 12),

                // Filtro Juego
                DropdownButton<int?>(
                  value: _selectedGameId,
                  dropdownColor: AppTheme.panel,
                  style: const TextStyle(fontSize: 12, color: AppTheme.text),
                  hint: const Text('Filtrar por Juego', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todos los juegos')),
                    ...provider.games.map((g) => DropdownMenuItem(value: g.id, child: Text(g.name))),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedGameId = val);
                    _applyFilters();
                  },
                ),
                const SizedBox(width: 12),

                // Filtro Plataforma
                DropdownButton<int?>(
                  value: _selectedPlatformId,
                  dropdownColor: AppTheme.panel,
                  style: const TextStyle(fontSize: 12, color: AppTheme.text),
                  hint: const Text('Plataforma', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todas')),
                    ...provider.platforms.map((p) => DropdownMenuItem(value: p['id'] as int, child: Text(p['name'] as String))),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedPlatformId = val);
                    _applyFilters();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Lista de Logros
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
                : provider.globalAchievements.isEmpty
                    ? const Center(child: Text('No hay logros que coincidan con los filtros.', style: TextStyle(color: AppTheme.textMuted)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: provider.globalAchievements.length,
                        itemBuilder: (context, idx) {
                          final a = provider.globalAchievements[idx];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.panel,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: a.unlocked,
                                  activeColor: AppTheme.accent,
                                  onChanged: (val) {
                                    setState(() => a.unlocked = val ?? false);
                                    provider.toggleAchievement(a.id, a.unlocked);
                                  },
                                ),
                                if (a.imageUrl != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: CachedNetworkImage(imageUrl: a.imageUrl!, width: 40, height: 40, fit: BoxFit.cover),
                                  ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(a.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      Text('${a.gameName} · ${a.platform}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}