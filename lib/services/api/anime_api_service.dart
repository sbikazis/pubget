import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class AnimeApiService {
  AnimeApiService._();

  static const String _baseUrl = 'https://api.jikan.moe/v4';

  // ✅ Headers لضمان استقرار الطلب
  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // ✅ تحسين دالة التنظيف لتكون أكثر ذكاءً (تتعامل مع الأسماء اليابانية والإنجليزية والرموز)
  static String _sanitize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ') // استبدال الرموز بمسافات
        .replaceAll(RegExp(r'\s+'), ' ') // إزالة المسافات المزدوجة
        .trim();
  }

  // =========================================================
  // SEARCH ANIME
  // =========================================================

  static Future<Map<String, dynamic>?> searchAnime(String animeName) async {
    try {
      final url = Uri.parse('$_baseUrl/anime').replace(queryParameters: {
        'q': animeName,
        'limit': '1',
      });

      final response = await http.get(url, headers: _headers).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      if (data['data'] == null || data['data'].isEmpty) return null;

      final animeData = data['data'][0];
      return {
        'id': animeData['mal_id'], 
        'title': animeData['title'],
        'image_url': animeData['images']?['jpg']?['large_image_url'] ??
                     animeData['images']?['jpg']?['image_url'],
      };
    } catch (e) {
      debugPrint("❌ API Error (SearchAnime): $e");
      return null;
    }
  }

  // =========================================================
  // VALIDATE ANIME EXISTS
  // =========================================================

  static Future<bool> validateAnimeExists(String animeName) async {
    try {
      final url = Uri.parse('$_baseUrl/anime').replace(queryParameters: {
        'q': animeName,
        'limit': '1',
      });
      
      final response = await http.get(url, headers: _headers).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode != 200) return false;
      final data = jsonDecode(response.body);
      return data['data'] != null && data['data'].isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // =========================================================
  // VALIDATE CHARACTER EXISTS (يعتمد على ID الأنمي)
  // =========================================================

  static Future<bool> validateCharacterExists({
    required dynamic animeId, 
    required String characterName,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/anime/$animeId/characters');

      final response = await http.get(url, headers: _headers).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode != 200) return false;

      final data = jsonDecode(response.body);
      if (data['data'] == null || data['data'].isEmpty) return false;

      final cleanInput = _sanitize(characterName);
      final List<String> inputWords = cleanInput.split(' ').where((w) => w.length > 1).toList();

      for (final item in data['data']) {
        final character = item['character'];
        final apiName = _sanitize(character['name'] ?? '');
       
        if (apiName.contains(cleanInput) || cleanInput.contains(apiName)) {
          return true;
        }

        if (inputWords.isNotEmpty && inputWords.every((word) => apiName.contains(word))) {
          return true;
        }
      }
     
      return false;
    } catch (e) {
      return false;
    }
  }

  // =========================================================
  // ✅ التعديل الذهبي: التحقق من الشخصية في السلسلة الكاملة (Ultra-Smart Franchise Check)
  // تم رفع الـ limit إلى 15 وإضافة مطابقة كلمات مفتاحية صارمة (Kimetsu / Demon Slayer)
  // =========================================================

  static Future<bool> isCharacterInFranchise({
    required dynamic animeId,
    required String animeName,
    required String characterName,
  }) async {
    try {
      // 1. البحث عن الشخصية بنطاق أوسع (15 نتيجة) لضمان عدم تفويتها
      final url = Uri.parse('$_baseUrl/characters').replace(queryParameters: {
        'q': characterName,
        'limit': '15', 
      });

      final response = await http.get(url, headers: _headers).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode != 200) return false;
      final data = jsonDecode(response.body);
      if (data['data'] == null || data['data'].isEmpty) return false;

      final String cleanTargetAnime = _sanitize(animeName);
      final int targetId = int.tryParse(animeId.toString()) ?? -1;
      final String inputCharName = _sanitize(characterName);

      // 2. فحص النتائج بعمق (ID + الاسم + الكلمات المفتاحية)
      for (final charData in data['data']) {
        final String apiCharName = _sanitize(charData['name'] ?? '');
        
        // التحقق من أن النتيجة تخص الشخصية المطلوبة فعلاً
        if (!apiCharName.contains(inputCharName) && !inputCharName.contains(apiCharName)) continue;

        final List animeList = charData['anime'] ?? [];
        for (final animeEntry in animeList) {
          final animeInfo = animeEntry['anime'];
          if (animeInfo == null) continue;

          final int entryMalId = animeInfo['mal_id'] ?? 0;
          final String entryTitle = _sanitize(animeInfo['title'] ?? '');

          // أ) المطابقة بالـ ID (الأكثر دقة)
          if (entryMalId == targetId) return true;

          // ب) المطابقة بالاسم الكامل
          if (entryTitle.contains(cleanTargetAnime) || cleanTargetAnime.contains(entryTitle)) return true;

          // ج) المطابقة بالكلمات المفتاحية الصارمة (لحل مشكلة اختلاف أسماء المواسم)
          bool hasKeywordMatch = false;
          if (cleanTargetAnime.contains("kimetsu") && entryTitle.contains("kimetsu")) hasKeywordMatch = true;
          if (cleanTargetAnime.contains("demon slayer") && entryTitle.contains("demon slayer")) hasKeywordMatch = true;
          
          if (hasKeywordMatch) return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint("❌ API Error (isCharacterInFranchise): $e");
      return false;
    }
  }

  // =========================================================
  // GET CHARACTER IMAGE (SEARCH-BASED)
  // =========================================================

  static Future<String?> getCharacterImage(String characterName) async {
    try {
      final url = Uri.parse('$_baseUrl/characters').replace(queryParameters: {
        'q': characterName,
        'limit': '1',
      });

      final response = await http.get(url, headers: _headers).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      if (data['data'] == null || data['data'].isEmpty) return null;

      return data['data'][0]['images']?['jpg']?['large_image_url'] ??
             data['data'][0]['images']?['jpg']?['image_url'];
    } catch (e) {
      debugPrint("❌ API Error (GetCharacterImage): $e");
      return null;
    }
  }
}