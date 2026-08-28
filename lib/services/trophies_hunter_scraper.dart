import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:flutter/foundation.dart';

class ScrapedAchievementSet {
  final String setName;
  final String platformName;
  final String sourceUrl;
  final List<Map<String, dynamic>> achievements;

  ScrapedAchievementSet({
    required this.setName,
    required this.platformName,
    required this.sourceUrl,
    required this.achievements,
  });
}

class TrophiesHunterScraper {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 25),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
        'Accept-Language': 'es-ES,es;q=0.9,en-US;q=0.8,en;q=0.7',
      },
    ),
  );

  /// Extrae los logros directamente desde una URL de TrophiesHunter
  Future<ScrapedAchievementSet> scrapeFromUrl(String url) async {
    final cleanUrl = url.trim();
    debugPrint('════════════════════════════════════════════════════════════');
    debugPrint('🚀 [SCRAPER INICIO] Solicitando URL: $cleanUrl');

    try {
      final response = await _dio.get(cleanUrl);
      debugPrint('📥 [SCRAPER HTTP] Código de respuesta: ${response.statusCode}');

      final htmlString = response.data.toString();
      debugPrint('📄 [SCRAPER HTML] Longitud recibida: ${htmlString.length} caracteres');
      debugPrint('🔍 [MUESTRA HTML]: ${htmlString.substring(0, htmlString.length > 500 ? 500 : htmlString.length)}...');

      final document = html_parser.parse(htmlString);

      // 1. Título
      final h1 = document.querySelector('h1')?.text.trim();
      final title = document.querySelector('title')?.text.trim();
      final setName = h1 ?? title ?? 'Conjunto de Logros';
      debugPrint('🏷️ [SCRAPER TÍTULO]: $setName');

      // 2. Plataforma
      final fullText = document.body?.text ?? '';
      final platformDetected = _detectPlatformFromTextOrUrl(cleanUrl, fullText);
      debugPrint('🎮 [SCRAPER PLATAFORMA DETECTADA]: $platformDetected');

      // 3. Extracción de Logros
      final achievements = <Map<String, dynamic>>[];
      final seenNames = <String>{};

      // Intentar múltiples selectores según la estructura de TrophiesHunter
      var elements = document.querySelectorAll('a[href*="/achievements/"], div.achievement, article, div.trophy');
      debugPrint('🔎 [SCRAPER NODOS ENCONTRADOS]: ${elements.length}');

      // Si no encuentra los selectores específicos, buscar en todos los enlaces o tarjetas
      if (elements.isEmpty) {
        elements = document.querySelectorAll('a[href*="/games/"]');
        debugPrint('🔎 [SCRAPER FALLBACK NODOS]: ${elements.length}');
      }

      for (final el in elements) {
        final nameEl = el.querySelector('h2, h3, h4, strong, span, .title');
        final name = nameEl?.text.trim() ?? el.text.trim().split('\n').first.trim();

        if (name.isEmpty || name.length < 2 || seenNames.contains(name)) continue;
        if (name.toLowerCase() == 'logros' || name.toLowerCase() == 'trofeos' || name.toLowerCase() == 'achievements') continue;

        // Descripción
        final descEl = el.querySelector('p, em, .description');
        String? description = descEl?.text.trim();
        if (description == name) description = null;

        // Imagen
        final imgEl = el.querySelector('img');
        String? imageUrl = imgEl?.attributes['src'] ?? imgEl?.attributes['data-src'];
        if (imageUrl != null && imageUrl.startsWith('//')) {
          imageUrl = 'https:$imageUrl';
        }

        final blockText = el.text;

        // Puntos / Gamerscore (ej: 25G, 25 Gamerscore, 25 Points)
        final pointsMatch = RegExp(r'(\d+)\s*(?:G|Points|pts|Gamerscore)', caseSensitive: false).firstMatch(blockText);
        int? points;
        if (pointsMatch != null) {
          points = int.tryParse(pointsMatch.group(1)!);
        }

        // Rareza %
        final rarityMatch = RegExp(r'(\d+(?:[\.,]\d+)?)%').firstMatch(blockText);
        double? rarity;
        if (rarityMatch != null) {
          rarity = double.tryParse(rarityMatch.group(1)!.replaceAll(',', '.'));
        }

        // Tier
        String? tier;
        final lower = blockText.toLowerCase();
        if (lower.contains('platino') || lower.contains('platinum')) {
          tier = 'Platino';
        } else if (lower.contains('oro') || lower.contains('gold')) {
          tier = 'Oro';
        } else if (lower.contains('plata') || lower.contains('silver')) {
          tier = 'Plata';
        } else if (lower.contains('bronce') || lower.contains('bronze')) {
          tier = 'Bronce';
        }

        String scoreType = 'Logro';
        if (platformDetected.contains('Xbox')) {
          scoreType = 'Gamerscore';
        } else if (platformDetected.contains('PlayStation')) {
          scoreType = 'Trofeo';
        }

        seenNames.add(name);

        achievements.add({
          'externalId': el.attributes['href'] ?? 'ach_${seenNames.length}',
          'name': name,
          'description': description,
          'tier': tier ?? (points != null ? '$points pts' : 'Logro'),
          'points': points,
          'rarityPercent': rarity,
          'isHidden': lower.contains('oculto') || lower.contains('hidden') || lower.contains('secret'),
          'isMissable': lower.contains('perdible') || lower.contains('missable'),
          'imageUrl': imageUrl,
          'scoreType': scoreType,
          'isRare': (rarity != null && rarity < 15.0),
        });
      }

      debugPrint('📊 [SCRAPER TOTAL LOGROS PROCESADOS]: ${achievements.length}');
      debugPrint('════════════════════════════════════════════════════════════');

      if (achievements.isEmpty) {
        throw Exception(
          'No se pudieron extraer logros. El DOM recibido no contiene elementos coincidentes.',
        );
      }

      return ScrapedAchievementSet(
        setName: setName,
        platformName: platformDetected,
        sourceUrl: cleanUrl,
        achievements: achievements,
      );
    } on DioException catch (e) {
      debugPrint('❌ [SCRAPER DIO ERROR] Status: ${e.response?.statusCode}');
      debugPrint('❌ [SCRAPER DIO ERROR DATA]: ${e.response?.data}');
      debugPrint('❌ [SCRAPER DIO ERROR MSG]: ${e.message}');
      debugPrint('════════════════════════════════════════════════════════════');
      rethrow;
    } catch (e, stack) {
      debugPrint('❌ [SCRAPER EXCEPCIÓN]: $e');
      debugPrint('❌ [STACKTRACE]: $stack');
      debugPrint('════════════════════════════════════════════════════════════');
      rethrow;
    }
  }

  String _detectPlatformFromTextOrUrl(String url, String text) {
    final lower = '$url $text'.toLowerCase();
    if (lower.contains('xbox-series') || lower.contains('xbox series')) return 'Xbox Series X|S';
    if (lower.contains('xbox-one') || lower.contains('xbox one')) return 'Xbox One';
    if (lower.contains('xbox-360') || lower.contains('xbox 360') || lower.contains('xbox')) return 'Xbox';
    if (lower.contains('ps5') || lower.contains('playstation 5') || lower.contains('playstation-5')) return 'PlayStation 5';
    if (lower.contains('ps4') || lower.contains('playstation 4') || lower.contains('playstation-4')) return 'PlayStation 4';
    if (lower.contains('ps3') || lower.contains('playstation 3')) return 'PlayStation 3';
    if (lower.contains('psvita') || lower.contains('ps-vita') || lower.contains('vita')) return 'PlayStation Vita';
    if (lower.contains('switch') || lower.contains('nintendo')) return 'Nintendo Switch';
    if (lower.contains('steam') || lower.contains('pc')) return 'PC / Steam';
    return 'General';
  }

  Future<List<Map<String, dynamic>>> searchSets(String gameName, String platformName) async {
    return [];
  }
}