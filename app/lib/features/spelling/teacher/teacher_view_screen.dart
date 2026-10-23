import 'dart:io';

import 'package:flutter/material.dart';

import '../data/skill_labels.dart';
import '../engine/learner_model.dart';
import '../engine/spelling_engine.dart';
import 'exporter.dart';
import 'teacher_insights.dart';

/// Teacher View: plain-language progress for the phone's child. No model
/// numbers. The ⋮ menu has the report, the data exports and "Reset all data".
class TeacherViewScreen extends StatefulWidget {
  const TeacherViewScreen({super.key, required this.engine});

  final SpellingEngine engine;

  @override
  State<TeacherViewScreen> createState() => _TeacherViewScreenState();
}

/// Colours of the three "how did each word go" groups and the sound groups.
class _Palette {
  const _Palette._();

  static const ink = Color(0xFF243042);
  static const soft = Color(0xFF5B6678);
  static const green = Color(0xFF1E9E5A);
  static const greenBg = Color(0xFFE3F5EA);
  static const blue = Color(0xFF2A78D6);
  static const blueBg = Color(0xFFE4EEFC);
  static const orange = Color(0xFFD9822B);
  static const orangeBg = Color(0xFFFDEEDC);
  static const grey = Color(0xFFE1E5EE);
}

class _TeacherViewScreenState extends State<TeacherViewScreen> {
  SpellingEngine get engine => widget.engine;
  Future<TeacherInsights>? _insights;

  static const _ink = _Palette.ink;
  static const _soft = _Palette.soft;

