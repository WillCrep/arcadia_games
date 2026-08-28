import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../core/app_theme.dart';
import '../services/api_service.dart';

class TrophiesHunterWebViewScreen extends StatefulWidget {
  final int gameId;
  final String initialUrl;
  final int platformId;
  final int? storeId;

  const TrophiesHunterWebViewScreen({
    super.key,
    required this.gameId,
    required this.initialUrl,
    required this.platformId,
    this.storeId,
  });

  @override
  State<TrophiesHunterWebViewScreen> createState() => _TrophiesHunterWebViewScreenState();
}

class _TrophiesHunterWebViewScreenState extends State<TrophiesHunterWebViewScreen> {
  late final WebViewController _controller;
  final ApiService _api = ApiService();
  bool _isLoadingPage = true;
  bool _isExtracting = false;
  String _currentUrl = '';

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.initialUrl;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() {
              _currentUrl = url;
              _isLoadingPage = true;
            });
          },
          onPageFinished: (url) {
            setState(() {
              _currentUrl = url;
              _isLoadingPage = false;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  Future<void> _extractAndImport() async {
    setState(() => _isExtracting = true);
    HapticFeedback.mediumImpact();

    try {
      const jsCode = r'''
      (function() {
        const list = [];
        const seen = new Set();

        const metaContainers = document.querySelectorAll('.game-achievement-meta-container');
        
        for (const meta of metaContainers) {
          let row = meta.parentElement;
          while (row && row !== document.body && !row.querySelector('img')) {
            row = row.parentElement;
          }
          if (!row) row = meta.parentElement;

          // 1. TÍTULO REAL
          const allLinks = Array.from(row.querySelectorAll('a[href*="/achievements/"], a[href*="/games/"]'));
          const titleLink = allLinks.find(a => !meta.contains(a));
          
          let name = '';
          if (titleLink) {
            name = titleLink.innerText.trim();
          }
          if (!name) {
            const headings = Array.from(row.querySelectorAll('h2, h3, h4, strong, .title, [class*="title"]'));
            const heading = headings.find(h => !meta.contains(h));
            if (heading) name = heading.innerText.trim();
          }

          if (!name || name.length < 2) continue;
          name = name.split('\n')[0].trim();
          
          const lowerName = name.toLowerCase();
          if (['ordenar', 'filtrar', 'buscar', 'logros', 'trofeos', 'achievements', 'guías', 'guias', 'comentarios'].includes(lowerName)) {
            continue;
          }
          if (lowerName.endsWith('guías') || lowerName.endsWith('guias')) continue;

          if (seen.has(name)) continue;
          seen.add(name);

          // 2. DESCRIPCIÓN REAL
          const paragraphs = Array.from(row.querySelectorAll('p, em, .description, [class*="description"], .text-sm, span'));
          const descEl = paragraphs.find(p => !meta.contains(p) && p !== titleLink && !p.innerText.includes('Guías'));
          let description = descEl ? descEl.innerText.trim() : '';
          if (description === name) description = '';

          // 3. IMAGEN / ICONO REAL DEL LOGRO
          const img = row.querySelector('img');
          let imageUrl = img ? (img.currentSrc || img.src || img.getAttribute('data-src') || '') : '';
          if (imageUrl && imageUrl.startsWith('//')) {
            imageUrl = 'https:' + imageUrl;
          }

          // 4. METADATOS: RETROACHIEVEMENTS, XBOX, EA PLAY, PLAYSTATION, GOG, STEAM
          let points = null;
          let scoreType = 'Logro';
          let tier = null;
          let rarity = null;
          let isRare = false;
          let isHidden = false;
          let isMissable = false;

          const metaText = meta.innerText || '';
          const lowerMeta = metaText.toLowerCase();

          // A. RETROACHIEVEMENTS (GBA, SNES, N64, Retro) -> .retro-achievements-score-icon
          const retroIcon = meta.querySelector('.retro-achievements-score-icon, [class*="retro-achievements-score"], [class*="retro-score"]');
          if (retroIcon) {
            const retroContainer = retroIcon.closest('.game-achievement-meta') || retroIcon.parentElement;
            const retroText = (retroContainer ? retroContainer.innerText : '').trim();
            const retroMatch = retroText.match(/(\d+)/);
            if (retroMatch) {
              points = parseInt(retroMatch[1], 10);
              scoreType = 'RetroAchievements';
              tier = points + ' pts';
            }
          }

          // B. EA Play / Origin XP (.origin-xp-icon -> 100 XP)
          const originIcon = meta.querySelector('.origin-xp-icon, [class*="origin-xp"], [class*="origin"], [class*="ea-xp"]');
          if (originIcon && points === null) {
            const originContainer = originIcon.closest('.game-achievement-meta') || originIcon.parentElement;
            const originText = (originContainer ? originContainer.innerText : '').trim();
            const originMatch = originText.match(/(\d+)/);
            if (originMatch) {
              points = parseInt(originMatch[1], 10);
              scoreType = 'Origin XP';
              tier = points + ' XP';
            }
          }

          // C. Gamerscore de Xbox (.gamerscore-icon -> 30 G)
          const gsIcon = meta.querySelector('.gamerscore-icon, [class*="gamerscore"]');
          if (gsIcon && points === null) {
            const gsContainer = gsIcon.closest('.game-achievement-meta') || gsIcon.parentElement;
            const gsMatch = (gsContainer ? gsContainer.innerText : '').match(/(\d+)/);
            if (gsMatch) {
              points = parseInt(gsMatch[1], 10);
              scoreType = 'Gamerscore';
              tier = points + ' G';
            }
          }

          // D. Trofeos de PlayStation (Platino, Oro, Plata, Bronce)
          const platIcon = meta.querySelector('[class*="platinum"], [class*="platino"], .trophy-platinum-icon');
          const goldIcon = meta.querySelector('[class*="gold"], [class*="oro"], .trophy-gold-icon');
          const silverIcon = meta.querySelector('[class*="silver"], [class*="plata"], .trophy-silver-icon');
          const bronzeIcon = meta.querySelector('[class*="bronze"], [class*="bronce"], .trophy-bronze-icon');

          if (platIcon || lowerMeta.includes('platino')) {
            tier = 'Platino';
            scoreType = 'Trofeo';
          } else if (goldIcon || lowerMeta.includes('oro')) {
            tier = 'Oro';
            scoreType = 'Trofeo';
          } else if (silverIcon || lowerMeta.includes('plata')) {
            tier = 'Plata';
            scoreType = 'Trofeo';
          } else if (bronzeIcon || lowerMeta.includes('bronce')) {
            tier = 'Bronce';
            scoreType = 'Trofeo';
          }
          // E. Tiers de GOG / Steam / PC
          else if (lowerMeta.includes('muy raro') || lowerMeta.includes('ultra raro') || lowerMeta.includes('very rare')) {
            tier = 'Muy raro';
            scoreType = 'Logro GOG';
            isRare = true;
          } else if (lowerMeta.includes('poco común') || lowerMeta.includes('poco comun') || lowerMeta.includes('uncommon')) {
            tier = 'Poco común';
            scoreType = 'Logro GOG';
          } else if (lowerMeta.includes('raro') || lowerMeta.includes('rare')) {
            tier = 'Raro';
            scoreType = 'Logro GOG';
            isRare = true;
          } else if (lowerMeta.includes('común') || lowerMeta.includes('comun') || lowerMeta.includes('common')) {
            tier = 'Común';
            scoreType = 'Logro GOG';
          }

          // F. Puntos de Comunidad TH (Solo como respaldo si no hay nada de lo anterior)
          if (points === null && tier === null) {
            const thPointsEl = meta.querySelector('.game-achievement-points, [class*="achievement-points"]');
            if (thPointsEl) {
              const ptsMatch = thPointsEl.innerText.match(/(\d+)\s*Points/i);
              if (ptsMatch) {
                points = parseInt(ptsMatch[1], 10);
                scoreType = 'Points';
                tier = points + ' pts';
              }
            }
          }

          // G. Rareza % (.users-icon -> 2.25%)
          const usersIcon = meta.querySelector('.users-icon, [class*="users"]');
          if (usersIcon) {
            const usersContainer = usersIcon.closest('.game-achievement-meta') || usersIcon.parentElement;
            const rarityMatch = (usersContainer ? usersContainer.innerText : '').match(/(\d+(?:[\.,]\d+)?)%/);
            if (rarityMatch) {
              rarity = parseFloat(rarityMatch[1].replace(',', '.'));
            }
          }

          // H. Diamante / Logro Raro
          const diamondIcon = meta.querySelector('.diamond-icon, [class*="diamond"]');
          if (diamondIcon || (rarity !== null && rarity < 15.0) || tier === 'Raro' || tier === 'Muy raro') {
            isRare = true;
          }

          // I. Flags
          const flagsContainer = meta.querySelector('.flags') || row.querySelector('.flags');
          const flagsText = flagsContainer ? flagsContainer.outerHTML.toLowerCase() : '';

          if (flagsText.includes('secret') || flagsText.includes('oculto') || meta.hasAttribute('data-secret-achievements-target')) {
            isHidden = true;
          }
          if (flagsText.includes('missable') || flagsText.includes('perdible')) {
            isMissable = true;
          }

          const externalId = (titleLink ? titleLink.getAttribute('href') : '') || ('ach_' + seen.size);

          list.push({
            externalId: externalId,
            name: name,
            description: description || null,
            tier: tier || (points ? (points + ' pts') : 'Logro'),
            points: points,
            rarityPercent: rarity,
            isHidden: isHidden,
            isMissable: isMissable,
            imageUrl: imageUrl || null,
            scoreType: scoreType,
            isRare: isRare
          });
        }

        const titleHeader = document.querySelector('h1')?.innerText?.trim() || document.title || 'Conjunto de Logros';

        return JSON.stringify({
          setName: titleHeader,
          achievements: list
        });
      })()
      ''';

      final jsResult = await _controller.runJavaScriptReturningResult(jsCode);
      
      String jsonStr = jsResult.toString();
      if (jsonStr.startsWith('"') && jsonStr.endsWith('"')) {
        jsonStr = jsonDecode(jsonStr);
      }

      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
      final setName = parsed['setName'] ?? 'Conjunto de Logros';
      final achievements = List<Map<String, dynamic>>.from(parsed['achievements'] ?? []);

      if (achievements.isEmpty) {
        throw Exception('No se detectaron logros en esta página. Asegúrate de estar en la vista de lista de trofeos.');
      }

      final platformDetected = _detectPlatformFromUrl(_currentUrl);

      final payload = {
        'platformId': widget.platformId,
        'storeId': widget.storeId,
        'sourceUrl': _currentUrl,
        'setName': setName,
        'platform': platformDetected,
        'achievements': achievements,
      };

      await _api.importAchievementsJson(widget.gameId, payload);

      if (mounted) {
        Navigator.pop(context, achievements.length);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al extraer: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isExtracting = false);
    }
  }

  String _detectPlatformFromUrl(String url) {
    final lower = url.toLowerCase();

    // 1. CONSOLAS RETRO
    if (lower.contains('game-boy-advance') || lower.contains('gba')) return 'Game Boy Advance';
    if (lower.contains('game-boy-color') || lower.contains('gbc')) return 'Game Boy Color';
    if (lower.contains('game-boy') || lower.contains('-gb')) return 'Game Boy';
    if (lower.contains('nintendo-64') || lower.contains('n64')) return 'Nintendo 64';
    if (lower.contains('gamecube')) return 'Nintendo GameCube';
    if (lower.contains('snes') || lower.contains('super-nintendo')) return 'Super Nintendo';
    if (lower.contains('-nes')) return 'Nintendo (NES)';
    if (lower.contains('nintendo-ds') || lower.contains('-nds')) return 'Nintendo DS';
    if (lower.contains('nintendo-3ds') || lower.contains('-3ds')) return 'Nintendo 3DS';
    if (lower.contains('genesis-mega-drive') || lower.contains('mega-drive') || lower.contains('genesis')) return 'Sega Genesis';
    if (lower.contains('dreamcast')) return 'Sega Dreamcast';
    if (lower.contains('saturn')) return 'Sega Saturn';
    if (lower.contains('master-system')) return 'Sega Master System';
    if (lower.contains('game-gear')) return 'Sega Game Gear';
    if (lower.contains('arcade')) return 'Arcade';

    // 2. PLAYSTATION
    if (lower.contains('playstation-portable') || lower.contains('-psp')) return 'PSP';
    if (lower.contains('psvita') || lower.contains('ps-vita')) return 'PlayStation Vita';
    if (lower.contains('playstation-2') || lower.contains('ps2')) return 'PlayStation 2';
    if (lower.contains('playstation-3') || lower.contains('ps3')) return 'PlayStation 3';
    if (lower.contains('playstation-4') || lower.contains('ps4')) return 'PlayStation 4';
    if (lower.contains('playstation-5') || lower.contains('ps5')) return 'PlayStation 5';
    if (lower.contains('playstation')) return 'PlayStation 1';

    // 3. XBOX
    if (lower.contains('xbox-series')) return 'Xbox Series X|S';
    if (lower.contains('xbox-one')) return 'Xbox One';
    if (lower.contains('xbox-360')) return 'Xbox 360';
    if (lower.contains('xbox')) return 'Xbox';

    // 4. PC & STORES
    if (lower.contains('-ea-play') || lower.contains('origin')) return 'PC';
    if (lower.contains('-gog')) return 'PC';
    if (lower.contains('switch')) return 'Nintendo Switch';
    if (lower.contains('steam') || lower.contains('pc')) return 'PC / Steam';

    return 'General';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asistente TrophiesHunter', style: TextStyle(fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoadingPage)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppTheme.accent),
                    SizedBox(height: 12),
                    Text('Cargando página...', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(14),
        color: AppTheme.panel,
        child: SafeArea(
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: _isExtracting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.bolt, color: Colors.white),
              label: Text(
                _isExtracting ? 'Guardando en Azure SQL...' : 'Extraer e Importar estos Logros',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              onPressed: (_isLoadingPage || _isExtracting) ? null : _extractAndImport,
            ),
          ),
        ),
      ),
    );
  }
}