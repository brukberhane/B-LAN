import 'package:blan/core/search/search_tokenizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('indexTokens includes full words and infix substrings', () {
    final tokens = SearchTokenizer.indexTokens('My-Video_File.mp4');
    expect(tokens, contains('video'));
    expect(tokens, contains('file'));
    expect(tokens, contains('mp4'));
    expect(tokens, contains('vid'));
    expect(tokens, contains('ideo'));
  });

  test('indexTokens indexes subwords inside a word', () {
    final tokens = SearchTokenizer.indexTokens('little');
    expect(tokens, contains('lit'));
    expect(tokens, contains('itt'));
    expect(tokens, contains('tle'));
    expect(tokens.contains('life'), isFalse);
  });

  test('queryTerms splits query words without prefix expansion', () {
    expect(SearchTokenizer.queryTerms('   '), isEmpty);
    expect(SearchTokenizer.queryTerms('HELLO'), ['hello']);
    expect(SearchTokenizer.queryTerms('life'), ['life']);
    expect(SearchTokenizer.queryTerms('little life'), ['little', 'life']);
  });

  test('matchesAllTerms requires every query word in haystack', () {
    const haystack = 'a little life.m4b books/a little life.m4b';
    expect(SearchTokenizer.matchesAllTerms(haystack, ['life']), isTrue);
    expect(SearchTokenizer.matchesAllTerms(haystack, ['little', 'life']), isTrue);
    expect(SearchTokenizer.matchesAllTerms(haystack, ['itt']), isTrue);
    expect(SearchTokenizer.matchesAllTerms(haystack, ['zzz']), isFalse);
  });
}
