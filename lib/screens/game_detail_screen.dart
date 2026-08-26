import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:confetti/confetti.dart';
import 'package:file_picker/file_picker.dart';
import '../core/app_theme.dart';
import '../services/api_service.dart';
import '../models/game_models.dart';
import '../models/achievement_models.dart';
import '../providers/library_provider.dart';

class GameDetailScreen extends StatefulWidget {
  final int gameId;
  const GameDetailScreen({super.key, required this.gameId});

  @override
  State<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends State<GameDetailScreen> {
  final ApiService _api = ApiService();
  late ConfettiController _confettiCtrl;
  
  GameDetail? _game;
  List<AchievementItem> _achievements = [];
  Color _dynamicColor = AppTheme.accent;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _confettiCtrl = ConfettiController(duration: const Duration(seconds: 3));
    _loadAll();
  }

  @override
  void dispose() {
    _confettiCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final g = await _api.getGame(widget.gameId);
      final ach = await _api.getGameAchievements(widget.gameId);
      
      // Extracción de color dominante con Palette Generator
      if (g.coverUrl != null) {
        final palette = await PaletteGenerator.fromImageProvider(
          CachedNetworkImageProvider(g.coverUrl!),
          maximumColorCount: 12,
        );
        _dynamicColor = palette.vibrantColor?.color ?? palette.dominantColor?.color ?? AppTheme.accent;
      }

      setState(() {
        _game = g;
        _achievements = ach;
      });
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _triggerCelebration() {
    HapticFeedback.heavyImpact();
    _confettiCtrl.play();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _game == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.accent)));
    }

    final g = _game!;
    final isWide = MediaQuery.of(context).size.width >= 750;

    return Stack(
      children: [
        Scaffold(
          appBar: isWide ? AppBar(title: Text(g.name)) : null,
          body: isWide
              ? _buildTabletLandscapeLayout(g)
              : _buildMobilePortraitLayout(g),
        ),
        // Confeti de celebración
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiCtrl,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [AppTheme.accent, AppTheme.cyan, AppTheme.lime, AppTheme.warning, Colors.white],
          ),
        ),
      ],
    );
  }

  // ================= 1. TABLET / LANDSCAPE =================
  Widget _buildTabletLandscapeLayout(GameDetail g) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: _dynamicColor.withOpacity(0.35), blurRadius: 25, spreadRadius: 2)],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: g.coverUrl != null
                          ? Hero(tag: 'cover_${g.id}', child: CachedNetworkImage(imageUrl: g.coverUrl!, height: 380, width: 320, fit: BoxFit.cover))
                          : Container(height: 380, width: 320, color: AppTheme.panel),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(g.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _chip(g.status, _dynamicColor),
                      if (g.igdbRating != null) _chip('★ ${g.igdbRating!.toStringAsFixed(1)} IGDB', AppTheme.warning),
                      if (g.myRating != null) _chip('Mi Nota: ${g.myRating}/5', AppTheme.cyan),
                      if (g.playTimeHours != null) _chip('${g.playTimeHours} hrs', AppTheme.textMuted),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _actionButtons(g),
                  const SizedBox(height: 16),
                  _metaGrid({
                    'Géneros': g.genres.join(', '),
                    'Desarrollador': g.developers.join(', '),
                    'Publisher': g.publishers.join(', '),
                    'Franquicia': g.franchises.join(', '),
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (g.seriesName != null && g.seriesName!.isNotEmpty) _seriesBanner(g),
                  _section('Resumen', g.summary ?? 'Sin descripción disponible.'),
                  if (g.screenshots.isNotEmpty) _screenshotsGallery(g),
                  if (g.notes != null && g.notes!.isNotEmpty) _section('Mis Notas Personales', g.notes!),
                  _copiesSection(g),
                  if (g.dlcs.isNotEmpty) _dlcsSection(g),
                  _achievementsSection(g),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= 2. MÓVIL VERTICAL =================
  Widget _buildMobilePortraitLayout(GameDetail g) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 240,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                if (g.coverUrl != null)
                  Hero(tag: 'cover_${g.id}', child: CachedNetworkImage(imageUrl: g.coverUrl!, fit: BoxFit.cover)),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, _dynamicColor.withOpacity(0.2), AppTheme.bg],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(g.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _chip(g.status, _dynamicColor),
                    if (g.igdbRating != null) _chip('★ ${g.igdbRating!.toStringAsFixed(1)} IGDB', AppTheme.warning),
                    if (g.myRating != null) _chip('Mi Nota: ${g.myRating}/5', AppTheme.cyan),
                    if (g.playTimeHours != null) _chip('${g.playTimeHours} hrs', AppTheme.textMuted),
                  ],
                ),
                const SizedBox(height: 14),
                if (g.seriesName != null && g.seriesName!.isNotEmpty) _seriesBanner(g),
                _actionButtons(g),
                const SizedBox(height: 18),
                _section('Resumen', g.summary ?? 'Sin descripción disponible.'),
                if (g.screenshots.isNotEmpty) _screenshotsGallery(g),
                _metaGrid({
                  'Géneros': g.genres.join(', '),
                  'Desarrollador': g.developers.join(', '),
                  'Publisher': g.publishers.join(', '),
                  'Franquicia': g.franchises.join(', '),
                }),
                if (g.notes != null && g.notes!.isNotEmpty) _section('Mis Notas Personales', g.notes!),
                _copiesSection(g),
                if (g.dlcs.isNotEmpty) _dlcsSection(g),
                _achievementsSection(g),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _seriesBanner(GameDetail g) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _dynamicColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _dynamicColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PERTENECE A LA SAGA', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _dynamicColor)),
              Text(g.seriesName!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          Icon(Icons.grid_view, color: _dynamicColor, size: 20),
        ],
      ),
    );
  }

  Widget _actionButtons(GameDetail g) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _actionBtn('+ Copia', Icons.add_circle_outline, () => _openAddCopyDialog(g.id)),
          const SizedBox(width: 8),
          _actionBtn('Editar Ficha', Icons.edit, () => _openEditDialog(g)),
          const SizedBox(width: 8),
          _actionBtn('Actualizar IGDB', Icons.sync, () async {
            HapticFeedback.lightImpact();
            await _api.refreshIgdb(g.id);
            _loadAll();
          }),
          const SizedBox(width: 8),
          _actionBtn('Eliminar', Icons.delete_forever, () => _confirmDelete(g.id, g.name), isDanger: true),
        ],
      ),
    );
  }

  Widget _screenshotsGallery(GameDetail g) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Capturas de Pantalla', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: g.screenshots.length,
            itemBuilder: (context, idx) {
              final url = g.screenshots[idx];
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _openImageViewer(url);
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(imageUrl: url, width: 160, height: 110, fit: BoxFit.cover),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _copiesSection(GameDetail g) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Copias en Colección (${g.collection.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Añadir'),
              onPressed: () {
                HapticFeedback.lightImpact();
                _openAddCopyDialog(g.id);
              },
            ),
          ],
        ),
        ...g.collection.map((c) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.panel, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${c.platform} · ${c.store}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('${c.edition} · ${c.format}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: AppTheme.danger, size: 18),
                    onPressed: () async {
                      HapticFeedback.mediumImpact();
                      await _api.deleteCollectionEntry(c.id);
                      _loadAll();
                    },
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _dlcsSection(GameDetail g) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text('DLCs y Expansiones (${g.dlcs.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...g.dlcs.map((d) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.panel, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(d.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(6)),
                        child: Text(d.type ?? 'DLC', style: const TextStyle(fontSize: 10, color: AppTheme.cyan)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          hint: const Text('Vincular a copia...', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                          dropdownColor: AppTheme.panel,
                          items: g.collection.map((c) => DropdownMenuItem(value: c.id, child: Text('${c.platform} (${c.store})', style: const TextStyle(fontSize: 11)))).toList(),
                          onChanged: (copyId) async {
                            if (copyId != null) {
                              HapticFeedback.lightImpact();
                              await _api.linkDlcToCopy(copyId, d.id);
                              _loadAll();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  if (d.copies.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(
                        spacing: 6,
                        children: d.copies.map((cp) => Chip(
                          backgroundColor: AppTheme.lime.withOpacity(0.15),
                          label: Text('${cp.platform} · ${cp.store}', style: const TextStyle(fontSize: 10, color: AppTheme.lime)),
                          deleteIcon: const Icon(Icons.close, size: 14),
                          onDeleted: () async {
                            HapticFeedback.lightImpact();
                            await _api.unlinkDlc(cp.collectionEntryId, d.id);
                            _loadAll();
                          },
                        )).toList(),
                      ),
                    ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _achievementsSection(GameDetail g) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Logros y Trofeos (${_achievements.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            PopupMenuButton<String>(
              icon: Icon(Icons.download, color: _dynamicColor),
              color: AppTheme.panel,
              onSelected: (val) {
                HapticFeedback.lightImpact();
                if (val == 'th') _openTrophiesHunterDialog(g);
                if (val == 'json') _importJsonFile(g.id);
              },
              itemBuilder: (BuildContext context) => const [
                PopupMenuItem(value: 'th', child: Text('Scraper TrophiesHunter')),
                PopupMenuItem(value: 'json', child: Text('Subir archivo JSON')),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._achievements.map((a) => CheckboxListTile(
              value: a.unlocked,
              activeColor: _dynamicColor,
              tileColor: AppTheme.panel,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              title: Text(a.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              subtitle: Text(a.description ?? '', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              onChanged: (val) async {
                HapticFeedback.selectionClick();
                setState(() => a.unlocked = val ?? false);
                await context.read<LibraryProvider>().toggleAchievement(a.id, a.unlocked);
                
                // Si desbloqueó todos los logros, lanzar confeti
                if (_achievements.every((item) => item.unlocked)) {
                  _triggerCelebration();
                }
              },
            )),
      ],
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3))),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _actionBtn(String label, IconData icon, VoidCallback onTap, {bool isDanger = false}) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: isDanger ? AppTheme.danger.withOpacity(0.2) : AppTheme.panel,
        foregroundColor: isDanger ? AppTheme.danger : AppTheme.text,
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }

  Widget _section(String title, String body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(body, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.5)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _metaGrid(Map<String, String> data) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppTheme.panel, borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: data.entries.map((e) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(e.key, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              Flexible(child: Text(e.value.isEmpty ? '—' : e.value, textAlign: TextAlign.end, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
            ],
          ),
        )).toList(),
      ),
    );
  }

  void _openImageViewer(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain)),
            IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 28), onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }

  void _openEditDialog(GameDetail g) {
    String status = g.status;
    final ratingCtrl = TextEditingController(text: g.myRating?.toString() ?? '');
    final hoursCtrl = TextEditingController(text: g.playTimeHours?.toString() ?? '');
    final notesCtrl = TextEditingController(text: g.notes ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.panel,
        title: const Text('Editar Ficha de Juego'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: status,
                decoration: const InputDecoration(labelText: 'Estado'),
                items: ['Nuevo', 'Por jugar', 'Jugando', 'Pausado', 'Completado', 'Abandonado'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => status = v ?? status,
              ),
              TextField(controller: ratingCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Mi Nota (1-5)')),
              TextField(controller: hoursCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Horas Jugadas')),
              TextField(controller: notesCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Notas Personales')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _api.updateGame(g.id, status: status, myRating: int.tryParse(ratingCtrl.text), playTimeHours: double.tryParse(hoursCtrl.text), notes: notesCtrl.text.trim());
              if (status == 'Completado' && g.status != 'Completado') {
                _triggerCelebration();
              }
              _loadAll();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _openAddCopyDialog(int gameId) {
    final provider = context.read<LibraryProvider>();
    int? platformId = provider.platforms.isNotEmpty ? provider.platforms.first['id'] : null;
    int? storeId = provider.stores.isNotEmpty ? provider.stores.first['id'] : null;
    final editionCtrl = TextEditingController(text: 'Standard');
    String format = 'Digital';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.panel,
        title: const Text('Añadir Copia'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              value: platformId,
              decoration: const InputDecoration(labelText: 'Plataforma'),
              items: provider.platforms.map((p) => DropdownMenuItem<int>(value: p['id'], child: Text(p['name']))).toList(),
              onChanged: (v) => platformId = v,
            ),
            DropdownButtonFormField<int>(
              value: storeId,
              decoration: const InputDecoration(labelText: 'Tienda'),
              items: provider.stores.map((s) => DropdownMenuItem<int>(value: s['id'], child: Text(s['name']))).toList(),
              onChanged: (v) => storeId = v,
            ),
            TextField(controller: editionCtrl, decoration: const InputDecoration(labelText: 'Edición')),
            DropdownButtonFormField<String>(
              value: format,
              decoration: const InputDecoration(labelText: 'Formato'),
              items: ['Digital', 'Físico'].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
              onChanged: (v) => format = v ?? format,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (platformId != null && storeId != null) {
                Navigator.pop(context);
                await _api.addCollectionEntry(gameId, platformId!, storeId!, editionCtrl.text.trim(), format);
                _loadAll();
              }
            },
            child: const Text('Guardar Copia'),
          ),
        ],
      ),
    );
  }

  Future<void> _importJsonFile(int gameId) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json'], withData: true);
    if (result != null && result.files.isNotEmpty && result.files.single.bytes != null) {
      final content = utf8.decode(result.files.single.bytes!);
      final jsonPayload = jsonDecode(content);
      await _api.importAchievementsJson(gameId, jsonPayload);
      _loadAll();
    }
  }

  void _openTrophiesHunterDialog(GameDetail g) {
    final searchCtrl = TextEditingController(text: g.name);
    final provider = context.read<LibraryProvider>();
    int platformId = provider.platforms.isNotEmpty ? provider.platforms.first['id'] : 1;
    String platName = provider.platforms.isNotEmpty ? provider.platforms.first['name'] : 'PC';
    List<Map<String, dynamic>> results = [];
    bool searching = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateModal) => AlertDialog(
          backgroundColor: AppTheme.panel,
          title: const Text('TrophiesHunter Scraper'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: searchCtrl, decoration: const InputDecoration(labelText: 'Buscar Juego')),
                DropdownButtonFormField<int>(
                  value: platformId,
                  decoration: const InputDecoration(labelText: 'Plataforma'),
                  items: provider.platforms.map((p) => DropdownMenuItem<int>(value: p['id'], child: Text(p['name']))).toList(),
                  onChanged: (v) {
                    platformId = v!;
                    platName = provider.platforms.firstWhere((p) => p['id'] == v)['name'];
                  },
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () async {
                    setStateModal(() => searching = true);
                    results = await _api.searchTrophiesHunter(searchCtrl.text.trim(), platName);
                    setStateModal(() => searching = false);
                  },
                  child: const Text('Buscar Set'),
                ),
                if (searching)
                  const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())
                else
                  ...results.map((r) => ListTile(
                        title: Text(r['name'] ?? '', style: const TextStyle(fontSize: 12)),
                        subtitle: Text('${r['achievementCount']} logros'),
                        trailing: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            await _api.importTrophiesHunterUrl(g.id, platformId, r['url']);
                            _loadAll();
                          },
                          child: const Text('Importar'),
                        ),
                      )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(int id, String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.panel,
        title: const Text('¿Eliminar Juego?'),
        content: Text('Esta acción borrará permanentemente "$name" de la Base de Datos SQL.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () async {
              HapticFeedback.heavyImpact();
              Navigator.pop(context);
              await context.read<LibraryProvider>().deleteGame(id);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}