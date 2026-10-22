/// One Sinhala akshara as the child builds it: a base letter (consonant or
/// independent vowel) plus the pilla marks placed on it.
///
/// Marks are kept as the child sees them: a vowel sign (ා ි ු ෙ ො …), the
/// hal kirima (්), the bindu (ං), or the joined forms yansaya (්‍ය) and
/// rakaransaya (්‍ර), which are one mark each even though they are three
/// code points.
class Akshara {
  const Akshara(this.base, [this.marks = const []]);

  final String base;
  final List<String> marks;

  static const zwj = '‍';
  static const hal = '්';
  static const yansaya = '$hal$zwjය';
  static const rakaransaya = '$hal$zwjර';

  /// Splits one akshara ("පූ", "ෂ්‍ය", "සිං") into base + marks.
  factory Akshara.parse(String text) {
    final s = text.trim();
    final marks = <String>[];
    var i = 1;
    while (i < s.length) {
      if (s[i] == hal && i + 2 < s.length && s[i + 1] == zwj) {
        marks.add(s.substring(i, i + 3)); // ්‍ය or ්‍ර
        i += 3;
      } else {
        marks.add(s[i]);
        i++;
      }
    }
    return Akshara(s.substring(0, 1), marks);
  }

  /// Order marks must be written in: joined forms, then the vowel sign or
  /// hal, then the bindu / visarga.
  static int markOrder(String mark) => switch (mark) {
        yansaya || rakaransaya => 0,
        'ං' || 'ඃ' => 2,
        _ => 1,
      };

  /// The written akshara, whatever order the marks were placed in.
  static String compose(String base, Iterable<String> marks) {
    final sorted = [...marks]..sort((a, b) => markOrder(a).compareTo(markOrder(b)));
    return base + sorted.join();
  }

  String get text => compose(base, marks);

  /// True for a pilla mark, false for a base letter.
  static bool isMark(String tile) {
    if (tile.isEmpty) return false;
    final c = tile.codeUnitAt(0);
    return c == 0x0D82 || c == 0x0D83 || (c >= 0x0DCA && c <= 0x0DDF) || c == 0x0DF2 || c == 0x0DF3;
  }

  /// A mark as shown on its own tile: on a dotted circle, the usual way to
  /// write a pilla by itself (◌ා).
  static String markLabel(String mark) => '◌$mark';

  /// Puts a dotted circle under every pilla that has no letter before it, so
  /// text like "ඉස්පිල්ල ි" shows "ඉස්පිල්ල ◌ි" instead of a pilla hanging
  /// next to a space. Pillas on letters (පූසා) are unchanged.
  static String showMarks(String text) {
    final out = StringBuffer();
    var prev = 0;
    for (final rune in text.runes) {
      final ch = String.fromCharCode(rune);
      final afterLetter = (prev >= 0x0D85 && prev <= 0x0DC6) || isMark(String.fromCharCode(prev)) || prev == 0x200D;
      if (isMark(ch) && !afterLetter) out.write('◌');
      out.write(ch);
      prev = rune;
    }
    return out.toString();
  }

  @override
  String toString() => text;
}
