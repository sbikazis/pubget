import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/services/api/anime_api_service.dart';

void main() {
  test('exact character name gets the highest match score', () {
    final exact = AnimeApiService.scoreCharacterNameMatch(
      'Sasuke Uchiha',
      'Sasuke Uchiha',
    );
    final close = AnimeApiService.scoreCharacterNameMatch(
      'Sasuke Uchiha',
      'Sasuke Uchihi',
    );

    expect(exact, greaterThan(close));
    expect(exact, greaterThan(0));
    expect(close, greaterThan(0));
  });

  test('partial queries still match when the words are relevant', () {
    final score = AnimeApiService.scoreCharacterNameMatch(
      'Naruto Uzumaki',
      'Naruto',
    );

    expect(score, greaterThan(0));
  });
}
