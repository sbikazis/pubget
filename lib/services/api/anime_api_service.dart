import 'dart:convert';
import 'package:http/http.dart' as http;

class AnimeApiService {
  AnimeApiService._();

  static const String _baseUrl = 'https://api.jikan.moe/v4';


  //  Validate Anime Exists

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


  //  Validate Character Exists Inside Anime

  static Future<bool> validateCharacterExists({
    required String animeName,
    required String characterName,
  }) async {
    final url =
        Uri.parse('$_baseUrl/characters?q=$characterName&limit=5');

    final response = await http.get(url);

    if (response.statusCode != 200) {
      return false;
    }

    final data = jsonDecode(response.body);

    if (data['data'] == null ||
        data['data'].isEmpty) {
      return false;
    }

    for (final character in data['data']) {
      final animeList = character['anime'];

      if (animeList == null) continue;

      for (final anime in animeList) {
        final title =
            anime['anime']['title']
                .toString()
                .toLowerCase();

        if (title.contains(
            animeName.toLowerCase())) {
          return true;
        }
      }
    }

    return false;
  }


  //  Get Character Image

  static Future<String?> getCharacterImage(
      String characterName) async {
    final url =
        Uri.parse('$_baseUrl/characters?q=$characterName&limit=1');

    final response = await http.get(url);

    if (response.statusCode != 200) {
      return null;
    }

    final data = jsonDecode(response.body);

    if (data['data'] == null ||
        data['data'].isEmpty) {
      return null;
    }

    return data['data'][0]['images']?['jpg']
        ['image_url'];
  }
}

