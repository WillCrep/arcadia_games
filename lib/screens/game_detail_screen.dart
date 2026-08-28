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
import 'trophies_hunter_webview_screen.dart';

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
  String _selectedPlatformTab = 'Todas';

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
      // Asegurar que los catálogos de tiendas y plataformas de la BD estén listos
      final provider = context.read<LibraryProvider>();
      if (provider.platforms.isEmpty || provider.stores.isEmpty) {
        await provider.loadCatalogs();
      }

      final g = await _api.getGame(widget.gameId);
      final ach = await _api.getGameAchievements(widget.gameId);
      
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
      debugPrint('Error cargando detalle: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _triggerCelebration() {
    HapticFeedback.heavyImpact();
    _confettiCtrl.play();
  }

  // Identificador compuesto único para separar por Plataforma + Tienda de la BD
  String _getAchievementSetKey(AchievementItem a) {
    if (a.store != null && a.store!.isNotEmpty) {
      return '${a.platform} · ${a.store}';
    }
    return a.platform;
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

  // ================= SECCIÓN DE LOGROS MULTIPLATAFORMA + TIENDA =================
  Widget _achievementsSection(GameDetail g) {
    // 1. Extraer identificadores únicos compuestos (Plataforma + Tienda de la BD)
    final setGroups = <String>{};
    for (final a in _achievements) {
      setGroups.add(_getAchievementSetKey(a));
    }
    final setList = setGroups.toList();

    // 2. Filtrar logros según la pestaña activa
    final visibleAchievements = _selectedPlatformTab == 'Todas'
        ? _achievements
        : _achievements.where((a) => _getAchievementSetKey(a) == _selectedPlatformTab).toList();

    final totalCount = visibleAchievements.length;
    final unlockedCount = visibleAchievements.where((a) => a.unlocked).length;
    final progressPct = totalCount > 0 ? (unlockedCount / totalCount) : 0.0;

    int totalPoints = 0;
    int unlockedPoints = 0;
    bool hasPoints = false;
    String scoreSuffix = 'pts';
    for (final a in visibleAchievements) {
      if (a.points != null) {
        hasPoints = true;
        totalPoints += a.points!;
        if (a.unlocked) unlockedPoints += a.points!;
        if (a.scoreType == 'Gamerscore' || (a.tier != null && a.tier!.contains('G'))) {
          scoreSuffix = 'G';
        } else if (a.scoreType != null && a.scoreType!.contains('XP') || (a.tier != null && a.tier!.contains('XP'))) {
          scoreSuffix = 'XP';
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Logros y Trofeos (${_achievements.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _dynamicColor.withOpacity(0.2),
                foregroundColor: _dynamicColor,
                side: BorderSide(color: _dynamicColor.withOpacity(0.4)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text('Importar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              onPressed: () => _showImportOptionsModal(g),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (_achievements.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppTheme.panel, borderRadius: BorderRadius.circular(10)),
            child: const Center(
              child: Text(
                'No hay logros cargados. Pulsa "Importar" para extraerlos.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
            ),
          )
        else ...[
          // SELECTOR DE PESTAÑAS (PLATAFORMA · TIENDA)
          if (setList.length > 1) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _platformFilterPill('Todas', Icons.all_inclusive, _achievements.length, AppTheme.accent),
                  const SizedBox(width: 8),
                  ...setList.map((setKey) {
                    final count = _achievements.where((a) => _getAchievementSetKey(a) == setKey).length;
                    final color = _getPlatformColor(setKey);
                    final icon = _getPlatformIcon(setKey);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _platformFilterPill(setKey, icon, count, color),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // TARJETA DE PROGRESO DE LA PLATAFORMA/TIENDA SELECCIONADA
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.panel,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _selectedPlatformTab == 'Todas' ? Icons.emoji_events : _getPlatformIcon(_selectedPlatformTab),
                          color: _selectedPlatformTab == 'Todas' ? AppTheme.lime : _getPlatformColor(_selectedPlatformTab),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _selectedPlatformTab,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                    Text(
                      hasPoints
                        ? '$unlockedPoints / $totalPoints $scoreSuffix  ·  $unlockedCount/$totalCount'
                        : '$unlockedCount de $totalCount (${(progressPct * 100).toStringAsFixed(0)}%)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: progressPct == 1.0 ? AppTheme.lime : AppTheme.cyan,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressPct,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _selectedPlatformTab == 'Todas' ? AppTheme.lime : _getPlatformColor(_selectedPlatformTab),
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // LISTA DE LOGROS CON BADGE DE PLATAFORMA + TIENDA
          ...visibleAchievements.map((a) {
            final platColor = _getPlatformColor(a.platform);
            final tierColor = _getTierBadgeColor(a.tier);
            final storeLabel = (a.store != null && a.store!.isNotEmpty) ? ' · ${a.store}' : '';

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.panel,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: a.unlocked ? platColor.withOpacity(0.4) : AppTheme.border,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 1. Imagen Oficial del Logro
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: (a.imageUrl != null && a.imageUrl!.isNotEmpty)
                        ? CachedNetworkImage(
                            imageUrl: a.imageUrl!,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(width: 44, height: 44, color: AppTheme.panelHover),
                            errorWidget: (_, __, ___) => Container(
                              width: 44,
                              height: 44,
                              color: AppTheme.panelHover,
                              child: Icon(Icons.emoji_events_outlined, color: platColor, size: 22),
                            ),
                          )
                        : Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(color: AppTheme.panelHover, borderRadius: BorderRadius.circular(8)),
                            child: Icon(Icons.emoji_events_outlined, color: platColor, size: 22),
                          ),
                  ),
                  const SizedBox(width: 12),

                  // 2. Información: Título, Descripción y Badges
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: a.unlocked ? Colors.white : AppTheme.text,
                          ),
                        ),
                        if (a.description != null && a.description!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            a.description!,
                            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, height: 1.3),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 5,
                          runSpacing: 4,
                          children: [
                            // Badge de Plataforma y Tienda (ej. PC · Steam)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: platColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: platColor.withOpacity(0.4), width: 0.8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_getPlatformIcon(a.platform), size: 10, color: platColor),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${a.platform}$storeLabel',
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: platColor),
                                  ),
                                ],
                              ),
                            ),

                            // Badge Tier / Gamerscore (ej: 30 G, Platino, Oro)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: tierColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: tierColor.withOpacity(0.4), width: 0.8),
                              ),
                              child: Text(
                                a.tier ?? (a.points != null ? '${a.points} pts' : 'Logro'),
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: tierColor),
                              ),
                            ),

                            // Badge de Rareza %
                            if (a.rarityPercent != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${a.rarityPercent!.toStringAsFixed(2)}% rareza',
                                  style: const TextStyle(fontSize: 9, color: AppTheme.textMuted),
                                ),
                              ),

                            // Badge Diamante / Logro Raro
                            if (a.isRare)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.amber.withOpacity(0.5), width: 0.8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.diamond_outlined, size: 10, color: Colors.amber),
                                    SizedBox(width: 3),
                                    Text(
                                      'Raro',
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber),
                                    ),
                                  ],
                                ),
                              ),

                            // Badge Perdible
                            if (a.isMissable)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: AppTheme.danger.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppTheme.danger.withOpacity(0.4), width: 0.8),
                                ),
                                child: const Text(
                                  'Perdible',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.danger),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 3. Checkbox Interactivo
                  Checkbox(
                    value: a.unlocked,
                    activeColor: platColor,
                    onChanged: (val) async {
                      HapticFeedback.selectionClick();
                      setState(() => a.unlocked = val ?? false);
                      await context.read<LibraryProvider>().toggleAchievement(a.id, a.unlocked);
                      
                      if (_achievements.every((item) => item.unlocked)) {
                        _triggerCelebration();
                      }
                    },
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _platformFilterPill(String title, IconData icon, int count, Color color) {
    final isSelected = _selectedPlatformTab == title;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedPlatformTab = title);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.25) : AppTheme.panel,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? color : AppTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: isSelected ? Colors.white : color),
            const SizedBox(width: 5),
            Text(
              '$title ($count)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getPlatformColor(String platform) {
    final p = platform.toLowerCase();
    // PlayStation
    if (p.contains('playstation') || p.contains('ps')) return const Color(0xFF0070D1);
    // Xbox
    if (p.contains('xbox')) return const Color(0xFF107C10);
    // Nintendo Actual & Clásico
    if (p.contains('switch') || p.contains('wii') || p.contains('ds') || p.contains('nes')) {
      return const Color(0xFFE60012);
    }
    // Game Boy Family (Púrpura / Índigo GBA clásico)
    if (p.contains('game boy') || p.contains('gba') || p.contains('gbc') || p.contains('gb')) {
      return const Color(0xFF6366F1);
    }
    // Sega
    if (p.contains('sega') || p.contains('genesis') || p.contains('dreamcast') || p.contains('saturn')) {
      return const Color(0xFF0055A5);
    }
    // PC & Tiendas
    if (p.contains('ea') || p.contains('origin')) return const Color(0xFFFF5400);
    if (p.contains('steam')) return const Color(0xFF66C0F4);
    if (p.contains('epic')) return const Color(0xFFF5F5F5);
    if (p.contains('gog')) return const Color(0xFF9B51E0);
    if (p.contains('pc')) return const Color(0xFF38BDF8);
    // Retro / Arcade / Otros
    if (p.contains('retro') || p.contains('arcade') || p.contains('atari')) return const Color(0xFFF59E0B);
    return AppTheme.cyan;
  }

  IconData _getPlatformIcon(String platform) {
    final p = platform.toLowerCase();
    if (p.contains('playstation') || p.contains('ps')) return Icons.sports_esports_rounded;
    if (p.contains('xbox')) return Icons.videogame_asset_rounded;
    if (p.contains('switch')) return Icons.gamepad_rounded;
    if (p.contains('game boy') || p.contains('gba') || p.contains('gb')) return Icons.developer_board_rounded;
    if (p.contains('steam') || p.contains('pc')) return Icons.laptop_chromebook_rounded;
    if (p.contains('retro') || p.contains('arcade') || p.contains('snes') || p.contains('genesis')) {
      return Icons.cruelty_free;
    }
    return Icons.album;
  }


  Color _getTierBadgeColor(String? tier) {
    if (tier == null) return AppTheme.cyan;
    final t = tier.toLowerCase();
        // PlayStation Trophies
    if (t.contains('platino') || t.contains('platinum')) return const Color(0xFFE5E4E2); // Platino brillante
    if (t.contains('oro') || t.contains('gold')) return AppTheme.warning;                // Oro
    if (t.contains('plata') || t.contains('silver')) return const Color(0xFFC0C0C0);     // Plata
    if (t.contains('bronce') || t.contains('bronze')) return const Color(0xFFCD7F32);    // Bronce
    
    // Xbox Gamerscore
    if (t.contains('g') || t.contains('gamerscore')) return AppTheme.lime;               // Verde Xbox
    
    // EA Play / Origin XP & Epic XP (Naranja EA)
    if (t.contains('xp')) return const Color(0xFFFF5400);

    // GOG & Steam Tiers
    if (t.contains('muy raro') || t.contains('ultra')) return const Color(0xFFA855F7);    // Púrpura épico
    if (t.contains('poco com')) return const Color(0xFF38BDF8);                          // Celeste
    if (t.contains('raro') || t.contains('rare')) return AppTheme.warning;               // Ámbar
    if (t.contains('com')) return const Color(0xFF94A3B8);                               // Gris neutro
    return AppTheme.cyan;
  }

