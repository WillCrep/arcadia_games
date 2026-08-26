import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../providers/library_provider.dart';
import '../services/api_service.dart';
import '../models/series_models.dart';

class SeriesTab extends StatefulWidget {
  const SeriesTab({super.key});

  @override
  State<SeriesTab> createState() => _SeriesTabState();
}

class _SeriesTabState extends State<SeriesTab> {
  String _filter = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LibraryProvider>().loadSeries();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LibraryProvider>();
    final list = provider.seriesList.where((s) => s.name.toLowerCase().contains(_filter.toLowerCase())).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Sagas & Franquicias')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (v) => setState(() => _filter = v),
              decoration: InputDecoration(
                hintText: 'Buscar saga...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted),
                filled: true,
                fillColor: AppTheme.panel,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
              ),
            ),
          ),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
                : list.isEmpty
                    ? const Center(child: Text('No hay series registradas.', style: TextStyle(color: AppTheme.textMuted)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: list.length,
                        itemBuilder: (context, idx) {
                          final s = list[idx];
                          return InkWell(
                            onTap: () => _openSeriesDetailModal(context, s.id),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.panel,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(s.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                      ),
                                      Text('${s.completionPercent.toStringAsFixed(0)}%', style: const TextStyle(color: AppTheme.warning, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text('${s.ownedGames} de ${s.totalGames} títulos en tu colección (${s.completedGames} completados)', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                                  const SizedBox(height: 10),
                                  LinearProgressIndicator(
                                    value: s.totalGames > 0 ? (s.ownedGames / s.totalGames) : 0,
                                    backgroundColor: Colors.white10,
                                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.warning),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _openSeriesDetailModal(BuildContext context, int seriesId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SeriesDetailSheet(seriesId: seriesId),
    );
  }
}

class _SeriesDetailSheet extends StatelessWidget {
  final int seriesId;
  const _SeriesDetailSheet({required this.seriesId});

  @override
  Widget build(BuildContext context) {
    final api = ApiService();

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppTheme.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: FutureBuilder<SeriesDetail>(
        future: api.getSeriesDetail(seriesId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
          }
          final s = snapshot.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(s.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _stat('TÍTULOS', '${s.totalGames}'),
                  const SizedBox(width: 8),
                  _stat('EN COLECCIÓN', '${s.ownedGames}', color: AppTheme.cyan),
                  const SizedBox(width: 8),
                  _stat('COMPLETADOS', '${s.completedGames}', color: AppTheme.lime),
                  const SizedBox(width: 8),
                  _stat('PROGRESO', '${s.completionPercent.toStringAsFixed(0)}%', color: AppTheme.warning),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Juegos de la Saga', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.accent)),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: s.games.length,
                  itemBuilder: (context, idx) {
                    final g = s.games[idx];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.panel,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(g.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                Text(g.status, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: g.owned ? AppTheme.lime.withOpacity(0.15) : Colors.white10,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: g.owned ? AppTheme.lime.withOpacity(0.3) : Colors.transparent),
                            ),
                            child: Text(
                              g.owned ? '✓ En Colección' : '✗ Falta',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: g.owned ? AppTheme.lime : AppTheme.textMuted),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _stat(String label, String value, {Color color = AppTheme.text}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: AppTheme.panel, borderRadius: BorderRadius.circular(8)),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(fontSize: 8, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}