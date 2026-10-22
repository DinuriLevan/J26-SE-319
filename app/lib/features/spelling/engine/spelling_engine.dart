import 'dart:math' as math;

import 'package:uuid/uuid.dart';

import '../data/spelling_storage.dart';
import '../data/word_bank.dart';
import '../model/difficulty_classifier.dart';
import 'event_logger.dart';
import 'feature_extractor.dart';
import 'learner_model.dart';
import 'selector.dart';
import 'spelling_config.dart';

/// Connects word bank, feature extractor, learner model, selector and
/// storage. The game UI only talks to this class.
///
/// One phone belongs to one child: [deviceChild] gives that child (made on
/// first play). Accounts from the shared profile can later pass their id.
///
/// Flow: [deviceChild] → [selectChild] → [startRound] → [recordWord] ×10 → [finishRound].
class SpellingEngine {
  SpellingEngine({
    required this.bank,
    required this.storage,
    math.Random? random,
    this.params = const ModelParams(),
  }) : selector = Selector(bank, random: random);

  final WordBank bank;
  final SpellingStorage storage;
  final Selector selector;

  /// Model numbers (the simulator swaps these for the parameter sweep).
  final ModelParams params;

  /// Predicts how hard a skill currently is (trained model, or the BKT
  /// fallback rule until init() has loaded the model).
  DifficultyClassifier classifier = const FallbackDifficultyClassifier();

  SpellingSettings settings = SpellingSettings();
  List<ChildModel> children = [];
  ChildModel? child;
  String sessionId = '';
  int roundsThisSession = 0;
  RoundPlan? plan;
  final List<FeatureRow> _roundRows = [];

  static const avatars = ['🐶', '🐱', '🐼', '🦁', '🐰', '🐸', '🐵', '🐧', '🦊', '🐨', '🐯', '🐻'];

  /// Avatar of the phone's child until accounts provide one.
  static const defaultAvatar = '🐼';

  Future<void> init({bool loadClassifier = true}) async {
    settings = await storage.loadSettings();
    children = await storage.loadChildren();
    if (loadClassifier) classifier = await MlDifficultyClassifier.load();
  }

  /// The experiment group a new child joins, from the research settings.
  SpellingMode groupForNewChild() => switch (settings.newChildGroup) {
        NewChildGroup.adaptive => SpellingMode.adaptive,
        NewChildGroup.fixed => SpellingMode.fixed,
        NewChildGroup.alternate => children.where((c) => c.group == SpellingMode.adaptive).length <=
                children.where((c) => c.group == SpellingMode.fixed).length
            ? SpellingMode.adaptive
            : SpellingMode.fixed,
      };

  /// Creates a child. The group is assigned here once and never changes
  /// (except by [resetChild]).
  Future<ChildModel> createChild(String avatar, {SpellingMode? group}) async {
    final c = ChildModel.create(
      childId: const Uuid().v4(),
      avatar: avatar,
      bank: bank,
      group: group ?? groupForNewChild(),
    );
    await storage.saveChild(c);
    children.add(c);
    return c;
  }

  /// The child who uses this phone. Returns the saved child (the most
  /// recently played one, if an older build saved several), or creates one.
  /// [childId] is for the shared profile/accounts later: the child with that
  /// id is used, or created with it.
  Future<ChildModel> deviceChild({String? childId}) async {
    if (childId != null) {
      for (final c in children) {
        if (c.childId == childId) return c;
      }
    } else if (children.isNotEmpty) {
      return mostRecentChild!;
    }
    final c = ChildModel.create(
      childId: childId ?? const Uuid().v4(),
      avatar: defaultAvatar,
      bank: bank,
      group: groupForNewChild(),
    );
    await storage.saveChild(c);
    children.add(c);
    return c;
  }

  /// The child who played last (or was created last), if any.
  ChildModel? get mostRecentChild {
    if (children.isEmpty) return null;
    DateTime last(ChildModel c) => c.rounds.isEmpty ? c.createdAt : c.rounds.last.finishedAt;
    return children.reduce((a, b) => last(b).isAfter(last(a)) ? b : a);
  }

  /// Starts a new session for [c] (resuming their saved model).
  void selectChild(ChildModel c) {
    child = c;
    sessionId = '${DateTime.now().millisecondsSinceEpoch}';
    roundsThisSession = 0;
    plan = null;
    _roundRows.clear();
  }

  bool get sessionOver => roundsThisSession >= SpellingConfig.roundsPerSession;

  /// The round [c] will play next. Planned when the previous round ended,
  /// so the teacher view shows exactly what will happen.
  RoundPlan previewNext(ChildModel c) {
    final saved = c.pendingPlan == null ? null : RoundPlan.fromJson(c.pendingPlan!, bank);
    if (saved != null) return saved;
    final p = selector.next(c, useClassifier: settings.useClassifier);
    c.pendingPlan = p.toJson();
    return p;
  }

