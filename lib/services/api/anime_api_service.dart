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
      debugPrint("❌ API Error (SearchAnime): $e"); 
      return null;
    }
  }

  // =========================================================
  // ✅ الدالة المطورة: جلب معرفات السلسلة الكاملة (Franchise IDs)
  // =========================================================
  static Future<List<int>> getAnimeFranchiseIds(int malId) async {
    try {
      final url = Uri.parse('$_baseUrl/anime/$malId/relations');
      final response = await http.get(url, headers: _headers).timeout(
        const Duration(seconds: 10),
      );

      Set<int> ids = {malId}; // نبدأ بالمعرف الأساسي

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List relations = data['data'] ?? [];
        
        for (var relation in relations) {
          final List entries = relation['entry'] ?? [];
          for (var entry in entries) {
            if (entry['type'] == 'anime') {
              ids.add(entry['mal_id']);
            }
          }
        }
      }
      return ids.toList();
    } catch (e) {
      debugPrint("❌ API Error (getAnimeFranchiseIds): $e");
      return [malId];
    }
  }

  // =========================================================
  // ✅ التعديل الجوهري: جلب تفاصيل السلسلة كاملة (Relations + Search)
  // =========================================================
  static Future<List<Map<String, dynamic>>> getAnimeFranchiseFullDetails(int malId, String animeName) async {
    try {
      Set<int> processedIds = {malId};
      List<Map<String, dynamic>> franchiseParts = [];

      // 1. جلب بيانات الأنمي الأساسي أولاً
      final mainAnime = await searchAnimeById(malId);
      if (mainAnime != null) franchiseParts.add(mainAnime);

      // 2. جلب العلاقات المباشرة (Relations)
      final relUrl = Uri.parse('$_baseUrl/anime/$malId/relations');
      final relResponse = await http.get(relUrl, headers: _headers).timeout(const Duration(seconds: 10));

      if (relResponse.statusCode == 200) {
        final data = jsonDecode(relResponse.body);
        final List relations = data['data'] ?? [];

        for (var relation in relations) {
          final List entries = relation['entry'] ?? [];
          for (var entry in entries) {
            if (entry['type'] == 'anime' && !processedIds.contains(entry['mal_id'])) {
              processedIds.add(entry['mal_id']);
              final partDetails = await searchAnimeById(entry['mal_id']);
              if (partDetails != null) franchiseParts.add(partDetails);
            }
          }
        }
      }

      // 3. ✅ البحث الذكي لجلب الأجزاء المفقودة (مثل المواسم البعيدة أو الأفلام)
      final String searchKey = animeName.split(' ').take(2).join(' ');
      final searchUrl = Uri.parse('$_baseUrl/anime').replace(queryParameters: {
        'q': searchKey,
        'limit': '15', 
      });

      final searchResponse = await http.get(searchUrl, headers: _headers).timeout(const Duration(seconds: 10));
      if (searchResponse.statusCode == 200) {
        final searchData = jsonDecode(searchResponse.body);
        final List results = searchData['data'] ?? [];
        final String sanitizedBaseName = _sanitize(searchKey);

        for (var res in results) {
          int resId = res['mal_id'];
          String resTitle = _sanitize(res['title'] ?? '');

          // التحقق من أن النتيجة تنتمي فعلاً لنفس السلسلة وليس أنمي بأسماء مشابهة
          if (!processedIds.contains(resId) && resTitle.contains(sanitizedBaseName)) {
            processedIds.add(resId);
            franchiseParts.add({
              'id': resId,
              'title': res['title'],
              // ✅ التعديل: تم تغيير small_image_url إلى large_image_url لمنع الضبابية في عرض السلسلة
              'image_url': res['images']?['jpg']?['large_image_url'] ?? 
                           res['images']?['jpg']?['image_url'],
            });
          }
        }
      }

      return franchiseParts;
    } catch (e) {
      debugPrint("❌ API Error (getAnimeFranchiseFullDetails): $e");
      return [];
    }
  }

  // دالة مساعدة لجلب أنمي معين بواسطة معرفه
  static Future<Map<String, dynamic>?> searchAnimeById(int malId) async {
    try {
      final url = Uri.parse('$_baseUrl/anime/$malId');
      final response = await http.get(url, headers: _headers).timeout(
        const Duration(seconds: 5),
      );

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body)['data'];
      return {
        'id': data['mal_id'],
        'title': data['title'],
        // ✅ التعديل: تم تغيير small_image_url إلى large_image_url لضمان أعلى جودة ممكنة
        'image_url': data['images']?['jpg']?['large_image_url'] ?? 
                     data['images']?['jpg']?['image_url'],
      };
    } catch (e) {
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
  // ✅ التعديل: فحص الشخصية في قائمة معرفات (List<int>) بدلاً من معرف واحد
  // =========================================================

  static Future<bool> validateCharacterExists({
    List<int>? animeIds, 
    required String characterName,
  }) async {
    final cleanInput = _sanitize(characterName);

    // إذا لم تكن هناك معرفات محددة، نستخدم البحث العالمي للتحقق
    if (animeIds == null || animeIds.isEmpty) {
      final globalResult = await getCharacterImage(characterName);
      return globalResult != null;
    }

    final List<String> inputWords = cleanInput.split(' ').where((w) => w.length > 1).toList();

    for (int id in animeIds) {
      try {
        final url = Uri.parse('$_baseUrl/anime/$id/characters');
        final response = await http.get(url, headers: _headers).timeout(
          const Duration(seconds: 10),
        );

        if (response.statusCode != 200) continue;

        final data = jsonDecode(response.body);
        if (data['data'] == null || data['data'].isEmpty) continue;

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
      } catch (e) {
        debugPrint("⚠️ Character Check failed for ID $id: $e");
        continue;
      }
    }
    return false;
  }

  // =========================================================
  // ✅ التحقق من الشخصية في السلسلة الكاملة (Franchise) - بحث عام
  // =========================================================

  static Future<bool> isCharacterInFranchise({
    required String animeName,
    required String characterName,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/characters').replace(queryParameters: {
        'q': characterName,
        'limit': '8',
      });

      final response = await http.get(url, headers: _headers).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode != 200) return false;
      final data = jsonDecode(response.body);
      if (data['data'] == null || data['data'].isEmpty) return false;

      final cleanAnimeName = _sanitize(animeName);
      final String firstKeyword = cleanAnimeName.split(' ').first;

      for (final charData in data['data']) {
        final List animeList = charData['anime'] ?? [];
        
        for (final animeEntry in animeList) {
          final String title = _sanitize(animeEntry['anime']?['title'] ?? '');
          
          if (title.contains(cleanAnimeName) || cleanAnimeName.contains(title) || title.contains(firstKeyword)) {
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
  // ✅ الدالة المطلوبة: جلب تفاصيل شخصية محددة داخل أنمي معين أو عالمياً
  // =========================================================
  static Future<Map<String, String>?> getCharacterDetails({
    List<int>? animeIds,
    required String characterName,
  }) async {
    // إذا كانت القائمة فارغة أو نول، نقوم بالبحث العالمي آلياً
    if (animeIds == null || animeIds.isEmpty) {
      return await searchCharacterGlobal(characterName);
    }

    final cleanInput = _sanitize(characterName);
    
    for (int id in animeIds) {
      try {
        final url = Uri.parse('$_baseUrl/anime/$id/characters');
        final response = await http.get(url, headers: _headers).timeout(
          const Duration(seconds: 10),
        );

        if (response.statusCode != 200) continue;

        final data = jsonDecode(response.body);
        if (data['data'] == null) continue;

        for (final item in data['data']) {
          final character = item['character'];
          final String apiName = character['name'] ?? '';
          final String sanitizedApiName = _sanitize(apiName);

          if (sanitizedApiName.contains(cleanInput) || cleanInput.contains(sanitizedApiName)) {
            return {
              'name': apiName, // الاسم الرسمي من MAL
              'imageUrl': character['images']?['jpg']?['image_url'] ?? '',
            };
          }
        }
      } catch (e) {
        debugPrint("⚠️ Character Detail Fetch failed for ID $id: $e");
        continue;
      }
    }
    // إذا لم يجدها في المعرفات المحددة، كحل أخير نبحث عالمياً لضمان عدم خيبة أمل المستخدم
    return await searchCharacterGlobal(characterName);
  }

  // =========================================================
  // ✅ الدالة الجديدة: البحث العالمي عن شخصية في كل MAL
  // =========================================================
  static Future<Map<String, String>?> searchCharacterGlobal(String characterName) async {
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

      final charData = data['data'][0];
      return {
        'name': charData['name'] ?? '',
        'imageUrl': charData['images']?['jpg']?['large_image_url'] ?? 
                   charData['images']?['jpg']?['image_url'] ?? '',
      };
    } catch (e) {
      debugPrint("❌ API Error (searchCharacterGlobal): $e");
      return null;
    }
  }

  // =========================================================
  // ✅ [دالة جديدة] البحث عن شخصيات متعددة لعرضها للمستخدم للاختيار
  // تُرجع قائمة بكل الشخصيات التي تطابق الاسم المُدخل
  // =========================================================
  static Future<List<Map<String, String>>> searchCharacterMultiple({
    List<int>? animeIds,
    required String characterName,
  }) async {
    final List<Map<String, String>> results = [];
    final Set<String> addedNames = {}; // لمنع التكرار
    final cleanInput = _sanitize(characterName);

    // ========================================
    // المسار 1: إذا كانت هناك معرفات أنمي محددة
    // نبحث داخل شخصيات كل أنمي في السلسلة
    // ========================================
    if (animeIds != null && animeIds.isNotEmpty) {
      for (int id in animeIds) {
        try {
          final url = Uri.parse('$_baseUrl/anime/$id/characters');
          final response = await http.get(url, headers: _headers).timeout(
            const Duration(seconds: 10),
          );

          if (response.statusCode != 200) continue;

          final data = jsonDecode(response.body);
          if (data['data'] == null) continue;

          for (final item in data['data']) {
            final character = item['character'];
            final String apiName = character['name'] ?? '';
            final String sanitizedApiName = _sanitize(apiName);

            // ✅ نضيف الشخصية فقط إذا كان اسمها يحتوي على ما كتبه المستخدم
            if (sanitizedApiName.contains(cleanInput) || cleanInput.contains(sanitizedApiName)) {
              if (!addedNames.contains(apiName)) {
                addedNames.add(apiName);
                results.add({
                  'name': apiName,
                  'imageUrl': character['images']?['jpg']?['image_url'] ?? '',
                });
              }
            }
          }
        } catch (e) {
          debugPrint("⚠️ searchCharacterMultiple failed for ID $id: $e");
          continue;
        }
      }
    }

    // ========================================
    // المسار 2: البحث العالمي دائماً
    // سواء كانت هناك معرفات أم لا، نضيف نتائج البحث العالمي
    // لضمان عدم فقدان شخصيات لم تُوجد في المسار 1
    // ========================================
    try {
      final url = Uri.parse('$_baseUrl/characters').replace(queryParameters: {
        'q': characterName,
        'limit': '8', // ✅ 8 نتائج لإعطاء المستخدم خيارات كافية
      });

      final response = await http.get(url, headers: _headers).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List globalResults = data['data'] ?? [];

        for (final charData in globalResults) {
          final String apiName = charData['name'] ?? '';
          if (apiName.isNotEmpty && !addedNames.contains(apiName)) {
            addedNames.add(apiName);
            results.add({
              'name': apiName,
              'imageUrl': charData['images']?['jpg']?['large_image_url'] ??
                          charData['images']?['jpg']?['image_url'] ?? '',
            });
          }
        }
      }
    } catch (e) {
      debugPrint("❌ API Error (searchCharacterMultiple global): $e");
    }

    return results;
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