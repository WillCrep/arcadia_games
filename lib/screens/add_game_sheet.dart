import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/app_theme.dart';
import '../services/api_service.dart';
import '../providers/library_provider.dart';

class AddGameSheet extends StatefulWidget {
  const AddGameSheet({super.key});

  @override
  State<AddGameSheet> createState() => _AddGameSheetState();
}

class _AddGameSheetState extends State<AddGameSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _api = ApiService();

  // Búsqueda IGDB
  String _searchMode = 'name'; // 'name' o 'id'
  final TextEditingController _queryCtrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isSearching = false;
  bool _isImporting = false;

  // Formulario Manual
  final TextEditingController _manualNameCtrl = TextEditingController();
  final TextEditingController _manualCoverCtrl = TextEditingController();
  String _manualStatus = 'Nuevo';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _queryCtrl.dispose();
    _manualNameCtrl.dispose();
    _manualCoverCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final text = _queryCtrl.text.trim();
    if (text.isEmpty) return;

    if (_searchMode == 'id' && int.tryParse(text) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa un ID numérico válido de IGDB.')),
      );
      return;
    }

    setState(() {
      _isSearching = true;
      _results = [];
    });

    try {
      final res = await _api.searchIgdb(text, byId: _searchMode == 'id');
      setState(() => _results = res);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error en búsqueda: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _importGame(int igdbId) async {
    setState(() => _isImporting = true);
    try {
      await _api.importIgdbGame(igdbId);
      if (mounted) {
        context.read<LibraryProvider>().init();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Juego importado exitosamente desde IGDB!'), backgroundColor: AppTheme.lime),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al importar: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _saveManualGame() async {
    final name = _manualNameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _isImporting = true);
    try {
      await _api.createManualGame(
        name,
        _manualCoverCtrl.text.trim().isEmpty ? null : _manualCoverCtrl.text.trim(),
        _manualStatus,
      );
      if (mounted) {
        context.read<LibraryProvider>().init();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Juego manual guardado'), backgroundColor: AppTheme.lime),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppTheme.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header y Pestañas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Añadir Videojuego', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.close, color: AppTheme.textMuted),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.accent,
            labelColor: AppTheme.accent,
            unselectedLabelColor: AppTheme.textMuted,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: const [
              Tab(icon: Icon(Icons.cloud_download, size: 18), text: 'Buscar en IGDB'),
              Tab(icon: Icon(Icons.edit_note, size: 18), text: 'Creación Manual'),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. PESTAÑA IGDB (Nombre o ID)
                Column(
                  children: [
                    // Selector Nombre / ID
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.panel,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _searchMode,
                              dropdownColor: AppTheme.panel,
                              style: const TextStyle(color: AppTheme.text, fontSize: 12, fontWeight: FontWeight.bold),
                              items: const [
                                DropdownMenuItem(value: 'name', child: Text('Por Nombre')),
                                DropdownMenuItem(value: 'id', child: Text('Por IGDB ID')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _searchMode = val;
                                    _queryCtrl.clear();
                                    _results.clear();
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _queryCtrl,
                            keyboardType: _searchMode == 'id' ? TextInputType.number : TextInputType.text,
                            onSubmitted: (_) => _search(),
                            decoration: InputDecoration(
                              hintText: _searchMode == 'id' ? 'Ej. 119277 (ID numérico)' : 'Ej. Elden Ring...',
                              hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                              filled: true,
                              fillColor: AppTheme.panel,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          style: IconButton.styleFrom(backgroundColor: AppTheme.accent),
                          icon: const Icon(Icons.search, color: Colors.white, size: 20),
                          onPressed: _search,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Estado de Carga / Resultados
                    if (_isSearching || _isImporting)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(color: AppTheme.accent),
                              const SizedBox(height: 12),
                              Text(
                                _isImporting ? 'Importando juego, DLCs y logros desde IGDB...' : 'Consultando base de datos de IGDB...',
                                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: _results.isEmpty
                            ? const Center(child: Text('Busca un título por nombre o introduce su ID directo de IGDB.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12), textAlign: TextAlign.center))
                            : ListView.builder(
                                itemCount: _results.length,
                                itemBuilder: (context, idx) {
                                  final r = _results[idx];
                                  final platforms = (r['platforms'] as List?)?.join(', ') ?? 'Plataforma no indicada';
                                  final year = r['releaseYear'] != null ? '${r['releaseYear']}' : 'Año desc.';

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.panel,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppTheme.border),
                                    ),
                                    child: Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: r['coverUrl'] != null
                                              ? CachedNetworkImage(imageUrl: r['coverUrl'], width: 38, height: 50, fit: BoxFit.cover)
                                              : Container(width: 38, height: 50, color: AppTheme.panelHover, child: const Icon(Icons.gamepad, size: 18)),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(r['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                              const SizedBox(height: 2),
                                              Text('ID: ${r['id']} · $year', style: const TextStyle(color: AppTheme.cyan, fontSize: 11, fontWeight: FontWeight.w600)),
                                              Text(platforms, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.accent,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                            minimumSize: const Size(60, 32),
                                          ),
                                          onPressed: _isImporting ? null : () => _importGame(r['id']),
                                          child: const Text('Importar', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                  ],
                ),

                // 2. PESTAÑA CREACIÓN MANUAL
                SingleChildScrollView(
                  child: Column(
                    children: [
                      TextField(
                        controller: _manualNameCtrl,
                        decoration: const InputDecoration(labelText: 'Nombre del Juego *', hintText: 'Ej. Hades II'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _manualCoverCtrl,
                        decoration: const InputDecoration(labelText: 'URL de Portada (Opcional)', hintText: 'https://...'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _manualStatus,
                        decoration: const InputDecoration(labelText: 'Estado Inicial'),
                        items: ['Nuevo', 'Por jugar', 'Jugando', 'Pausado', 'Completado']
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) => _manualStatus = v ?? _manualStatus,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
                          onPressed: _isImporting ? null : _saveManualGame,
                          child: const Text('Guardar Juego Manual', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}