  RoundPlan startRound() {
    final c = child!;
    _roundRows.clear();
    final p = previewNext(c);
    c.pendingPlan = null;
    // Failed words in this round are now "returned" and won't come back again.
    for (final w in p.words) {
      if (c.failedDue.containsKey(w.id)) c.failedReturned.add(w.id);
    }
    return plan = p;
  }

  /// Featurises one finished word, updates the model and saves row + events.
  Future<FeatureRow> recordWord({
    required WordEntry word,
    required int wordIndex,
    required List<SpellingEvent> events,
  }) async {
    final c = child!;
    final ctx = WordContext(
      childId: c.childId,
      sessionId: sessionId,
      roundNo: c.nextRoundNo,
      wordIndex: wordIndex,
      mode: plan!.kind,
    );
    // Features first (against the child's earlier medians), then add this
    // word's timing to the medians.
    final row = featurize(events, word, c, ctx, useBehaviour: settings.useBehaviour);
    c.recordTiming(row.firstInputMs, row.maxGapMs);

    if (plan!.isPlacement) {
      LearnerModel.applyPlacementWord(c, row, bank);
    } else {
      // The model always updates, even in the fixed group, for comparison.
      LearnerModel.applyWord(c, row, bank, useBehaviour: settings.useBehaviour, params: params);
    }
    _predict(c, row);
    _roundRows.add(row);

    await storage.saveRow(row);
    await storage.saveEvents({
      'childId': c.childId,
      'sessionId': sessionId,
      'roundNo': ctx.roundNo,
      'wordIndex': wordIndex,
      'word_id': word.id,
      'word': word.word,
      'events': events.map((e) => e.toJson()).toList(),
    });
    await storage.saveChild(c);
    return row;
  }

  /// Runs the difficulty classifier for this word's skill, keeps the
  /// prediction (last 3 per skill), adds it to the row, and holds back
  /// "mastered" while BKT and the classifier strongly disagree.
  void _predict(ChildModel c, FeatureRow row) {
    final prediction = classifier.predict(row);
    c.addPrediction(row.skill, prediction);
    row.values['clf_label'] = prediction.label;
    row.values['clf_p_hard'] = prediction.probs['hard'];
    row.values['clf_source'] = prediction.source;
    final s = c.skills[row.skill];
    if (s != null) {
      s.masteryHeld = settings.useClassifier && c.bktMastered(row.skill) && c.hardTwiceInARow(row.skill);
    }
  }

  /// Closes the round: placement initialisation, history, failed-word
  /// scheduling, fixed-sequence cursor, and plans the next round.
  Future<RoundRecord> finishRound() async {
    final c = child!;
    final p = plan!;
    if (p.isPlacement) LearnerModel.applyPlacement(c, _roundRows, bank);
    if (p.kind == 'fixed') c.fixedCursor += p.words.length;

    final roundNo = c.nextRoundNo;
    final failed = [for (final r in _roundRows) if (!r.finalCorrect) r.wordId];
    for (final id in failed) {
      if (!c.failedReturned.contains(id)) {
        c.failedDue[id] = roundNo + SpellingConfig.failedReturnAfter;
      }
    }

    final record = RoundRecord(
      roundNo: roundNo,
      mode: p.kind,
      focusSkill: p.focusSkill,
      reason: p.reason,
      wordIds: p.words.map((w) => w.id).toList(),
      failedWordIds: failed,
      pSnapshot: c.skills.map((k, v) => MapEntry(k, v.pL)),
      finishedAt: DateTime.now(),
      sessionId: sessionId,
      correct: _roundRows.where((r) => r.finalCorrect).length,
      correctFirstTry: _roundRows.where((r) => r.correctFirstTry).length,
    );
    c.rounds.add(record);
    roundsThisSession++;
    _roundRows.clear();
    previewNext(c);
    await storage.saveChild(c);
    return record;
  }

  Future<void> saveSettings() => storage.saveSettings(settings);

  Future<void> renameChild(ChildModel c, String name) async {
    c.name = name.trim().isEmpty ? null : name.trim();
    await storage.saveChild(c);
  }

  /// Deletes everything the spelling game saved on this phone (children,
  /// word rows, tap logs, settings), so testing can start from scratch.
  Future<void> resetAllData() async {
    await storage.clearAll();
    settings = SpellingSettings();
    children = [];
    child = null;
    plan = null;
    sessionId = '';
    roundsThisSession = 0;
    _roundRows.clear();
  }

  /// Starts the child over (new placement), optionally in another group.
  /// Their recorded rows and events are kept for research.
  Future<ChildModel> resetChild(ChildModel c, {SpellingMode? group}) async {
    final fresh = ChildModel.create(
      childId: c.childId,
      avatar: c.avatar,
      bank: bank,
      group: group ?? c.group,
      name: c.name,
    );
    await storage.saveChild(fresh);
    final i = children.indexWhere((x) => x.childId == c.childId);
    if (i >= 0) children[i] = fresh;
    if (child?.childId == c.childId) child = fresh;
    return fresh;
  }
}
