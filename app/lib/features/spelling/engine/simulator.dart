import 'dart:math' as math;

import '../data/spelling_storage.dart';
import '../data/word_bank.dart';
import 'error_analyzer.dart';
import 'event_logger.dart';
import 'feature_extractor.dart';
import 'learner_model.dart';
import 'spelling_config.dart';
import 'spelling_engine.dart';

/// A pretend child with a hidden truth (which skills are weak), used to
/// check that the model finds the weakness.
class SimulatedChildProfile {
  const SimulatedChildProfile({
    required this.name,
    this.baseAbility = 0.9,
    this.weakSkills = const {},
    this.reversalRate = 0,
    this.learningPerWord = 0.015,
  });

  final String name;

  /// Chance of a correct first try on ordinary skills.
  final double baseAbility;

  /// Skill → chance of a correct first try (the hidden weak skills).
  final Map<String, double> weakSkills;

  /// Chance of flipping b/d or p/q in words that contain them.
  final double reversalRate;

  /// How much ability grows each time a skill is practised.
  final double learningPerWord;

  static const presets = [
    SimulatedChildProfile(
      name: 'Weak at "sh" + mixes up b/d',
      weakSkills: {'digraph_sh': 0.2},
      reversalRate: 0.6,
    ),
    SimulatedChildProfile(name: 'Weak at short vowels', weakSkills: {
      'short_a': 0.3, 'short_e': 0.25, 'short_i': 0.3, 'short_o': 0.3, 'short_u': 0.3,
    }),
    SimulatedChildProfile(name: 'Weak at magic e', weakSkills: {
      'magic_e_a': 0.25, 'magic_e_i': 0.25, 'magic_e_o': 0.25, 'magic_e_u': 0.25,
    }),
    SimulatedChildProfile(name: 'Strong child (no weak skills)', baseAbility: 0.97),
  ];
}

class SimulationRound {
  SimulationRound({
    required this.roundNo,
    required this.kind,
    required this.focusSkill,
    required this.reason,
    required this.correct,
    required this.watch,
    required this.detectedWeak,
    required this.mastered,
    required this.trulyWeak,
  });

  final int roundNo;
  final String kind;
  final String? focusSkill;
  final String reason;
  final int correct;

  /// P(L) of the watched skills after the round.
  final Map<String, double> watch;

  /// Skills the model labels weak / mastered after the round.
  final Set<String> detectedWeak;
  final Set<String> mastered;

  /// Hidden truth after the round: weak skills whose ability is still < 0.5.
  final Set<String> trulyWeak;
}

class SimulationResult {
  SimulationResult(this.profile, this.rounds, this.finalModel, this.rows);

  final SimulatedChildProfile profile;
  final List<SimulationRound> rounds;
  final ChildModel finalModel;

  /// Every word's feature row (as the app would export them).
  final List<FeatureRow> rows;
}

/// Plays whole rounds through the real engine (featurizer, model, selector)
/// with synthetic events. Nothing is saved.
class ChildSimulator {
  ChildSimulator(this.bank, {int seed = 7}) : _random = math.Random(seed);

  final WordBank bank;
  final math.Random _random;

  Future<SimulationResult> run(
    SimulatedChildProfile profile, {
    int rounds = 6,
    SpellingSettings? settings,
    ModelParams params = const ModelParams(),
  }) async {
    final engine = SpellingEngine(bank: bank, storage: _NoStorage(), random: _random, params: params);
    if (settings != null) engine.settings = settings;
    final child = await engine.createChild('🤖', group: SpellingMode.adaptive);
    engine.selectChild(child);

    final ability = <String, double>{};
    double abilityOf(String skill) => ability[skill] ?? profile.weakSkills[skill] ?? profile.baseAbility;
    final watched = {...profile.weakSkills.keys, if (profile.weakSkills.isEmpty) 'short_a'};

    final out = <SimulationRound>[];
    final rows = <FeatureRow>[];
    for (var r = 0; r < rounds; r++) {
      final plan = engine.startRound();
      var correct = 0;
      for (var i = 0; i < plan.words.length; i++) {
        final word = plan.words[i];
        final events = _playWord(word, abilityOf(word.phonicsSkill), profile.reversalRate);
        final row = await engine.recordWord(word: word, wordIndex: i, events: events);
        rows.add(row);
        if (row.finalCorrect) correct++;
        ability[word.phonicsSkill] = math.min(0.98, abilityOf(word.phonicsSkill) + profile.learningPerWord);
      }
      await engine.finishRound();
      out.add(SimulationRound(
        roundNo: r + 1,
        kind: plan.kind,
        focusSkill: plan.focusSkill,
        reason: plan.reason,
        correct: correct,
        watch: {for (final s in watched) s: child.skills[s]?.pL ?? 0},
        detectedWeak: {for (final s in bank.skillOrder) if (child.isWeak(s)) s},
        mastered: {for (final s in bank.skillOrder) if (child.isMastered(s)) s},
        trulyWeak: {for (final s in profile.weakSkills.keys) if (abilityOf(s) < 0.5) s},
      ));
    }
    return SimulationResult(profile, out, child, rows);
  }

