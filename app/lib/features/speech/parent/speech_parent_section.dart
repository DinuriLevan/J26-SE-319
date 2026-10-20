import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../audio/speech_voice.dart';
import '../data/speech_api.dart';
import '../data/speech_progress_store.dart';
import '../ui/speech_theme.dart';
import '../ui/word_picture.dart';
import 'speech_parent_stats.dart';

/// The speech tab of the parent dashboard: words mastered, sounds to practise, recent activity,
/// improvement over time and tips for grown-ups, from the finished words stored on this device.
/// For grown-ups, but still encouraging: no raw scores, no diagnosis wording.
class SpeechParentSection extends ConsumerStatefulWidget {
  const SpeechParentSection({super.key, required this.childId, this.now});

  final String childId;

  /// Fixed "now" for tests; the real clock otherwise.
  final DateTime? now;

  @override
  ConsumerState<SpeechParentSection> createState() =>
      _SpeechParentSectionState();
}

class _SpeechParentSectionState extends ConsumerState<SpeechParentSection> {
  String? _language; // null = both

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final results = ref.watch(speechWordResultsProvider(widget.childId));
    return SpeechThemed(
      child: ColoredBox(
        color: SpeechColors.cream,
        child: results.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(child: Text(l10n.speechSomethingWrong)),
          data: (all) {
            final stats = SpeechParentStats.from(all,
                now: widget.now ?? DateTime.now(), language: _language);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                _languageSwitch(l10n),
                const SizedBox(height: 12),
                if (all.isEmpty)
                  _Card(child: Text(l10n.speechParentEmpty))
                else ...[
                  _summary(l10n, stats),
                  _Card(
                    title: l10n.speechParentMastered,
                    child: _words(l10n, stats.mastered),
                  ),
                  _Card(
                    title: l10n.speechParentPractising,
                    child: _words(l10n, stats.practising),
                  ),
                  _Card(
                    title: l10n.speechParentSounds,
                    child: _sounds(l10n, stats.sounds),
                  ),
                  _Card(
                    title: l10n.speechParentRecent,
                    subtitle: l10n.speechParentDailyHint,
                    child: _DailyChart(
                      daily: stats.daily,
                      summary: l10n.speechParentDailySummary(
                          stats.daily.fold(0, (a, b) => a + b)),
                    ),
                  ),
                  _Card(
                    title: l10n.speechParentImprovement,
                    subtitle: l10n.speechParentFirstTry,
                    child: _improvement(l10n, stats),
                  ),
                ],
                _Card(title: l10n.speechParentTips, child: _tips(l10n, stats)),
                const SizedBox(height: 8),
                Text(l10n.speechParentFootnote,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: SpeechColors.navySoft, fontSize: 13)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _languageSwitch(AppLocalizations l10n) => SegmentedButton<String>(
        segments: [
          ButtonSegment(value: 'all', label: Text(l10n.speechParentBoth)),
          const ButtonSegment(value: 'si', label: Text('සිංහල')),
          const ButtonSegment(value: 'en', label: Text('English')),
        ],
        selected: {_language ?? 'all'},
        showSelectedIcon: false,
        onSelectionChanged: (s) =>
            setState(() => _language = s.first == 'all' ? null : s.first),
      );

  Widget _summary(AppLocalizations l10n, SpeechParentStats stats) {
    Widget pill(IconData icon, String text, Color color) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(20)),
            child: Column(children: [
              Icon(icon, color: SpeechColors.navy),
              const SizedBox(height: 6),
              Text(text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: SpeechColors.navy)),
            ]),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        pill(
            Icons.star_rounded,
            l10n.speechParentMasteredCount(stats.mastered.length),
            SpeechColors.mint),
        pill(Icons.calendar_today_rounded,
            l10n.speechParentThisWeek(stats.wordsThisWeek), SpeechColors.sky),
        pill(Icons.local_fire_department_rounded,
            l10n.speechParentStreak(stats.streakDays), SpeechColors.peach),
      ]),
    );
  }

  Widget _words(AppLocalizations l10n, List<WordProgress> words) {
    if (words.isEmpty) return Text(l10n.speechParentNoneYet);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final w in words)
          Chip(
            avatar: WordPicture(wordId: w.word.id, size: 24),
            label: Text(w.word.text),
            backgroundColor: SpeechColors.level(w.word.level),
            side: BorderSide.none,
          ),
      ],
    );
  }

  Widget _sounds(AppLocalizations l10n, List<SoundToPractise> sounds) {
    if (sounds.isEmpty) return Text(l10n.speechParentNoSounds);
    return Column(children: [
      for (final s in sounds.take(5))
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: WordPicture(wordId: s.word.id, size: 40),
          title: Text('“${s.label}”',
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          subtitle: Text(
              '${l10n.speechParentInWord(s.word.text)} · ${l10n.speechParentTimes(s.count)}'),
          trailing: IconButton.filledTonal(
            key: ValueKey('hear_sound_${s.word.id}_${s.label}'),
            tooltip: '${l10n.speechHearSound} ${s.label}',
            icon: const Icon(Icons.volume_up_rounded),
            onPressed: () => _hearSound(s),
          ),
        ),
    ]);
  }

  /// Plays the sound in the adult voice, cut from the word (same rules as the practice screen:
  /// Sinhala may fall back to text-to-speech, English letters never do).
  Future<void> _hearSound(SoundToPractise s) async {
    WordInfo? info;
    try {
      info = (await ref.read(speechWordsProvider.future))[s.word.id];
    } catch (_) {
      info = null; // offline: only the Sinhala TTS fallback is possible
    }
    final i = info?.units.indexOf(s.label) ?? -1;
    final hasRecording = info != null && i >= 0 && info.listenUnits.contains(i);
    await ref.read(speechVoiceProvider).playModel(
          fetchRecording: () async => hasRecording
              ? ref.read(speechApiProvider).listen(s.word, start: i, end: i)
              : null,
          ttsText: s.label,
          lang: s.word.language,
          allowTts: s.word.language == 'si',
        );
  }

  Widget _improvement(AppLocalizations l10n, SpeechParentStats stats) {
    final trend = stats.trend;
    final summary = trend == null
        ? l10n.speechParentNoTrend
        : l10n.speechParentTrend((trend.$1.firstTryRate! * 100).round(),
            (trend.$2.firstTryRate! * 100).round(), trend.$3);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WeeklyChart(weeks: stats.weeks, summary: summary),
        const SizedBox(height: 8),
        Text(summary),
        Text(l10n.speechParentTriesLegend,
            style: const TextStyle(color: SpeechColors.navySoft, fontSize: 13)),
      ],
    );
  }

  Widget _tips(AppLocalizations l10n, SpeechParentStats stats) {
    final top = stats.sounds.isEmpty ? null : stats.sounds.first;
    final tips = [
      if (top != null) l10n.speechParentSoundTip(top.label, top.word.text),
      l10n.speechParentTip1,
      l10n.speechParentTip2,
      l10n.speechParentTip3,
      l10n.speechParentTip4,
    ];
    return Column(children: [
      for (final t in tips)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(
              padding: EdgeInsets.only(top: 2, right: 8),
              child: Icon(Icons.lightbulb_outline_rounded,
                  size: 20, color: SpeechColors.coralDeep),
            ),
            Expanded(child: Text(t)),
          ]),
        ),
    ]);
  }
}