  /// One phone = one child: the one playing now, else the last one played.
  ChildModel? get _child => engine.child ?? engine.mostRecentChild;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final c = _child;
    if (c == null) return;
    _insights = engine.storage.loadRows(childId: c.childId).then(
          (rows) => TeacherInsights(child: c, rows: rows, bank: engine.bank, next: engine.previewNext(c)),
        );
  }

  Future<void> _rename(ChildModel c) async {
    final controller = TextEditingController(text: c.name ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Child\'s name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(hintText: c.displayName),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save')),
        ],
      ),
    );
    if (name == null) return;
    await engine.renameChild(c, name);
    setState(_load);
  }

  Future<void> _downloadReport() async {
    final insights = await _insights;
    if (insights == null || !mounted) return;
    await _save('Report', () => SpellingExporter(engine).reportHtml(insights),
        hint: '\nOpen it in a browser to print or save as PDF.');
  }

  /// Runs an export and says where the file went.
  Future<void> _save(String what, Future<File> Function() run, {String hint = ''}) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await run();
      messenger.showSnackBar(SnackBar(content: Text('$what saved: ${file.path}$hint'), duration: const Duration(seconds: 6)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not save the ${what.toLowerCase()}: $e')));
    }
  }

  /// Deletes everything on this phone after a clear warning (for testing).
  Future<void> _resetAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_forever_rounded, size: 36, color: _Palette.orange),
        title: const Text('Reset all data?'),
        content: const Text('This deletes the child\'s progress, words and saved data on this phone. '
            'The next game starts again with the warm-up. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _Palette.orange),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await engine.resetAllData();
      setState(() => _insights = null);
      messenger.showSnackBar(const SnackBar(content: Text('All spelling data was deleted.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not reset: $e')));
    }
  }

  void _menu(String item) {
    final export = SpellingExporter(engine);
    switch (item) {
      case 'reset':
        _resetAll();
      case 'report':
        _downloadReport();
      case 'csv':
        _save('Word data', export.featuresCsv);
      case 'model':
        _save('Model state', export.modelJson);
      case 'events':
        _save('Tap log', export.eventsJson);
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = _child;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('👩‍🏫 Progress'),
        actions: [
          PopupMenuButton<String>(
            onSelected: _menu,
            itemBuilder: (_) => [
              if (child != null) const PopupMenuItem(value: 'report', child: Text('Download report')),
              if (child != null) const PopupMenuDivider(),
              const PopupMenuItem(
                enabled: false,
                height: 32,
                child: Text('Data for training', style: TextStyle(fontSize: 13)),
              ),
              const PopupMenuItem(value: 'csv', child: Text('Word data (CSV)')),
              const PopupMenuItem(value: 'model', child: Text('Model state (JSON)')),
              const PopupMenuItem(value: 'events', child: Text('Tap log (JSON)')),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever_rounded, color: _Palette.orange),
                    SizedBox(width: 10),
                    Text('Reset all data'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: child == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('Nothing played yet.\nProgress shows here after the first game.',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: _soft, height: 1.4)),
              ),
            )
          : FutureBuilder<TeacherInsights>(
              future: _insights,
              builder: (context, snap) {
                final i = snap.data;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    const SizedBox(height: 4),
                    if (i == null)
                      const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
                    else
                      ..._cards(i),
                  ],
                );
              },
            ),
    );
  }

  List<Widget> _cards(TeacherInsights i) {
    final c = i.child;
    final needs = i.needsHelp;
    final habits = i.habits;
    final slow = i.hesitationNotes;

    return [
      // a) Header
      _card(
        child: Row(
          children: [
            Text(c.avatar, style: const TextStyle(fontSize: 56)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(c.displayName,
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: _ink)),
                      ),
                      IconButton(
                        tooltip: 'Change name',
                        icon: const Icon(Icons.edit_outlined, size: 20, color: _soft),
                        onPressed: () => _rename(c),
                      ),
                    ],
                  ),
                  Text(
                    '${i.sessionsPlayed} session${i.sessionsPlayed == 1 ? '' : 's'} played · last played ${i.lastPlayed}',
                    style: const TextStyle(fontSize: 16, color: _soft),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      // b) Latest round
      _card(
        title: 'Latest round',
        child: _latestRound(i),
      ),
      // c) Needs help with
      _card(
        title: 'Needs help with',
        child: needs.isEmpty
            ? _line('Nothing worrying right now 👍')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (final n in needs) _bullet(n.sentence, color: _Palette.orange)],
              ),
      ),
      // d) Mistake habits
      _card(
        title: 'Mistake habits',
        child: habits.isEmpty && slow.isEmpty
            ? _line('No repeated mistake habits right now.')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final h in habits) _bullet('${h.sentence} (${h.countText})'),
                  for (final s in slow) _bullet(s),
                ],
              ),
      ),
      // e) Sounds
      _card(
        title: 'Sounds',
        child: _sounds(i),
      ),
      // f) Progress
      _card(
        title: 'Progress',
        child: i.progress.isEmpty
            ? _line('The chart appears after the first round.')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Words right first time, each round',
                      style: TextStyle(fontSize: 15, color: _soft)),
                  const SizedBox(height: 8),
                  RoundsBarChart(progress: i.progress),
                ],
              ),
      ),
      // g) What's next
      _card(
        title: 'What\'s next',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _line(i.nextSentence),
            for (final tip in i.tips) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💡 ', style: TextStyle(fontSize: 18)),
                  Expanded(child: Text(tip, style: const TextStyle(fontSize: 16, color: _ink))),
                ],
              ),
            ],
          ],
        ),
      ),
    ];
  }

  /// Three big numbers: right first time, right after another try, shown.
  Widget _latestRound(TeacherInsights i) {
    final b = i.latest;
    if (b == null) return _line('No rounds played yet.');
    final trend = i.trend;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _stat(b.firstTry, 'right first time', '⭐', _Palette.green, _Palette.greenBg),
            const SizedBox(width: 8),
            _stat(b.afterRetry, 'right after another try', '🔁', _Palette.blue, _Palette.blueBg),
            const SizedBox(width: 8),
            _stat(b.shown, 'answer shown', '💡', _Palette.orange, _Palette.orangeBg),
          ],
        ),
        const SizedBox(height: 12),
        _splitBar(b),
        if (trend != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                trend > 0
                    ? Icons.trending_up_rounded
                    : (trend < 0 ? Icons.trending_down_rounded : Icons.trending_flat_rounded),
                color: trend > 0 ? _Palette.green : (trend < 0 ? _Palette.orange : _soft),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(i.trendText!, style: const TextStyle(fontSize: 16, color: _ink))),
            ],
          ),
        ],
      ],
    );
  }

  Widget _stat(int value, String label, String emoji, Color color, Color background) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(14)),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              Text('$value', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: color)),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: _ink, height: 1.2)),
            ],
          ),
        ),
      );

  /// One bar split into the three groups, so the round reads at a glance.
  Widget _splitBar(RoundBreakdown b) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 14,
          child: Row(
            children: [
              if (b.firstTry > 0) Expanded(flex: b.firstTry, child: Container(color: _Palette.green)),
              if (b.afterRetry > 0) Expanded(flex: b.afterRetry, child: Container(color: _Palette.blue)),
              if (b.shown > 0) Expanded(flex: b.shown, child: Container(color: _Palette.orange)),
            ],
          ),
        ),
      );

  /// Stage path plus the practised sounds in three coloured groups.
  Widget _sounds(TeacherInsights i) {
    final groups = [
      (SkillStatus.needsHelp, '🟠', _Palette.orangeBg),
      (SkillStatus.gettingThere, '📘', _Palette.blueBg),
      (SkillStatus.mastered, '✅', _Palette.greenBg),
    ];
    final improving = i.improving.toSet();
    final later = i.skillsWith(SkillStatus.notStarted).length;
    final practised = groups.any((g) => i.skillsWith(g.$1).isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _line(i.stageText),
        if (!i.next.isPlacement) ...[
          const SizedBox(height: 10),
          _stagePath(i.currentStage),
        ],
        const SizedBox(height: 6),
        if (!practised) ...[
          const SizedBox(height: 8),
          _line('Sounds appear here after the first round.'),
        ],
        for (final (status, emoji, background) in groups)
          if (i.skillsWith(status).isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('$emoji  ${status.text}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in i.skillsWith(status))
                  _chip('${skillLabel(s).full}${improving.contains(s) ? '  📈' : ''}', background),
              ],
            ),
          ],
        if (later > 0) ...[
          const SizedBox(height: 14),
          Text('$later more sound${later == 1 ? '' : 's'} will come in later stages.',
              style: const TextStyle(fontSize: 14, color: _soft)),
        ],
        if (improving.isNotEmpty) ...[
          const SizedBox(height: 4),
          const Text('📈 = getting better lately', style: TextStyle(fontSize: 14, color: _soft)),
        ],
      ],
    );
  }

  /// 8 segments: earlier stages filled, the current one highlighted.
  Widget _stagePath(int current) => Row(
        children: [
          for (var s = 1; s <= TeacherInsights.stageCount; s++) ...[
            Expanded(
              child: Container(
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: s < current ? _Palette.green : (s == current ? _Palette.blue : _Palette.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$s',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: s <= current ? Colors.white : _soft,
                    )),
              ),
            ),
            if (s < TeacherInsights.stageCount) const SizedBox(width: 4),
          ],
        ],
      );

  Widget _card({String? title, required Widget child}) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(color: Color(0x14243042), blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _ink)),
              const SizedBox(height: 10),
            ],
            child,
          ],
        ),
      );

  Widget _line(String text) => Text(text, style: const TextStyle(fontSize: 17, color: _ink, height: 1.35));

  Widget _bullet(String text, {Color color = _ink}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, right: 10),
              child: Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            ),
            Expanded(child: _line(text)),
          ],
        ),
      );

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: const TextStyle(fontSize: 15, color: _ink)),
      );
}

/// Simple bar chart: words right first time (out of 10) per round.
class RoundsBarChart extends StatelessWidget {
  const RoundsBarChart({super.key, required this.progress});

  /// (round number, words right first time).
  final List<(int, int)> progress;

  @override
  Widget build(BuildContext context) {
    const maxHeight = 120.0;
    return SizedBox(
      height: maxHeight + 44,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (round, firstTry) in progress)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('$firstTry', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 44),
                      height: maxHeight * (firstTry.clamp(0, 10) / 10) + 2,
                      decoration: BoxDecoration(
                        color: _Palette.green,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('R$round', style: const TextStyle(fontSize: 11, color: _Palette.soft)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
