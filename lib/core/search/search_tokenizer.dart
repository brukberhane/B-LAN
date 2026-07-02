/// Normalizes names/paths into searchable tokens and query terms.
abstract final class SearchTokenizer {
  static const minTokenLength = 2;
  static const maxPartLength = 64;

  /// All substrings (length >= [minTokenLength]) from each name/path word.
  static List<String> indexTokens(String input) {
    final normalized = input.toLowerCase().replaceAll('\\', '/');
    final parts = normalized.split(RegExp(r'[^a-z0-9]+'));
    final tokens = <String>{};
    for (final part in parts) {
      if (part.isEmpty) {
        continue;
      }
      final word =
          part.length > maxPartLength ? part.substring(0, maxPartLength) : part;
      tokens.add(word);
      final length = word.length;
      for (var start = 0; start < length; start++) {
        for (var len = minTokenLength; len <= length - start; len++) {
          tokens.add(word.substring(start, start + len));
        }
      }
    }
    return tokens.toList()..sort();
  }

  /// Query split into lowercase terms; no prefix expansion.
  static List<String> queryTerms(String query) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return const [];
    }
    return trimmed
        .split(RegExp(r'[^a-z0-9]+'))
        .where((part) => part.length >= minTokenLength)
        .toList();
  }

  static String normalizeHaystack(String name, String relativePath) =>
      '$name $relativePath'.toLowerCase().replaceAll('\\', '/');

  static bool matchesAllTerms(String haystack, List<String> terms) =>
      terms.every(haystack.contains);
}
