import 'dart:math' as math;

/// Error types tracked by the analyzer and the learner model.
class ErrorType {
  const ErrorType._();

  static const reversal = 'reversal';
  static const vowelSub = 'vowel_sub';
  static const otherSub = 'other_sub';
  static const omission = 'omission';
  static const insertion = 'insertion';
  static const transposition = 'transposition';

  static const all = [reversal, vowelSub, otherSub, omission, insertion, transposition];
}

/// Mirror/rotation look-alike pairs (counted as reversals).
const Map<String, String> mirrorLetters = {
  'b': 'd', 'd': 'b', 'p': 'q', 'q': 'p', 'm': 'w', 'w': 'm', 'n': 'u', 'u': 'n',
};

const _vowels = {'a', 'e', 'i', 'o', 'u'};

class ErrorAnalysis {
  ErrorAnalysis({
    required this.editDistance,
    required this.counts,
    required this.targetGraphemeError,
  });

  /// Nothing to analyse (correct answer or no wrong answer given).
  factory ErrorAnalysis.none() => ErrorAnalysis(
        editDistance: 0,
        counts: {for (final t in ErrorType.all) t: 0},
        targetGraphemeError: false,
      );

  final int editDistance;
  final Map<String, int> counts;
  final bool targetGraphemeError;

  int count(String type) => counts[type] ?? 0;

  Map<String, Object?> toJson() =>
      {'editDistance': editDistance, ...counts, 'targetGraphemeError': targetGraphemeError};
}

/// Aligns [answer] to [target] with an edit distance that also allows
/// adjacent swaps (optimal string alignment), backtraces the operations and
/// classifies each one.
ErrorAnalysis analyzeErrors(String target, String answer, String targetGrapheme) {
  final t = target.toLowerCase();
  final a = answer.toLowerCase();
  final n = t.length, m = a.length;

  final d = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
  for (var i = 0; i <= n; i++) {
    d[i][0] = i;
  }
  for (var j = 0; j <= m; j++) {
    d[0][j] = j;
  }
  bool swapAt(int i, int j) =>
      i > 1 && j > 1 && t[i - 1] == a[j - 2] && t[i - 2] == a[j - 1] && t[i - 1] != t[i - 2];

  for (var i = 1; i <= n; i++) {
    for (var j = 1; j <= m; j++) {
      final cost = t[i - 1] == a[j - 1] ? 0 : 1;
      var best = math.min(math.min(d[i - 1][j] + 1, d[i][j - 1] + 1), d[i - 1][j - 1] + cost);
      if (swapAt(i, j)) best = math.min(best, d[i - 2][j - 2] + 1);
      d[i][j] = best;
    }
  }

  final counts = {for (final type in ErrorType.all) type: 0};
  final span = graphemeSpan(t, targetGrapheme);
  var targetError = false;
  bool inSpan(int index) => span != null && index >= span.$1 && index <= span.$2;

  var i = n, j = m;
  while (i > 0 || j > 0) {
    if (i > 0 && j > 0 && t[i - 1] == a[j - 1] && d[i][j] == d[i - 1][j - 1]) {
      i--;
      j--; // match
    } else if (swapAt(i, j) && d[i][j] == d[i - 2][j - 2] + 1) {
      counts[ErrorType.transposition] = counts[ErrorType.transposition]! + 1;
      if (inSpan(i - 2) || inSpan(i - 1)) targetError = true;
      i -= 2;
      j -= 2;
    } else if (i > 0 && j > 0 && d[i][j] == d[i - 1][j - 1] + 1) {
      final type = _substitutionType(t[i - 1], a[j - 1]);
      counts[type] = counts[type]! + 1;
      if (inSpan(i - 1)) targetError = true;
      i--;
      j--;
    } else if (i > 0 && d[i][j] == d[i - 1][j] + 1) {
      counts[ErrorType.omission] = counts[ErrorType.omission]! + 1;
      if (inSpan(i - 1)) targetError = true;
      i--;
    } else {
      // Extra letter inserted before target position i.
      counts[ErrorType.insertion] = counts[ErrorType.insertion]! + 1;
      if (span != null && i > span.$1 && i <= span.$2) targetError = true;
      j--;
    }
  }

  // No target sound (tricky / longer words): the whole word is the target.
  if (span == null) targetError = d[n][m] > 0;
  return ErrorAnalysis(editDistance: d[n][m], counts: counts, targetGraphemeError: targetError);
}

String _substitutionType(String expected, String given) {
  if (mirrorLetters[expected] == given) return ErrorType.reversal;
  if (_vowels.contains(expected) && _vowels.contains(given)) return ErrorType.vowelSub;
  return ErrorType.otherSub;
}

/// Start/end index (inclusive) of the first target-grapheme option found in
/// the word. "a_e" style options are split digraphs (a + any letter + e).
(int, int)? graphemeSpan(String word, String targetGrapheme) {
  if (targetGrapheme.trim().isEmpty) return null;
  for (final raw in targetGrapheme.split('|')) {
    final option = raw.trim().toLowerCase();
    if (option.isEmpty) continue;
    if (option.contains('_')) {
      final match = RegExp(option.replaceAll('_', '[a-z]')).firstMatch(word);
      if (match != null) return (match.start, match.end - 1);
    } else {
      final index = word.indexOf(option);
      if (index >= 0) return (index, index + option.length - 1);
    }
  }
  return null;
}
