// lib/services/api/anime_api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class AnimeApiService {
  AnimeApiService._();

  static const String _baseUrl = 'https://api.jikan.moe/v4';

  // ✅ دالة داخلية لتنظيف النصوص والمقارنة بمرونة (Fuzzy Match)
  static String _sanitize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '') // إزالة الفواصل والرموز مثل (,)
        .trim();
  }

  // =========================================================
  // SEARCH ANIME (للحصول على الاسم الرسمي والصورة)
  // =========================================================

  static Future<Map<String, dynamic>?> searchAnime(String animeName) async {
    final url =
        Uri.parse('$_baseUrl/anime?q=$animeName&limit=1');

    final response = await http.get(url);

    if (response.statusCode != 200) {
      return null;
    }

    final data = jsonDecode(response.body);

    if (data['data'] == null || data['data'].isEmpty) {
      return null;
    }

    // نُعيد الاسم الرسمي والصورة لاعتمادهما في المجموعة
    final animeData = data['data'][0];
    return {
      'title': animeData['title'],
      'image_url': animeData['images']?['jpg']?['large_image_url'] ?? 
                   animeData['images']?['jpg']?['image_url'],
    };
  }

  // =========================================================
  // VALIDATE ANIME EXISTS
  // =========================================================

  static Future<bool> validateAnimeExists(String animeName) async {
    final url =
        Uri.parse('$_baseUrl/anime?q=$animeName&limit=1');

    final response = await http.get(url);

    if (response.statusCode != 200) {
      return false;
    }

    final data = jsonDecode(response.body);

    return data['data'] != null &&
        data['data'].isNotEmpty;
  }

  // =========================================================
  // VALIDATE CHARACTER EXISTS INSIDE ANIME (تم تحسين المنطق)
  // =========================================================

  static Future<bool> validateCharacterExists({
    required String animeName,
    required String characterName,
  }) async {
    final url =
        Uri.parse('$_baseUrl/characters?q=$characterName&limit=10');

    final response = await http.get(url);

    if (response.statusCode != 200) {
      return false;
    }

    final data = jsonDecode(response.body);

    if (data['data'] == null || data['data'].isEmpty) {
      return false;
    }

    final cleanAnime = _sanitize(animeName);
    final cleanCharacter = _sanitize(characterName);

    for (final character in data['data']) {
      final apiName = _sanitize(character['name'] ?? '');

      // ✅ تحقق أولاً من اسم الشخصية
      if (!apiName.contains(cleanCharacter) &&
          !cleanCharacter.contains(apiName)) {
        continue;
      }

      final animeList = character['anime'] as List?;
      if (animeList == null) continue;

      for (final animeItem in animeList) {
        final apiAnimeTitle =
            _sanitize(animeItem['anime']['title'].toString());

        // ✅ مقارنة مرنة للأنمي
        if (apiAnimeTitle.contains(cleanAnime) ||
            cleanAnime.contains(apiAnimeTitle)) {
          return true;
        }
      }
    }

    return false;
  }

  // =========================================================
  // GET CHARACTER IMAGE
  // =========================================================

  static Future<String?> getCharacterImage(String characterName) async {
    // نطلب أكثر من نتيجة لضمان الحصول على أدق صورة إذا كان الاسم شائعاً
    final url =
        Uri.parse('$_baseUrl/characters?q=$characterName&limit=5');

    final response = await http.get(url);

    if (response.statusCode != 200) {
      return null;
    }

    final data = jsonDecode(response.body);

    if (data['data'] == null || data['data'].isEmpty) {
      return null;
    }

    // نأخذ صورة أول نتيجة مطابقة
    return data['data'][0]['images']?['jpg']['large_image_url'] ?? 
           data['data'][0]['images']?['jpg']['image_url'];
  }
}