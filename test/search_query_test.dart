import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/features/search/search_query.dart';

void main() {
  test('empty and short queries are not runnable', () {
    expect(SearchQuery.isRunnable(''), isFalse);
    expect(SearchQuery.isRunnable('   '), isFalse);
    expect(SearchQuery.isRunnable('a'), isFalse);
    expect(SearchQuery.isRunnable(' a '), isFalse);
  });

  test('valid queries trim, collapse whitespace, and lower-case Latin', () {
    expect(SearchQuery.prefix('  Fri  Ren  '), 'fri ren');
    expect(SearchQuery.isRunnable('ab'), isTrue);
    expect(SearchQuery.normalize('  hello   world  '), 'hello world');
  });

  test('Arabic queries keep letters and stay runnable', () {
    expect(SearchQuery.prefix('  ناروتو  '), 'ناروتو');
    expect(SearchQuery.isRunnable('من'), isTrue);
    expect(SearchQuery.prefix('Naruto ناروتو'), 'naruto ناروتو');
  });

  test('query length is capped', () {
    final long = 'n' * 120;
    expect(SearchQuery.prefix(long).length, SearchQuery.maxLength);
    expect(SearchQuery.normalize(long).length, SearchQuery.maxLength);
  });
}
