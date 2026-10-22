import '../engine/error_analyzer.dart';

/// Teacher-friendly name for a phonics skill.
class SkillLabel {
  const SkillLabel(this.name, this.examples, this.short);

  /// e.g. '"sh" sound'.
  final String name;

  /// e.g. 'ship, fish'.
  final String examples;

  /// Used in sentences: 'more "sh" words'.
  final String short;

  String get full => '$name ($examples)';
}

/// One entry for every phonics_skill in english_wordbank.csv.
const Map<String, SkillLabel> skillLabels = {
  'short_a': SkillLabel('Short "a" sound', 'cat, map', 'short "a"'),
  'short_e': SkillLabel('Short "e" sound', 'bed, hen', 'short "e"'),
  'short_i': SkillLabel('Short "i" sound', 'pig, sit', 'short "i"'),
  'short_o': SkillLabel('Short "o" sound', 'dog, hot', 'short "o"'),
  'short_u': SkillLabel('Short "u" sound', 'sun, cup', 'short "u"'),
  'digraph_sh': SkillLabel('"sh" sound', 'ship, fish', '"sh"'),
  'digraph_ch': SkillLabel('"ch" sound', 'chin, chip', '"ch"'),
  'digraph_th': SkillLabel('"th" sound', 'thin, bath', '"th"'),
  'ending_ck': SkillLabel('"ck" ending', 'duck, sock', '"ck"'),
  'ending_ng_nk': SkillLabel('"ng / nk" ending', 'ring, pink', '"ng / nk"'),
  'double_ff_ll_ss_zz': SkillLabel('Double letters ff, ll, ss, zz', 'bell, hill', 'double-letter'),
  'blend_initial': SkillLabel('Blends at the start', 'frog, crab', 'starting-blend'),
  'blend_final': SkillLabel('Blends at the end', 'hand, pond', 'ending-blend'),
  'magic_e_a': SkillLabel('Magic e with a', 'cake, game', 'magic e (a_e)'),
  'magic_e_i': SkillLabel('Magic e with i', 'bike, kite', 'magic e (i_e)'),
  'magic_e_o': SkillLabel('Magic e with o', 'home, bone', 'magic e (o_e)'),
  'magic_e_u': SkillLabel('Magic e with u', 'cube, tube', 'magic e (u_e)'),
  'y_long_i': SkillLabel('"y" saying "i"', 'my, fly', '"y" as in "my"'),
  'vowel_ee': SkillLabel('"ee" sound', 'tree, bee', '"ee"'),
  'vowel_ea': SkillLabel('"ea" sound', 'sea, eat', '"ea"'),
  'vowel_ai_ay': SkillLabel('"ai / ay" sound', 'rain, play', '"ai / ay"'),
  'vowel_oa_ow': SkillLabel('"oa / ow" sound', 'boat, snow', '"oa / ow"'),
  'vowel_oo_long': SkillLabel('Long "oo" sound', 'moon, zoo', 'long "oo"'),
  'vowel_oo_short': SkillLabel('Short "oo" sound', 'book, look', 'short "oo"'),
  'vowel_igh': SkillLabel('"igh" sound', 'light, night', '"igh"'),
  'vowel_ue_ew': SkillLabel('"ue / ew" sound', 'blue, new', '"ue / ew"'),
  'y_long_e': SkillLabel('"y" saying "ee"', 'baby, happy', '"y" as in "baby"'),
  'r_ar': SkillLabel('"ar" sound', 'car, star', '"ar"'),
  'r_or': SkillLabel('"or" sound', 'fork, corn', '"or"'),
  'r_er_ir_ur': SkillLabel('"er / ir / ur" sound', 'her, bird', '"er / ir / ur"'),
  'r_air_ear': SkillLabel('"air / ear" sound', 'hair, ear', '"air / ear"'),
  'diphthong_ou_ow': SkillLabel('"ou / ow" sound', 'house, cow', '"ou / ow"'),
  'diphthong_oi_oy': SkillLabel('"oi / oy" sound', 'coin, boy', '"oi / oy"'),
  'suffix_s_es': SkillLabel('Adding s or es', 'cats, boxes', '"-s / -es"'),
  'suffix_ing': SkillLabel('Adding ing', 'jumping, singing', '"-ing"'),
  'two_syllable': SkillLabel('Two-part words', 'sunset, bathtub', 'two-part'),
  'longer_words': SkillLabel('Longer words', 'monkey, parrot', 'longer'),
  'sight_words': SkillLabel('Tricky words', 'said, was', 'tricky'),
};

SkillLabel skillLabel(String skill) =>
    skillLabels[skill] ?? SkillLabel(skill.replaceAll('_', ' '), '', skill.replaceAll('_', ' '));

/// Stage names shown to teachers (0 = tricky/sight words).
const Map<int, String> stageNames = {
  0: 'Tricky words',
  1: 'Short vowel sounds',
  2: 'Letter pairs (sh, ch, th, ck)',
  3: 'Blends (fr, st, nd)',
  4: 'Magic e',
  5: 'Vowel teams (ee, ai, oa)',
  6: 'Vowel + r (ar, or, ir)',
  7: 'Endings & ou/oi',
  8: 'Longer words',
};

/// Plain names for error types (selector reasons).
const Map<String, String> errorNames = {
  ErrorType.reversal: 'Mixing up b/d or p/q',
  ErrorType.vowelSub: 'Wrong vowel',
  ErrorType.otherSub: 'Wrong letter (other)',
  ErrorType.omission: 'Missing letter',
  ErrorType.insertion: 'Extra letter',
  ErrorType.transposition: 'Letters swapped round',
};

/// Teacher-view sentences for mistake habits.
const Map<String, String> habitSentences = {
  ErrorType.reversal: 'Often mixes up b and d (or p and q)',
  ErrorType.omission: 'Often leaves out letters',
  ErrorType.vowelSub: 'Often mixes up vowel sounds',
  ErrorType.transposition: 'Sometimes swaps letter order',
  ErrorType.insertion: 'Sometimes adds extra letters',
};

// Classroom tips — to be reviewed by an expert (reading specialist /
// dyslexia teacher) before use with children.
const Map<int, String> stageTips = {
  0: 'Practise tricky words as whole shapes: say it, trace it, cover it, write it.',
  1: 'Stretch the word slowly ("c-a-t") and tap one finger for each sound.',
  2: 'Show the two letters as one sound card ("sh") and practise them together.',
  3: 'Say both sounds of the blend separately first ("f-r"), then push them together.',
  4: 'Point to the magic e and "jump" from it to the vowel: it makes the vowel say its name.',
  5: 'Teach "when two vowels go walking": sort words by their vowel-team card.',
  6: 'Use a "bossy r" picture: the r changes the vowel sound before it.',
  7: 'Clap the word into parts, then build the ending as its own card.',
  8: 'Clap the syllables and spell one part at a time.',
};

// Tips per mistake habit — to be reviewed by an expert.
const Map<String, String> errorTips = {
  ErrorType.reversal: 'For b/d: make the "bed" hand shape (two thumbs up) and check the letter against it.',
  ErrorType.omission: 'Ask the child to say the word slowly and push one counter for each sound before spelling.',
  ErrorType.vowelSub: 'Use vowel picture cards (a-apple, e-egg…) and have the child say the middle sound aloud.',
  ErrorType.transposition: 'Point under each letter while saying the sounds left to right.',
  ErrorType.insertion: 'Count the sounds together first, then check the number of letters matches.',
};