class _Card extends StatelessWidget {
  const _Card({this.title, this.subtitle, required this.child});

  final String? title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SpeechColors.paper,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
              color: SpeechColors.shadow, blurRadius: 10, offset: Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Text(title!,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: SpeechColors.navy)),
          if (subtitle != null)
            Text(subtitle!,
                style: const TextStyle(
                    fontSize: 13, color: SpeechColors.navySoft)),
          if (title != null) const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// Words practised per day; today is the right-most bar.
class _DailyChart extends StatelessWidget {
  const _DailyChart({required this.daily, required this.summary});

  final List<int> daily;
  final String summary;

  @override
  Widget build(BuildContext context) => Semantics(
        label: summary,
        excludeSemantics: true,
        child: SizedBox(
          height: 110,
          width: double.infinity,
          child: CustomPaint(painter: _BarsPainter(daily)),
        ),
      );
}

class _BarsPainter extends CustomPainter {
  _BarsPainter(this.values);

  final List<int> values;

  @override
  void paint(Canvas canvas, Size size) {
    final max = values.fold(1, (a, b) => a > b ? a : b);
    final slot = size.width / values.length;
    final base = Paint()..color = SpeechColors.navySoft.withValues(alpha: 0.15);
    canvas.drawRect(Rect.fromLTWH(0, size.height - 1, size.width, 1), base);
    for (var i = 0; i < values.length; i++) {
      if (values[i] == 0) continue;
      final h = (size.height - 16) * values[i] / max;
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(
            i * slot + slot * 0.18, size.height - h - 1, slot * 0.64, h),
        const Radius.circular(6),
      );
      canvas.drawRRect(
          r,
          Paint()
            ..color = i == values.length - 1
                ? SpeechColors.coral
                : SpeechColors.levelDeep(2));
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) => old.values != values;
}

/// Weekly first-try success (bars, 0-100%) with average tries per mastered word (dots, 1-3+).
/// Weeks without practice are left empty.
class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart({required this.weeks, required this.summary});

  final List<WeekPoint> weeks;
  final String summary;

  @override
  Widget build(BuildContext context) => Semantics(
        label: summary,
        excludeSemantics: true,
        child: SizedBox(
          height: 130,
          width: double.infinity,
          child: CustomPaint(painter: _WeeklyPainter(weeks)),
        ),
      );
}

class _WeeklyPainter extends CustomPainter {
  _WeeklyPainter(this.weeks);

  final List<WeekPoint> weeks;

  @override
  void paint(Canvas canvas, Size size) {
    final slot = size.width / weeks.length;
    final top = 8.0;
    final h = size.height - top - 1;
    final grid = Paint()..color = SpeechColors.navySoft.withValues(alpha: 0.15);
    for (final f in [0.0, 0.5, 1.0]) {
      canvas.drawRect(Rect.fromLTWH(0, top + h * (1 - f), size.width, 1), grid);
    }
    final dot = Paint()..color = SpeechColors.coralDeep;
    Offset? prev;
    for (var i = 0; i < weeks.length; i++) {
      final w = weeks[i];
      final rate = w.firstTryRate;
      if (rate == null) {
        prev = null;
        continue;
      }
      final bh = h * rate;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
              i * slot + slot * 0.2, top + h - bh, slot * 0.6, bh < 2 ? 2 : bh),
          const Radius.circular(6),
        ),
        Paint()..color = SpeechColors.success,
      );
      final tries = w.avgTries;
      if (tries == null) continue;
      // 1 try at the top, 3 or more at the bottom.
      final y = top + h * ((tries.clamp(1, 3) - 1) / 2);
      final p = Offset(i * slot + slot / 2, y);
      if (prev != null) {
        canvas.drawLine(
            prev,
            p,
            Paint()
              ..color = SpeechColors.coralDeep
              ..strokeWidth = 2);
      }
      canvas.drawCircle(p, 5, dot);
      prev = p;
    }
  }

  @override
  bool shouldRepaint(_WeeklyPainter old) => old.weeks != weeks;
}
