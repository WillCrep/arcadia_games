import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import 'library_tab.dart';
import 'collection_tab.dart';
import 'series_tab.dart';
import 'achievements_tab.dart';
import 'add_game_sheet.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = const [
    LibraryTab(),
    CollectionTab(),
    SeriesTab(),
    AchievementsTab(),
  ];

  void _openAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddGameSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Detectar si estamos en Tablet o Apaisado (ancho >= 720px)
    final isWideScreen = MediaQuery.of(context).size.width >= 720;

    return Scaffold(
      body: Row(
        children: [
          // NavigationRail Lateral para Tablets / Apaisado
          if (isWideScreen)
            NavigationRail(
              backgroundColor: AppTheme.panel,
              selectedIndex: _currentIndex,
              onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: FloatingActionButton.small(
                  backgroundColor: AppTheme.accent,
                  onPressed: _openAddSheet,
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ),
              selectedIconTheme: const IconThemeData(color: AppTheme.accent),
              unselectedIconTheme: const IconThemeData(color: AppTheme.textMuted),
              selectedLabelTextStyle: const TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.bold),
              unselectedLabelTextStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.sports_esports_outlined), selectedIcon: Icon(Icons.sports_esports), label: Text('Biblioteca')),
                NavigationRailDestination(icon: Icon(Icons.album_outlined), selectedIcon: Icon(Icons.album), label: Text('Colección')),
                NavigationRailDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view), label: Text('Sagas')),
                NavigationRailDestination(icon: Icon(Icons.emoji_events_outlined), selectedIcon: Icon(Icons.emoji_events), label: Text('Logros')),
              ],
            ),

          // Contenido de la pestaña activa
          Expanded(
            child: IndexedStack(index: _currentIndex, children: _tabs),
          ),
        ],
      ),

      // FAB en Celulares Verticales
      floatingActionButton: (!isWideScreen && _currentIndex == 0)
          ? FloatingActionButton(
              backgroundColor: AppTheme.accent,
              onPressed: _openAddSheet,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,

      // NavigationBar Inferior solo para Celulares Verticales (< 720px)
      bottomNavigationBar: isWideScreen
          ? null
          : NavigationBarTheme(
              data: NavigationBarThemeData(
                backgroundColor: AppTheme.panel,
                indicatorColor: AppTheme.accent.withOpacity(0.2),
                labelTextStyle: WidgetStateProperty.all(
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                ),
              ),
              child: NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
                destinations: const [
                  NavigationDestination(icon: Icon(Icons.sports_esports_outlined, size: 22), selectedIcon: Icon(Icons.sports_esports, color: AppTheme.accent, size: 22), label: 'Biblioteca'),
                  NavigationDestination(icon: Icon(Icons.album_outlined, size: 22), selectedIcon: Icon(Icons.album, color: AppTheme.cyan, size: 22), label: 'Colección'),
                  NavigationDestination(icon: Icon(Icons.grid_view_outlined, size: 22), selectedIcon: Icon(Icons.grid_view, color: AppTheme.warning, size: 22), label: 'Sagas'),
                  NavigationDestination(icon: Icon(Icons.emoji_events_outlined, size: 22), selectedIcon: Icon(Icons.emoji_events, color: AppTheme.lime, size: 22), label: 'Logros'),
                ],
              ),
            ),
    );
  }
}