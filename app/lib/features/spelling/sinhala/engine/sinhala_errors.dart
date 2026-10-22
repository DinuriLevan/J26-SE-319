import 'dart:math' as math;

import '../data/akshara.dart';

/// The kinds of Sinhala spelling mistakes the game recognises.
class SinhalaError {
  const SinhalaError._();

  /// The akshara needs a pilla but has none (පුසා → පසා).
  static const pillaMissing = 'pilla_missing';

  /// A different pilla, or one that does not belong (පූ → පා).
  static const pillaWrong = 'pilla_wrong';

  /// The short and long form of the same pilla (ි/ී, ු/ූ, ැ/ෑ, ෙ/ේ, ො/ෝ).
  static const pillaLength = 'pilla_length';

  /// The hal kirima (්) left out or added (බත් → බත).
  static const hal = 'hal';

  /// A look-alike or sound-alike letter (බ/භ, ද/ධ, ල/ළ, න/ණ, ද/ඳ).
  static const lookalike = 'lookalike';

  /// Any other wrong letter.
  static const otherLetter = 'other_letter';

  /// A whole akshara left out.
  static const missing = 'missing';

  /// An extra akshara.
  static const extra = 'extra';

  /// Two aksharas swapped.
  static const order = 'order';

  static const all = [pillaMissing, pillaWrong, pillaLength, hal, lookalike, otherLetter, missing, extra, order];

  /// Short ↔ long pillas.
  static const lengthPairs = {
    'ි': 'ී', 'ී': 'ි', // ි ී
    'ු': 'ූ', 'ූ': 'ු', // ු ූ
    'ැ': 'ෑ', 'ෑ': 'ැ', // ැ ෑ
    'ෙ': 'ේ', 'ේ': 'ෙ', // ෙ ේ
    'ො': 'ෝ', 'ෝ': 'ො', // ො ෝ
  };

  /// Letters children often confuse: alpaprana/mahaprana, dental/retroflex,
  /// plain/prenasal (sanyaka), and short/long independent vowels.
  static const confusableGroups = [
    'කඛ', 'ගඝඟ', 'චඡ', 'ජඣ', 'ටඨ', 'ඩඪඬ', 'තථ', 'දධඳ', 'පඵ', 'බභඹ', 'මඹ',
    'නණ', 'ලළ', 'සශෂ', 'අආ', 'ඇඈ', 'ඉඊ', 'උඌ', 'එඒ', 'ඔඕ',
  ];

  static bool confusable(String a, String b) =>
      confusableGroups.any((g) => g.contains(a) && g.contains(b));
}

/// What went wrong in one answer: a count per [SinhalaError] type.
class SinhalaErrorReport {
  SinhalaErrorReport(this.counts);

  final Map<String, int> counts;

  int count(String type) => counts[type] ?? 0;
  bool get isEmpty => counts.values.every((n) => n == 0);
}

/// Compares the child's aksharas with the word's, akshara by akshara (edit
/// distance with swaps), and names each difference. [lookalikes] adds the
/// word's own confusable letters from the word bank.
SinhalaErrorReport analyzeSinhala(
  List<Akshara> target,
  List<Akshara> answer, {
  Iterable<String> lookalikes = const [],
}) {
  final counts = {for (final t in SinhalaError.all) t: 0};
  final t = [for (final a in target) a.text];
  final a = [for (final x in answer) x.text];
  final n = t.length, m = a.length;

  // Damerau–Levenshtein table; a substitution of a near-miss akshara is cheaper
  // than delete + insert, so "පුසා" for "පූසා" aligns පු with පූ.
  final d = List.generate(n + 1, (i) => List<double>.filled(m + 1, 0));
  for (var i = 0; i <= n; i++) {
    d[i][0] = i.toDouble();
  }
  for (var j = 0; j <= m; j++) {
    d[0][j] = j.toDouble();
  }
  double subCost(int i, int j) {
    if (t[i] == a[j]) return 0;
    return target[i].base == answer[j].base ? 0.5 : 1;
  }

  for (var i = 1; i <= n; i++) {
    for (var j = 1; j <= m; j++) {
      var best = math.min(d[i - 1][j] + 1, d[i][j - 1] + 1);
      best = math.min(best, d[i - 1][j - 1] + subCost(i - 1, j - 1));
      if (i > 1 && j > 1 && t[i - 1] == a[j - 2] && t[i - 2] == a[j - 1] && t[i - 1] != t[i - 2]) {
        best = math.min(best, d[i - 2][j - 2] + 1);
      }
      d[i][j] = best;
    }
  }

  final confusable = {...lookalikes};
  var i = n, j = m;
  while (i > 0 || j > 0) {
    if (i > 0 && j > 0 && d[i][j] == d[i - 1][j - 1] + subCost(i - 1, j - 1)) {
      if (t[i - 1] != a[j - 1]) {
        final type = _substitution(target[i - 1], answer[j - 1], confusable);
        counts[type] = counts[type]! + 1;
      }
      i--;
      j--;
    } else if (i > 1 && j > 1 && t[i - 1] == a[j - 2] && t[i - 2] == a[j - 1] && d[i][j] == d[i - 2][j - 2] + 1) {
      counts[SinhalaError.order] = counts[SinhalaError.order]! + 1;
      i -= 2;
      j -= 2;
    } else if (i > 0 && d[i][j] == d[i - 1][j] + 1) {
      counts[SinhalaError.missing] = counts[SinhalaError.missing]! + 1;
      i--;
    } else {
      counts[SinhalaError.extra] = counts[SinhalaError.extra]! + 1;
      j--;
    }
  }
  return SinhalaErrorReport(counts);
}

String _substitution(Akshara target, Akshara answer, Set<String> lookalikes) {
  if (target.base != answer.base) {
    final alike = SinhalaError.confusable(target.base, answer.base) ||
        (lookalikes.contains(answer.base) && !Akshara.isMark(answer.base));
    return alike ? SinhalaError.lookalike : SinhalaError.otherLetter;
  }
  // Same letter, different pillas.
  String? vowel(Akshara x) {
    for (final m in x.marks) {
      if (Akshara.markOrder(m) == 1) return m;
    }
    return null;
  }

  final tv = vowel(target), av = vowel(answer);
  if (tv == Akshara.hal || av == Akshara.hal) return SinhalaError.hal;
  if (tv != null && av == null) return SinhalaError.pillaMissing;
  if (tv != null && av != null && SinhalaError.lengthPairs[tv] == av) return SinhalaError.pillaLength;
  // Joined forms or bindu left out, or a different / extra vowel sign.
  if (answer.marks.length < target.marks.length && tv == av) return SinhalaError.pillaMissing;
  return SinhalaError.pillaWrong;
}
