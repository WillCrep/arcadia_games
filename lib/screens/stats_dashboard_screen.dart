import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/app_theme.dart';
import '../providers/library_provider.dart';

class StatsDashboardScreen extends StatefulWidget {
  const StatsDashboardScreen({super.key});

  @override
  State<StatsDashboardScreen> createState() => _StatsDashboardScreenState();
}

class _StatsDashboardScreenState extends State<StatsDashboardScreen> {
  int _touchedBacklogIndex = -1;
  int _touchedPlatformIndex = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LibraryProvider>().loadCollection();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LibraryProvider>();
    final games = provider.games;
    final collection = provider.collectionList;
    final stats = provider.stats;

    // 1. Conteo de Estados
    final statusCounts = <String, int>{};
    for (final g in games) {
      statusCounts[g.status] = (statusCounts[g.status] ?? 0) + 1;
    }

    // 2. Conteo de Géneros
    final genreCounts = <String, int>{};
    for (final g in games) {
      for (final genre in g.genres) {
        genreCounts[genre] = (genreCounts[genre] ?? 0) + 1;
      }
    }

    // 3. Conteo de Plataformas y Formato
    final platformCounts = <String, int>{};
    final formatCounts = <String, int>{'Digital': 0, 'Físico': 0};
    for (final c in collection) {
      platformCounts[c.platform] = (platformCounts[c.platform] ?? 0) + 1;
      final fmt = (c.format != null && c.format!.toLowerCase().contains('físico')) ? 'Físico' : 'Digital';
      formatCounts[fmt] = (formatCounts[fmt] ?? 0) + 1;
    }

