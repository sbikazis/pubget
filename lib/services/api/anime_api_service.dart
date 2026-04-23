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

  // ✅ تحسين دالة التنظيف لتكون أكثر مرونة في المقارنة
  static String _sanitize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ') // استبدال الرموز بمسافة وليس حذفها تماماً لمنع دمج الكلمات
        .replaceAll(RegExp(r'\s+'), ' ') // تقليص المسافات الزائدة
        .trim();
  }

  // =========================================================
  // SEARCH ANIME
  // =========================================================

  static Future<Map<String, dynamic>?> searchAnime(String animeName) async {
    try {
      // ✅ التعديل: استخدام Uri.https لضمان عمل الـ Encoding بشكل آلي ومنع أخطاء الـ Socket
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
      debugPrint("❌ API Error (SearchAnime): $e"); // ✅ إضافة سجل للأخطاء للمتابعة
      return null;
    }
  }

  // =========================================================
  // ✅ الدالة الجديدة: جلب كافة معرفات السلسلة (Franchise IDs)
  // تقوم بجلب الـ Relations (الأجزاء، الأفلام، الأوفا) لتخزينها عند الإنشاء
  // =========================================================
  static Future<List<int>> getAnimeFranchiseIds(int malId) async {
    try {
      final url = Uri.parse('$_baseUrl/anime/$malId/relations');
      final response = await http.get(url, headers: _headers).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode != 200) return [malId];

      final data = jsonDecode(response.body);
      final List relations = data['data'] ?? [];
      
      // نستخدم Set لتجنب التكرار ثم نحوله لـ List
      Set<int> allIds = {malId};

      for (var relation in relations) {
        final List entries = relation['entry'] ?? [];
        for (var entry in entries) {
          if (entry['type'] == 'anime') {
            allIds.add(entry['mal_id']);
          }
        }
      }
      return allIds.toList();
    } catch (e) {
      debugPrint("❌ API Error (getAnimeFranchiseIds): $e");
      return [malId]; // في حال الفشل نكتفي بالـ ID الأساسي
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
  // ✅ الدالة السابقة: التحقق من الشخصية في السلسلة الكاملة (B-Plan)
  // =========================================================

  static Future<bool> isCharacterInFranchise({
    required String animeName,
    required String characterName,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/characters').replace(queryParameters: {
        'q': characterName,
        'limit': '5', 
      });

      final response = await http.get(url, headers: _headers).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode != 200) return false;
      final data = jsonDecode(response.body);
      if (data['data'] == null || data['data'].isEmpty) return false;

      final cleanAnimeName = _sanitize(animeName);

      for (final charData in data['data']) {
        final List animeList = charData['anime'] ?? [];
        
        for (final animeEntry in animeList) {
          final String title = _sanitize(animeEntry['anime']?['title'] ?? '');
          
          if (title.contains(cleanAnimeName) || cleanAnimeName.contains(title)) {
            return true;
          }
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