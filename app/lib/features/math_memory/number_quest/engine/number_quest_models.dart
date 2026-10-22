import '../../engine/attempt.dart';
import '../../engine/math_picture.dart';

enum MathSkill {
  counting,
  addition,
  subtraction,
  multiplication,
  division;

  static MathSkill fromName(String name) =>
      values.firstWhere((s) => s.name == name, orElse: () => counting);
}

/// One multiple-choice Number Quest activity.
class NumberQuestion {
  const NumberQuestion({
    required this.skill,
    required this.level,
    required this.a,
    required this.b,
    required this.answer,
    required this.choices,
    required this.picture,
    required this.showObjects,
  });

  final MathSkill skill;

  /// Difficulty within [skill], 1..5.
  final int level;

  /// counting: number of objects (b unused). addition/subtraction: a ± b.
  /// multiplication: a groups of b. division: a shared into b groups.
  final int a;
  final int b;
  final int answer;

  /// Answer options in display order; always contains [answer].
  final List<int> choices;

  final MathPicture picture;

  /// Whether to draw the quantities as pictures. Lower levels and
  /// reinforcement questions are visual; higher levels use numerals only.
  final bool showObjects;

  /// Equation shown under the pictures, or null for counting.
  String? get equation => switch (skill) {
        MathSkill.counting => null,
        MathSkill.addition => '$a + $b = ?',
        MathSkill.subtraction => '$a - $b = ?',
        MathSkill.multiplication => '$a × $b = ?',
        MathSkill.division => '$a ÷ $b = ?',
      };

  /// One short instruction, kept simple for early readers.
  String get prompt => switch (skill) {
        MathSkill.counting => 'How many ${picture.plural}?',
        MathSkill.addition => 'How many in all?',
        MathSkill.subtraction => 'Take away $b. How many are left?',
        MathSkill.multiplication => '$a groups of $b. How many in all?',
        MathSkill.division => 'Share $a into $b groups. How many in each?',
      };

  /// Identity for avoiding repeats within one attempt.
  String get key => '${skill.name}:$a:$b';

  Map<String, dynamic> toJson() => {
        'skill': skill.name,
        'level': level,
        'a': a,
        'b': b,
        'answer': answer,
        'choices': choices,
        'picture': picture.name,
        'visual': showObjects,
      };
}

/// What the engine knows about one skill. Persisted between attempts.
class SkillState {
  const SkillState({
    required this.level,
    this.firstTryStreak = 0,
    this.errorStreak = 0,
    this.cooldown = 0,
    this.recent = const [],
  });

  /// Current difficulty, 1..5.
  final int level;

  /// Consecutive quick first-try correct answers since the last change.
  final int firstTryStreak;

  /// Consecutive answers that were not first-try correct.
  final int errorStreak;

  /// Answers left before the level may change again (prevents oscillation).
  final int cooldown;

  /// Recent [AnswerOutcome.mastery] values, oldest first.
  final List<double> recent;

  double? get recentAccuracy => meanOf(recent);

  SkillState copyWith({
    int? level,
    int? firstTryStreak,
    int? errorStreak,
    int? cooldown,
    List<double>? recent,
  }) {
    return SkillState(
      level: level ?? this.level,
      firstTryStreak: firstTryStreak ?? this.firstTryStreak,
      errorStreak: errorStreak ?? this.errorStreak,
      cooldown: cooldown ?? this.cooldown,
      recent: recent ?? this.recent,
    );
  }

  Map<String, dynamic> toJson() => {
        'level': level,
        'first_try_streak': firstTryStreak,
        'error_streak': errorStreak,
        'cooldown': cooldown,
        'recent': recent,
      };

  factory SkillState.fromJson(Map<String, dynamic> json) => SkillState(
        level: (json['level'] as num?)?.toInt() ?? 1,
        firstTryStreak: (json['first_try_streak'] as num?)?.toInt() ?? 0,
        errorStreak: (json['error_streak'] as num?)?.toInt() ?? 0,
        cooldown: (json['cooldown'] as num?)?.toInt() ?? 0,
        recent: [
          for (final v in (json['recent'] as List?) ?? const []) (v as num).toDouble(),
        ],
      );
}

/// Everything Number Quest remembers about a child, stored locally under
/// [MathGameId.numberQuest].
class NumberQuestProgress {
  const NumberQuestProgress({
    required this.tutorialSeen,
    required this.completedAttempts,
    required this.skills,
  });

  /// Before the baseline, every skill starts at level 1.
  factory NumberQuestProgress.initial() => NumberQuestProgress(
        tutorialSeen: false,
        completedAttempts: 0,
        skills: {for (final s in MathSkill.values) s: const SkillState(level: 1)},
      );

  final bool tutorialSeen;

  /// Completed (not abandoned) real attempts. Tutorial practice never counts.
  final int completedAttempts;

  final Map<MathSkill, SkillState> skills;

  AttemptType get nextAttemptType => AttemptType.forCompletedAttempts(completedAttempts);

  int get nextAttemptNumber => completedAttempts + 1;

  NumberQuestProgress copyWith({
    bool? tutorialSeen,
    int? completedAttempts,
    Map<MathSkill, SkillState>? skills,
  }) {
    return NumberQuestProgress(
      tutorialSeen: tutorialSeen ?? this.tutorialSeen,
      completedAttempts: completedAttempts ?? this.completedAttempts,
      skills: skills ?? this.skills,
    );
  }

  Map<String, dynamic> toJson() => {
        'schema_version': mathMemorySchemaVersion,
        'tutorial_seen': tutorialSeen,
        'completed_attempts': completedAttempts,
        'skills': {for (final e in skills.entries) e.key.name: e.value.toJson()},
      };

  factory NumberQuestProgress.fromJson(Map<String, dynamic> json) {
    final initial = NumberQuestProgress.initial();
    final rawSkills = (json['skills'] as Map?)?.cast<String, dynamic>() ?? const {};
    return NumberQuestProgress(
      tutorialSeen: json['tutorial_seen'] as bool? ?? false,
      completedAttempts: (json['completed_attempts'] as num?)?.toInt() ?? 0,
      skills: {
        for (final s in MathSkill.values)
          s: rawSkills[s.name] is Map
              ? SkillState.fromJson((rawSkills[s.name] as Map).cast<String, dynamic>())
              : initial.skills[s]!,
      },
    );
  }
}