  /// Synthetic events for one word. Weak skills are slower to start, slower
  /// between tiles and more often corrected; anyone can make a quick motor
  /// slip (which the model must ignore).
  List<SpellingEvent> _playWord(WordEntry word, double ability, double reversalRate) {
    final events = <SpellingEvent>[];
    var t = 0.0;
    void log(SpellingEventType type, [Map<String, Object?> data = const {}]) =>
        events.add(SpellingEvent(type, t, data));

    final weak = ability < 0.5;
    log(SpellingEventType.audioStart);
    t += 1500;
    log(SpellingEventType.audioEnd);
    t += (weak ? 4000 : 1800) * (0.6 + _random.nextDouble() * 0.8);

    final target = word.letters;
    final hasMirror = target.any((l) => const {'b', 'd', 'p', 'q'}.contains(l));
    for (var attempt = 1; attempt <= SpellingConfig.maxAttempts; attempt++) {
      final pCorrect = math.min(0.98, ability + (attempt - 1) * 0.25);
      final reversed = hasMirror && _random.nextDouble() < reversalRate * (attempt == 1 ? 1 : 0.5);
      final right = !reversed && _random.nextDouble() < pCorrect;
      final answer = right ? target : _mistake(word, reversed, onTarget: weak);

      for (var i = 0; i < answer.length; i++) {
        log(SpellingEventType.tilePlace, {'letter': answer[i], 'index': i});
        if (_random.nextDouble() < 0.05) {
          // Motor slip: picked straight back up and put down again.
          t += 300;
          log(SpellingEventType.tileRemove, {'letter': answer[i], 'index': i, 'msSincePlaced': 300});
          t += 400;
          log(SpellingEventType.tilePlace, {'letter': answer[i], 'index': i});
        }
        t += (weak ? 1800 : 800) + _random.nextDouble() * 500;
      }
      if (_random.nextDouble() < (weak ? 0.5 : 0.1)) {
        log(SpellingEventType.tileRemove, {'letter': answer.last, 'index': answer.length - 1, 'msSincePlaced': 2500});
        t += 900;
        log(SpellingEventType.tilePlace, {'letter': answer.last, 'index': answer.length - 1});
      }
      log(SpellingEventType.check, {'answer': answer.join(), 'correct': right, 'attemptNo': attempt});
      if (right) break;
      t += 1200;
    }
    log(SpellingEventType.wordEnd);
    return events;
  }

  /// A plausible wrong answer. The answer line has no fixed length, so a
  /// mistake can be a mirror flip, a wrong letter, a left-out letter
  /// (likely in blends: "fog" for "frog") or a doubled letter ("froog").
  /// A child weak at the skill gets the target sound wrong ([onTarget]);
  /// other slips land anywhere in the word.
  List<String> _mistake(WordEntry word, bool reversal, {required bool onTarget}) {
    final letters = [...word.letters];
    if (reversal) {
      final i = letters.indexWhere((l) => const {'b', 'd', 'p', 'q'}.contains(l));
      letters[i] = mirrorLetters[letters[i]]!;
      return letters;
    }
    final span = onTarget ? graphemeSpan(word.spelling, word.targetGrapheme) : null;
    final i = span == null
        ? _random.nextInt(letters.length)
        : span.$1 + _random.nextInt(span.$2 - span.$1 + 1);
    final blend = word.phonicsSkill.startsWith('blend_');
    final roll = _random.nextDouble();
    if (letters.length > 2 && roll < (blend ? 0.6 : 0.2)) {
      return letters..removeAt(i); // omission
    }
    if (roll > 0.85) {
      return letters..insert(i, letters[i]); // doubling (insertion)
    }
    const vowels = 'aeiou', consonants = 'cfhlmnrstw';
    final pool = (vowels.contains(letters[i]) ? vowels : consonants).replaceAll(letters[i], '');
    letters[i] = pool[_random.nextInt(pool.length)];
    return letters;
  }
}

/// Storage that keeps nothing (the simulator plays thousands of words).
class _NoStorage implements SpellingStorage {
  @override
  Future<List<ChildModel>> loadChildren() async => [];
  @override
  Future<ChildModel?> loadChild(String childId) async => null;
  @override
  Future<void> saveChild(ChildModel child) async {}
  @override
  Future<void> saveRow(FeatureRow row) async {}
  @override
  Future<List<FeatureRow>> loadRows({String? childId}) async => [];
  @override
  Future<void> saveEvents(Map<String, Object?> wordEvents) async {}
  @override
  Future<List<Map<String, Object?>>> loadEvents({String? childId}) async => [];
  @override
  Future<SpellingSettings> loadSettings() async => SpellingSettings();
  @override
  Future<void> saveSettings(SpellingSettings settings) async {}
  @override
  Future<void> clearAll() async {}
}