    // 4. Métricas Clave
    double totalHours = 0;
    int ratedGames = 0;
    double sumRating = 0;
    for (final g in games) {
      if (g.playTimeHours != null) totalHours += g.playTimeHours!;
      if (g.myRating != null) {
        ratedGames++;
        sumRating += g.myRating!;
      }
    }
    final avgRating = ratedGames > 0 ? (sumRating / ratedGames).toStringAsFixed(1) : '—';
    final completedCount = statusCounts['Completado'] ?? 0;
    final completionRate = games.isNotEmpty ? (completedCount / games.length * 100).toStringAsFixed(0) : '0';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Centro de Telemetría Gamer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.cyan),
            onPressed: () {
              HapticFeedback.lightImpact();
              provider.loadStats();
              provider.loadGames();
              provider.loadCollection();
            },
          ),
        ],
      ),
      body: games.isEmpty && collection.isEmpty
          ? const Center(child: Text('No hay datos registrados aún.', style: TextStyle(color: AppTheme.textMuted)))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. HERO KPI CARDS
                  Row(
                    children: [
                      _heroKpi('HORAS JUGADAS', '${totalHours.toStringAsFixed(1)}h', Icons.timer, AppTheme.accent),
                      const SizedBox(width: 8),
                      _heroKpi('NOTA MEDIA', avgRating == '—' ? '—' : '$avgRating★', Icons.star_rate_rounded, AppTheme.warning),
                      const SizedBox(width: 8),
                      _heroKpi('COMPLETISMO', '$completionRate%', Icons.verified_rounded, AppTheme.lime),
                    ],
                  ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1, end: 0),
                  const SizedBox(height: 18),

                  // 2. RADAR CHART DE ADN GAMER
                  _buildGamerDnaSection(genreCounts, games.length)
                      .animate().fadeIn(delay: 100.ms, duration: 400.ms).slideY(begin: 0.05, end: 0),
                  const SizedBox(height: 18),

                  // 3. DONA INTERACTIVA: ESTADOS DEL BACKLOG
                  _buildInteractiveBacklogChart(statusCounts, games.length)
                      .animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(begin: 0.05, end: 0),
                  const SizedBox(height: 18),

                  // 4. DONA INTERACTIVA: COPIAS POR PLATAFORMA
                  _buildInteractivePlatformChart(platformCounts, collection.length)
                      .animate().fadeIn(delay: 300.ms, duration: 400.ms).slideY(begin: 0.05, end: 0),
                  const SizedBox(height: 18),

                  // 5. PROPORCIÓN DIGITAL VS FÍSICO
                  if (collection.isNotEmpty)
                    _buildFormatBeamSection(formatCounts, collection.length)
                        .animate().fadeIn(delay: 350.ms, duration: 400.ms).slideY(begin: 0.05, end: 0),
                  if (collection.isNotEmpty) const SizedBox(height: 18),

                  // 6. TOP JUEGOS CON MÁS HORAS
                  _buildTopPlayedSection(games)
                      .animate().fadeIn(delay: 400.ms, duration: 400.ms).slideY(begin: 0.05, end: 0),
                  const SizedBox(height: 18),

                  // 7. RATIO GLOBAL DE TROFEOS
                  _buildTrophiesSummaryCard(stats)
                      .animate().fadeIn(delay: 450.ms, duration: 400.ms).slideY(begin: 0.05, end: 0),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _heroKpi(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: AppTheme.panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.35)),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 9, color: AppTheme.textMuted, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _buildGamerDnaSection(Map<String, int> genreCounts, int totalGames) {
    final sorted = genreCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topGenres = sorted.take(6).toList();

    return _cardContainer(
      title: 'ADN Gamer (Afinidad de Géneros)',
      subtitle: 'Tu perfil de juego según categorías registradas',
      child: topGenres.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('Importa juegos de IGDB para generar tu ADN.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12))),
            )
          : Column(
              children: [
                if (topGenres.length >= 3)
                  SizedBox(
                    height: 200,
                    child: RadarChart(
                      RadarChartData(
                        radarShape: RadarShape.polygon,
                        radarBorderData: const BorderSide(color: Colors.white12, width: 1.5),
                        gridBorderData: const BorderSide(color: Colors.white10, width: 1),
                        tickBorderData: const BorderSide(color: Colors.transparent),
                        ticksTextStyle: const TextStyle(color: Colors.transparent),
                        tickCount: 3,
                        getTitle: (index, angle) {
                          if (index >= topGenres.length) return const RadarChartTitle(text: '');
                          return RadarChartTitle(
                            text: topGenres[index].key.length > 12
                                ? '${topGenres[index].key.substring(0, 10)}..'
                                : topGenres[index].key,
                            angle: angle,
                            positionPercentageOffset: 0.15,
                          );
                        },
                        titleTextStyle: const TextStyle(color: AppTheme.cyan, fontSize: 10, fontWeight: FontWeight.bold),
                        dataSets: [
                          RadarDataSet(
                            fillColor: AppTheme.accent.withOpacity(0.35),
                            borderColor: AppTheme.accent,
                            borderWidth: 2.5,
                            dataEntries: topGenres
                                .map((e) => RadarEntry(value: e.value.toDouble()))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                ...topGenres.map((e) {
                  final pct = totalGames > 0 ? (e.value / totalGames) : 0.0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(e.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            Text('${e.value} títulos (${(pct * 100).toStringAsFixed(0)}%)', style: const TextStyle(fontSize: 11, color: AppTheme.cyan, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct.clamp(0.05, 1.0),
                            backgroundColor: Colors.white10,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
    );
  }

  Widget _buildInteractiveBacklogChart(Map<String, int> statusCounts, int totalGames) {
    final entries = statusCounts.entries.toList();

    return _cardContainer(
      title: 'Distribución del Backlog',
      subtitle: 'Toca una sección para inspeccionar',
      child: statusCounts.isEmpty
          ? const SizedBox()
          : SizedBox(
              height: 200,
              child: Row(
                children: [
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            pieTouchData: PieTouchData(
                              touchCallback: (event, response) {
                                if (!event.isInterestedForInteractions || response == null || response.touchedSection == null) {
                                  setState(() => _touchedBacklogIndex = -1);
                                  return;
                                }
                                final idx = response.touchedSection!.touchedSectionIndex;
                                if (_touchedBacklogIndex != idx) {
                                  HapticFeedback.selectionClick();
                                  setState(() => _touchedBacklogIndex = idx);
                                }
                              },
                            ),
                            sectionsSpace: 3,
                            centerSpaceRadius: 42,
                            sections: entries.asMap().entries.map((mapEntry) {
                              final idx = mapEntry.key;
                              final e = mapEntry.value;
                              final isTouched = idx == _touchedBacklogIndex;
                              final color = _getStatusColor(e.key);

                              return PieChartSectionData(
                                color: color,
                                value: e.value.toDouble(),
                                title: isTouched ? '${e.value}' : '',
                                radius: isTouched ? 48 : 38,
                                titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                              );
                            }).toList(),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_touchedBacklogIndex >= 0 && _touchedBacklogIndex < entries.length) ...[
                              Text('${entries[_touchedBacklogIndex].value}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _getStatusColor(entries[_touchedBacklogIndex].key))),
                              Text(entries[_touchedBacklogIndex].key, style: const TextStyle(fontSize: 9, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                            ] else ...[
                              Text('$totalGames', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const Text('TOTAL', style: TextStyle(fontSize: 9, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: entries.asMap().entries.map((mapEntry) {
                      final idx = mapEntry.key;
                      final e = mapEntry.value;
                      final isTouched = idx == _touchedBacklogIndex;

                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _touchedBacklogIndex = isTouched ? -1 : idx);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Container(
                                width: isTouched ? 12 : 9,
                                height: isTouched ? 12 : 9,
                                decoration: BoxDecoration(color: _getStatusColor(e.key), shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${e.key} (${e.value})',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isTouched ? FontWeight.bold : FontWeight.normal,
                                  color: isTouched ? Colors.white : AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInteractivePlatformChart(Map<String, int> platformCounts, int totalCopies) {
    final entries = platformCounts.entries.toList();

    return _cardContainer(
      title: 'Copias por Plataforma',
      subtitle: 'Distribución de tus plataformas en colección',
      child: platformCounts.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: Text('No has registrado copias en tu colección.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12))),
            )
          : SizedBox(
              height: 200,
              child: Row(
                children: [
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            pieTouchData: PieTouchData(
                              touchCallback: (event, response) {
                                if (!event.isInterestedForInteractions || response == null || response.touchedSection == null) {
                                  setState(() => _touchedPlatformIndex = -1);
                                  return;
                                }
                                final idx = response.touchedSection!.touchedSectionIndex;
                                if (_touchedPlatformIndex != idx) {
                                  HapticFeedback.selectionClick();
                                  setState(() => _touchedPlatformIndex = idx);
                                }
                              },
                            ),
                            sectionsSpace: 3,
                            centerSpaceRadius: 42,
                            sections: entries.asMap().entries.map((mapEntry) {
                              final idx = mapEntry.key;
                              final e = mapEntry.value;
                              final isTouched = idx == _touchedPlatformIndex;
                              final color = _getPlatformColor(e.key);

                              return PieChartSectionData(
                                color: color,
                                value: e.value.toDouble(),
                                title: isTouched ? '${e.value}' : '',
                                radius: isTouched ? 48 : 38,
                                titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                              );
                            }).toList(),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_touchedPlatformIndex >= 0 && _touchedPlatformIndex < entries.length) ...[
                              Text('${entries[_touchedPlatformIndex].value}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _getPlatformColor(entries[_touchedPlatformIndex].key))),
                              Text(entries[_touchedPlatformIndex].key, style: const TextStyle(fontSize: 9, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                            ] else ...[
                              Text('$totalCopies', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.cyan)),
                              const Text('COPIAS', style: TextStyle(fontSize: 9, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: entries.asMap().entries.map((mapEntry) {
                          final idx = mapEntry.key;
                          final e = mapEntry.value;
                          final isTouched = idx == _touchedPlatformIndex;

                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _touchedPlatformIndex = isTouched ? -1 : idx);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Container(
                                    width: isTouched ? 12 : 9,
                                    height: isTouched ? 12 : 9,
                                    decoration: BoxDecoration(color: _getPlatformColor(e.key), shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      '${e.key} (${e.value})',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isTouched ? FontWeight.bold : FontWeight.normal,
                                        color: isTouched ? Colors.white : AppTheme.textMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFormatBeamSection(Map<String, int> formatCounts, int total) {
    final dig = formatCounts['Digital'] ?? 0;
    final fis = formatCounts['Físico'] ?? 0;
    final digPct = total > 0 ? (dig / total * 100).toStringAsFixed(0) : '0';
    final fisPct = total > 0 ? (fis / total * 100).toStringAsFixed(0) : '0';

    return _cardContainer(
      title: 'Formato de la Colección',
      subtitle: 'Proporción entre copias Físicas y Digitales',
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.cloud_done, color: AppTheme.cyan, size: 16),
                  const SizedBox(width: 4),
                  Text('Digital: $dig ($digPct%)', style: const TextStyle(color: AppTheme.cyan, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              Row(
                children: [
                  Text('Físico: $fis ($fisPct%)', style: const TextStyle(color: AppTheme.warning, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  const Icon(Icons.album, color: AppTheme.warning, size: 16),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: total > 0 ? (dig / total) : 0.5,
              backgroundColor: AppTheme.warning,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.cyan),
              minHeight: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopPlayedSection(List<dynamic> games) {
    final sorted = List.from(games)..sort((a, b) => (b.playTimeHours ?? 0.0).compareTo(a.playTimeHours ?? 0.0));
    final top5 = sorted.take(5).where((g) => (g.playTimeHours ?? 0.0) > 0).toList();

    return _cardContainer(
      title: 'Top Juegos Más Jugados',
      subtitle: 'Ranking por horas dedicadas',
      child: top5.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.hourglass_empty_rounded, color: AppTheme.textMuted, size: 26),
                    SizedBox(height: 6),
                    Text('Aún no has registrado horas jugadas.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    Text('Edita la ficha de un juego para registrar tus horas.', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                  ],
                ),
              ),
            )
          : Column(
              children: top5.asMap().entries.map((entry) {
                final idx = entry.key;
                final g = entry.value;
                final hours = g.playTimeHours ?? 0.0;
                final maxHours = top5.first.playTimeHours ?? 1.0;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: idx == 0 ? AppTheme.warning : (idx == 1 ? Colors.grey.shade400 : (idx == 2 ? const Color(0xFFCD7F32) : Colors.white10)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${idx + 1}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: idx < 3 ? Colors.black : Colors.white70,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: Text(g.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: maxHours > 0 ? (hours / maxHours).clamp(0.05, 1.0) : 0.1,
                            backgroundColor: Colors.white10,
                            valueColor: AlwaysStoppedAnimation<Color>(idx == 0 ? AppTheme.accent : AppTheme.cyan),
                            minHeight: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 44,
                        child: Text('${hours.toStringAsFixed(1)}h', textAlign: TextAlign.end, style: const TextStyle(fontSize: 11, color: AppTheme.cyan, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildTrophiesSummaryCard(Map<String, dynamic> stats) {
    final unlocked = stats['unlocked'] ?? 0;
    final total = stats['achievements'] ?? 0;
    final pct = total > 0 ? (unlocked / total) : 0.0;

    return _cardContainer(
      title: 'Ratio Global de Trofeos',
      subtitle: 'Progreso total hacia la maestría 100%',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.emoji_events, color: AppTheme.lime, size: 18),
                  const SizedBox(width: 6),
                  Text('$unlocked Desbloqueados', style: const TextStyle(color: AppTheme.lime, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              Text('Total: $total (${(pct * 100).toStringAsFixed(1)}%)', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.lime),
              minHeight: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardContainer({required String title, required String subtitle, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Nuevo': return AppTheme.accent;
      case 'Jugando': return AppTheme.cyan;
      case 'Por jugar': return AppTheme.warning;
      case 'Completado': return AppTheme.lime;
      case 'Pausado': return const Color(0xFF6366F1);
      case 'Abandonado': return AppTheme.danger;
      default: return Colors.blueGrey;
    }
  }

  Color _getPlatformColor(String platform) {
    final p = platform.toLowerCase();
    if (p.contains('playstation') || p.contains('ps')) return const Color(0xFF0070D1);
    if (p.contains('xbox')) return const Color(0xFF107C10);
    if (p.contains('switch') || p.contains('nintendo')) return const Color(0xFFE60012);
    if (p.contains('steam') || p.contains('pc')) return const Color(0xFF66C0F4);
    if (p.contains('epic')) return const Color(0xFFF5F5F5);
    if (p.contains('gog')) return const Color(0xFF9B51E0);
    return AppTheme.accent;
  }
}