void _showImportOptionsModal(GameDetail g) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Gestión de Logros & Trofeos',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 12),

              // 1. Scraper TrophiesHunter
              ListTile(
                leading: const Icon(Icons.travel_explore, color: AppTheme.cyan),
                title: const Text('Scraper TrophiesHunter (URL directa o Buscador)'),
                subtitle: const Text(
                  'Extrae logros asociándolos a consola y tienda',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _openTrophiesHunterDialog(g);
                },
              ),

              // 2. Subir Archivo JSON Local
              ListTile(
                leading: const Icon(Icons.folder_open, color: AppTheme.accent),
                title: const Text('Subir Archivo JSON Local'),
                subtitle: const Text(
                  'Carga un archivo .json desde tu celular',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _importJsonFile(g.id);
                },
              ),

              // 3. Traducir con Groq IA (Aparece si el juego ya tiene logros guardados)
              if (_achievements.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.translate_rounded, color: AppTheme.lime),
                  title: const Text('Traducir logros actuales con IA (Groq)'),
                  subtitle: const Text(
                    'Traduce al español los nombres y descripciones ya guardados',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    HapticFeedback.lightImpact();

                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text('Traduciendo logros al español con Groq IA...'),
                        backgroundColor: AppTheme.accent,
                      ),
                    );

                    try {
                      final count = await _api.translateExistingAchievements(g.id);
                      _triggerCelebration();
                      if (mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text('¡$count logros traducidos al español con éxito!'),
                            backgroundColor: AppTheme.lime,
                          ),
                        );
                        _loadAll();
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text('Error al traducir con IA: $e'),
                            backgroundColor: AppTheme.danger,
                          ),
                        );
                      }
                    }
                  },
                ),
            ],
          ),
        ),
      ),
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
    int? platformId = provider.platforms.isNotEmpty ? provider.platforms.first['id'] as int : null;
    int? storeId = provider.stores.isNotEmpty ? provider.stores.first['id'] as int : null;
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
            // 1. Selector de Plataforma Dinámico desde BD
            DropdownButtonFormField<int>(
              value: platformId,
              decoration: const InputDecoration(labelText: 'Plataforma'),
              items: provider.platforms.map((p) => DropdownMenuItem<int>(
                value: p['id'] as int,
                child: Text(p['name'] as String),
              )).toList(),
              onChanged: (v) => platformId = v,
            ),
            const SizedBox(height: 8),

            // 2. Selector de Tienda Dinámico desde BD (dbo.Stores)
            DropdownButtonFormField<int>(
              value: storeId,
              decoration: const InputDecoration(labelText: 'Tienda (Desde BD)'),
              items: provider.stores.map((s) => DropdownMenuItem<int>(
                value: s['id'] as int,
                child: Text(s['name'] as String),
              )).toList(),
              onChanged: (v) => storeId = v,
            ),
            const SizedBox(height: 8),

            TextField(controller: editionCtrl, decoration: const InputDecoration(labelText: 'Edición')),
            const SizedBox(height: 8),

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
                await context.read<LibraryProvider>().addCollectionEntry(
                  gameId,
                  platformId!,
                  storeId!,
                  editionCtrl.text.trim(),
                  format,
                );
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

  // ================= MODAL CON TIENDAS DINÁMICAS DESDE AZURE SQL =================
  void _openTrophiesHunterDialog(GameDetail g) {
    final urlCtrl = TextEditingController(text: 'https://trophieshunter.com/es/games/');
    final provider = context.read<LibraryProvider>();

    int platformId = provider.platforms.isNotEmpty ? provider.platforms.first['id'] as int : 1;
    int? storeId; // Opcional (null = Sin tienda específica)

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.panel,
          title: const Row(
            children: [
              Icon(Icons.auto_awesome, color: AppTheme.cyan, size: 20),
              SizedBox(width: 8),
              Text('Scraper TrophiesHunter', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Selector de Plataforma Dinámico desde BD
              DropdownButtonFormField<int>(
                value: platformId,
                decoration: const InputDecoration(labelText: 'Plataforma Destino'),
                items: provider.platforms.map((p) => DropdownMenuItem<int>(
                  value: p['id'] as int,
                  child: Text(p['name'] as String),
                )).toList(),
                onChanged: (v) => setModalState(() => platformId = v!),
              ),
              const SizedBox(height: 10),

              // 2. Selector de Tienda Dinámico desde BD (dbo.Stores)
              DropdownButtonFormField<int?>(
                value: storeId,
                decoration: const InputDecoration(labelText: 'Tienda (Desde tu BD)'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Sin tienda específica'),
                  ),
                  ...provider.stores.map((s) => DropdownMenuItem<int?>(
                    value: s['id'] as int,
                    child: Text(s['name'] as String),
                  )),
                ],
                onChanged: (v) => setModalState(() => storeId = v),
              ),
              const SizedBox(height: 10),

              // 3. URL de TrophiesHunter
              TextField(
                controller: urlCtrl,
                decoration: const InputDecoration(
                  labelText: 'URL de TrophiesHunter',
                  hintText: 'https://trophieshunter.com/es/games/...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancelar')),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
              icon: const Icon(Icons.travel_explore, size: 16),
              label: const Text('Abrir y Extraer'),
              onPressed: () async {
                final url = urlCtrl.text.trim();
                if (url.isEmpty || !url.startsWith('http')) return;

                Navigator.pop(dialogCtx); // Cerrar diálogo

                final count = await Navigator.push<int>(
                  this.context,
                  MaterialPageRoute(
                    builder: (_) => TrophiesHunterWebViewScreen(
                      gameId: g.id,
                      initialUrl: url,
                      platformId: platformId,
                      storeId: storeId,
                    ),
                  ),
                );

                if (!mounted) return;

                if (count != null && count > 0) {
                  _triggerCelebration();
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text('¡$count logros importados con éxito!'), backgroundColor: AppTheme.lime),
                  );
                  _loadAll();
                }
              },
            ),
          ],
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