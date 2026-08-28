import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/app_theme.dart';
import '../providers/library_provider.dart';
import '../models/game_models.dart';
import 'game_detail_screen.dart';

class CollectionTab extends StatefulWidget {
  const CollectionTab({super.key});

  @override
  State<CollectionTab> createState() => _CollectionTabState();
}

class _CollectionTabState extends State<CollectionTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedPlatform = 'Todas';
  String _selectedFormat = 'Todos'; // 'Todos', 'Digital', 'Físico'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LibraryProvider>().loadCollection();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LibraryProvider>();
    final allCopies = provider.collectionList;

    // 1. Extraer plataformas únicas dinámicamente tal como vienen de la BD
    final platformCounts = <String, int>{'Todas': allCopies.length};
    int physicalCount = 0;
    int digitalCount = 0;

    for (final c in allCopies) {
      final plat = c.platform.trim();
      if (plat.isNotEmpty) {
        platformCounts[plat] = (platformCounts[plat] ?? 0) + 1;
      }

      final isPhys = c.format != null && c.format!.toLowerCase().contains('físico');
      if (isPhys) {
        physicalCount++;
      } else {
        digitalCount++;
      }
    }

    // 2. Si la plataforma seleccionada ya no existe, volver a 'Todas'
    if (!platformCounts.containsKey(_selectedPlatform)) {
      _selectedPlatform = 'Todas';
    }

    // 3. Filtrado dinámico
    final filteredCopies = allCopies.where((c) {
      final matchesSearch = _searchCtrl.text.isEmpty ||
          c.gameName.toLowerCase().contains(_searchCtrl.text.toLowerCase()) ||
          c.platform.toLowerCase().contains(_searchCtrl.text.toLowerCase()) ||
          c.store.toLowerCase().contains(_searchCtrl.text.toLowerCase()) ||
          c.edition.toLowerCase().contains(_searchCtrl.text.toLowerCase());

      final matchesPlatform = _selectedPlatform == 'Todas' ||
          c.platform.trim() == _selectedPlatform;

      final isPhys = c.format != null && c.format!.toLowerCase().contains('físico');
      final matchesFormat = _selectedFormat == 'Todos' ||
          (_selectedFormat == 'Físico' && isPhys) ||
          (_selectedFormat == 'Digital' && !isPhys);

      return matchesSearch && matchesPlatform && matchesFormat;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bóveda de Colección'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.cyan),
            tooltip: 'Recargar colección',
            onPressed: () {
              HapticFeedback.lightImpact();
              provider.loadCollection(_searchCtrl.text.trim());
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.accent,
        backgroundColor: AppTheme.panel,
        onRefresh: () async {
          HapticFeedback.lightImpact();
          await provider.loadCollection(_searchCtrl.text.trim());
        },
        child: Column(
          children: [
            // 1. BANNER RESUMEN DE COLECCIÓN (KPIs)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.accent.withOpacity(0.2), AppTheme.cyan.withOpacity(0.12), AppTheme.panel],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.accent.withOpacity(0.35)),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _summaryMetric('COPIAS', '${allCopies.length}', Icons.album, AppTheme.text),
                    Container(height: 28, width: 1, color: Colors.white12),
                    _summaryMetric('FÍSICOS', '$physicalCount', Icons.disc_full, AppTheme.warning),
                    Container(height: 28, width: 1, color: Colors.white12),
                    _summaryMetric('DIGITALES', '$digitalCount', Icons.cloud_done, AppTheme.cyan),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1, end: 0),
            ),

            // 2. BUSCADOR
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Buscar por título, edición, tienda o consola...',
                  hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted, size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18, color: AppTheme.textMuted),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {});
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

            // 3. CARRUSEL DINÁMICO DE CONSOLAS / PLATAFORMAS (CADA CONSOLA ES SU PROPIO CHIP)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: platformCounts.entries.map((e) {
                  final isSelected = _selectedPlatform == e.key;
                  final color = _getPlatformThemeColor(e.key);

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      avatar: e.key == 'Todas'
                          ? const Icon(Icons.all_inclusive, size: 16, color: Colors.white70)
                          : Icon(_getPlatformIcon(e.key), size: 15, color: isSelected ? Colors.white : color),
                      label: Text('${e.key} (${e.value})'),
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
                        setState(() => _selectedPlatform = e.key);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            // 4. SELECTOR DE FORMATO (TODOS / DIGITAL / FÍSICO)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Row(
                children: [
                  _formatPill('Todos', Icons.dashboard_outlined),
                  const SizedBox(width: 8),
                  _formatPill('Físico', Icons.album, badgeColor: AppTheme.warning),
                  const SizedBox(width: 8),
                  _formatPill('Digital', Icons.cloud_download, badgeColor: AppTheme.cyan),
                  const Spacer(),
                  Text(
                    '${filteredCopies.length} de ${allCopies.length}',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // 5. CUADRÍCULA RESPONSIVA
            Expanded(
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
                  : filteredCopies.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.album_outlined, size: 48, color: AppTheme.textMuted.withOpacity(0.5)),
                              const SizedBox(height: 10),
                              const Text('No se encontraron copias con los filtros actuales.', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 400,
                            mainAxisExtent: 106,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: filteredCopies.length,
                          itemBuilder: (context, idx) => _CollectionCard(
                            item: filteredCopies[idx],
                            onDeleted: () => provider.loadCollection(_searchCtrl.text.trim()),
                          ).animate().fadeIn(delay: (idx * 20).ms, duration: 200.ms),
                        ),
            ),
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

  Widget _formatPill(String format, IconData icon, {Color badgeColor = AppTheme.accent}) {
    final isSelected = _selectedFormat == format;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedFormat = format);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? badgeColor.withOpacity(0.2) : AppTheme.panel,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? badgeColor : AppTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: isSelected ? badgeColor : AppTheme.textMuted),
            const SizedBox(width: 5),
            Text(
              format,
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

  Color _getPlatformThemeColor(String platform) {
    final p = platform.toLowerCase();
    if (p.contains('playstation') || p.contains('ps')) return const Color(0xFF0070D1);
    if (p.contains('xbox')) return const Color(0xFF107C10);
    if (p.contains('switch') || p.contains('nintendo') || p.contains('wii') || p.contains('ds') || p.contains('nes') || p.contains('snes')) {
      return const Color(0xFFE60012);
    }
    if (p.contains('game boy') || p.contains('gba') || p.contains('gbc') || p.contains('gb')) {
      return const Color(0xFF6366F1);
    }
    if (p.contains('sega') || p.contains('genesis') || p.contains('dreamcast') || p.contains('saturn')) {
      return const Color(0xFF0055A5);
    }
    if (p.contains('ea') || p.contains('origin')) return const Color(0xFFFF5400);
    if (p.contains('steam')) return const Color(0xFF66C0F4);
    if (p.contains('epic')) return const Color(0xFFF5F5F5);
    if (p.contains('gog')) return const Color(0xFF9B51E0);
    if (p.contains('pc')) return const Color(0xFF38BDF8);
    if (p.contains('retro') || p.contains('arcade') || p.contains('atari')) return const Color(0xFFF59E0B);
    return AppTheme.cyan;
  }

  IconData _getPlatformIcon(String platform) {
    final p = platform.toLowerCase();
    if (p.contains('playstation') || p.contains('ps')) return Icons.sports_esports_rounded;
    if (p.contains('xbox')) return Icons.videogame_asset_rounded;
    if (p.contains('switch') || p.contains('nintendo')) return Icons.gamepad_rounded;
    if (p.contains('game boy') || p.contains('gba') || p.contains('gb')) return Icons.developer_board_rounded;
    if (p.contains('steam') || p.contains('pc') || p.contains('gog') || p.contains('epic')) return Icons.laptop_chromebook_rounded;
    if (p.contains('retro') || p.contains('arcade') || p.contains('snes') || p.contains('genesis')) {
      return Icons.cruelty_free;
    }
    return Icons.album;
  }
}

// ================= TARJETA DE COLECCIÓN =================
class _CollectionCard extends StatefulWidget {
  final OwnedCollectionItem item;
  final VoidCallback onDeleted;

  const _CollectionCard({required this.item, required this.onDeleted});

  @override
  State<_CollectionCard> createState() => _CollectionCardState();
}

class _CollectionCardState extends State<_CollectionCard> {
  bool _isPressed = false;

  Color _getPlatformStripeColor(String platform) {
    final p = platform.toLowerCase();
    if (p.contains('playstation') || p.contains('ps')) return const Color(0xFF0070D1);
    if (p.contains('xbox')) return const Color(0xFF107C10);
    if (p.contains('switch') || p.contains('nintendo') || p.contains('wii') || p.contains('ds') || p.contains('nes')) {
      return const Color(0xFFE60012);
    }
    if (p.contains('game boy') || p.contains('gba') || p.contains('gb')) return const Color(0xFF6366F1);
    if (p.contains('sega') || p.contains('genesis')) return const Color(0xFF0055A5);
    if (p.contains('ea') || p.contains('origin')) return const Color(0xFFFF5400);
    if (p.contains('steam')) return const Color(0xFF66C0F4);
    if (p.contains('gog')) return const Color(0xFF9B51E0);
    if (p.contains('pc')) return const Color(0xFF38BDF8);
    return AppTheme.cyan;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.item;
    final stripeColor = _getPlatformStripeColor(c.platform);
    final isPhysical = c.format != null && c.format!.toLowerCase().contains('físico');

    return AnimatedScale(
      scale: _isPressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 100),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _isPressed ? stripeColor : AppTheme.border),
          boxShadow: [
            BoxShadow(
              color: stripeColor.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4.5, color: stripeColor),
              SizedBox(
                width: 76,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    c.coverUrl != null
                        ? CachedNetworkImage(
                            imageUrl: c.coverUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(color: AppTheme.panelHover),
                            errorWidget: (_, __, ___) => Container(color: AppTheme.panelHover, child: const Icon(Icons.broken_image, size: 20)),
                          )
                        : Container(color: AppTheme.panelHover, child: const Icon(Icons.gamepad, size: 24)),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, AppTheme.panel.withOpacity(0.85)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: InkWell(
                  onTapDown: (_) => setState(() => _isPressed = true),
                  onTapCancel: () => setState(() => _isPressed = false),
                  onTap: () {
                    setState(() => _isPressed = false);
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => GameDetailScreen(gameId: c.gameId)),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.gameName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${c.platform} · ${c.store}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: stripeColor),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: isPhysical ? AppTheme.warning.withOpacity(0.15) : AppTheme.cyan.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: isPhysical ? AppTheme.warning.withOpacity(0.4) : AppTheme.cyan.withOpacity(0.4),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isPhysical ? Icons.disc_full : Icons.cloud_done,
                                    size: 10,
                                    color: isPhysical ? AppTheme.warning : AppTheme.cyan,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    isPhysical ? 'Físico' : 'Digital',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: isPhysical ? AppTheme.warning : AppTheme.cyan,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  c.edition,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 9, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.danger),
                tooltip: 'Eliminar copia',
                padding: const EdgeInsets.symmetric(horizontal: 8),
                constraints: const BoxConstraints(),
                onPressed: () => _confirmDeleteCopy(context, c),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteCopy(BuildContext context, OwnedCollectionItem copy) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.panel,
        title: const Text('¿Eliminar copia?'),
        content: Text('Se eliminará la copia "${copy.edition}" (${copy.platform}) del juego "${copy.gameName}".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () async {
              HapticFeedback.mediumImpact();
              Navigator.pop(context);
              await context.read<LibraryProvider>().deleteCollectionEntry(copy.id);
              widget.onDeleted();
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}