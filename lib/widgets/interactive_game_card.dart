import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/app_theme.dart';

class InteractiveGameCard extends StatefulWidget {
  final dynamic game;
  final VoidCallback onTap;

  const InteractiveGameCard({
    super.key,
    required this.game,
    required this.onTap,
  });

  @override
  State<InteractiveGameCard> createState() => _InteractiveGameCardState();
}

class _InteractiveGameCardState extends State<InteractiveGameCard> with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  double _tiltX = 0;
  double _tiltY = 0;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _onPointerMove(PointerMoveEvent event, Size size) {
    final x = event.localPosition.dx / size.width - 0.5;
    final y = event.localPosition.dy / size.height - 0.5;
    setState(() {
      _tiltX = -y * 0.15; // Inclinación vertical
      _tiltY = x * 0.15;  // Inclinación horizontal
    });
  }

  void _resetTilt() {
    setState(() {
      _tiltX = 0;
      _tiltY = 0;
      _isPressed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Listener(
          onPointerMove: (e) => _onPointerMove(e, Size(constraints.maxWidth, constraints.maxHeight)),
          onPointerUp: (_) => _resetTilt(),
          onPointerCancel: (_) => _resetTilt(),
          child: GestureDetector(
            onTapDown: (_) {
              HapticFeedback.lightImpact();
              setState(() => _isPressed = true);
            },
            onTapUp: (_) {
              _resetTilt();
              widget.onTap();
            },
            onTapCancel: _resetTilt,
            child: AnimatedScale(
              scale: _isPressed ? 0.96 : 1.0,
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOutQuad,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001) // Perspectiva 3D
                  ..rotateX(_tiltX)
                  ..rotateY(_tiltY),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.panel,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _isPressed ? AppTheme.accent : AppTheme.border,
                      width: _isPressed ? 1.5 : 1.0,
                    ),
                    boxShadow: _isPressed
                        ? [BoxShadow(color: AppTheme.accent.withOpacity(0.35), blurRadius: 18, spreadRadius: 1)]
                        : [const BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Carátula Hero
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                              child: game.coverUrl != null
                                  ? Hero(
                                      tag: 'cover_${game.id}',
                                      child: CachedNetworkImage(
                                        imageUrl: game.coverUrl!,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) => Container(color: AppTheme.panelHover),
                                        errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
                                      ),
                                    )
                                  : Container(color: AppTheme.panelHover, child: const Icon(Icons.gamepad)),
                            ),
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Text(
                                  game.status,
                                  style: const TextStyle(color: AppTheme.cyan, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Info
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              game.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    game.seriesName ?? (game.genres.isNotEmpty ? game.genres.first : 'Sin serie'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                                  ),
                                ),
                                if (game.achievementTotal > 0)
                                  Text('${game.achievementUnlocked}/${game.achievementTotal}', style: const TextStyle(fontSize: 10, color: AppTheme.lime, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            LinearProgressIndicator(
                              value: game.progressPercent,
                              backgroundColor: Colors.white10,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
                              minHeight: 3,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}