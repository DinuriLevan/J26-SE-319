import 'package:flutter/material.dart';

import '../../../../core/theme/app_fonts.dart';
import '../../teacher/teacher_insights.dart' show SkillStatus, SkillStatusText;
import '../../teacher/teacher_view_screen.dart' show RoundsBarChart;
import '../data/sinhala_progress.dart';
import '../game/sinhala_game_controller.dart';
import 'sinhala_insights.dart';

/// Teacher View for the Sinhala game: plain-language progress for the
/// phone's child, in the same layout as the English Teacher View.
class SinhalaTeacherScreen extends StatefulWidget {
  const SinhalaTeacherScreen({super.key, required this.controller});

  final SinhalaGameController controller;

  @override
  State<SinhalaTeacherScreen> createState() => _SinhalaTeacherScreenState();
}

class _P {
  const _P._();

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

/// Sinhala inside the teacher's English sentences: English keeps the app
/// font, Sinhala letters fall back to Noto Sans Sinhala.
const _si = TextStyle(fontFamilyFallback: [AppFonts.sinhala]);

class _SinhalaTeacherScreenState extends State<SinhalaTeacherScreen> {
  SinhalaGameController get game => widget.controller;
  SinhalaProgress get progress => game.progress;

  bool get _played => progress.results.isNotEmpty;

  Future<void> _rename() async {
    final controller = TextEditingController(text: progress.name ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Child\'s name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(hintText: progress.displayName),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save')),
        ],
      ),
    );
    if (name == null) return;
    setState(() => progress.name = name.trim().isEmpty ? null : name.trim());
    await game.saveProgress();
  }

  Future<void> _resetAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_forever_rounded, size: 36, color: _P.orange),
        title: const Text('Reset all Sinhala data?'),
        content: const Text('This deletes the child\'s Sinhala progress and results on this phone. '
            'The next game starts again with the warm-up. English data is not touched. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _P.orange),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await game.resetAll();
    if (!mounted) return;
    setState(() {});
    messenger.showSnackBar(const SnackBar(content: Text('All Sinhala spelling data was deleted.')));
  }

  void _credits() => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Credits'),
          content: const Text(
            'Pictures: Twemoji 15.0.0 (github.com/jdecked/twemoji), '
            '© Twitter, Inc. and other contributors, licensed CC-BY 4.0.\n\n'
            'Sinhala voice: recorded for AkuRin.',
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final bank = game.bank;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('👩‍🏫 Progress · සිංහල'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => v == 'reset' ? _resetAll() : _credits(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'credits', child: Text('Picture credits')),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever_rounded, color: _P.orange),
                    SizedBox(width: 10),
                    Text('Reset all data'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: bank == null || !_played
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('Nothing played yet.\nProgress shows here after the first game.',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: _P.soft, height: 1.4)),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: _cards(SinhalaInsights(progress: progress, bank: bank)),
            ),
    );
  }

  List<Widget> _cards(SinhalaInsights i) {
    final needs = i.needsHelp;
    final habits = i.habits;
    return [
      _card(
        child: Row(
          children: [
            Text(progress.avatar, style: const TextStyle(fontSize: 56)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(progress.displayName,
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: _P.ink)),
                      ),
                      IconButton(
                        tooltip: 'Change name',
                        icon: const Icon(Icons.edit_outlined, size: 20, color: _P.soft),
                        onPressed: _rename,
                      ),
                    ],
                  ),
                  Text(
                    '${i.sessionsPlayed} session${i.sessionsPlayed == 1 ? '' : 's'} played · last played ${i.lastPlayed}',
                    style: const TextStyle(fontSize: 16, color: _P.soft),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      _card(title: 'Latest round', child: _latestRound(i)),
      _card(
        title: 'Needs help with',
        child: needs.isEmpty
            ? _line('Nothing worrying right now 👍')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (final n in needs) _bullet(n.sentence, color: _P.orange)],
              ),
      ),
      _card(
        title: 'Mistake habits',
        child: habits.isEmpty
            ? _line('No repeated mistake habits right now.')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (final h in habits) _bullet('${h.sentence} (${h.countText})')],
              ),
      ),
      _card(title: 'Letters and pillas', child: _sounds(i)),
      _card(
        title: 'Progress',
        child: i.progressChart.isEmpty
            ? _line('The chart appears after the first round.')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Words right first time, each round', style: TextStyle(fontSize: 15, color: _P.soft)),
                  const SizedBox(height: 8),
                  RoundsBarChart(progress: i.progressChart),
                ],
              ),
      ),
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
                  Expanded(child: Text(tip, style: const TextStyle(fontSize: 16, color: _P.ink).merge(_si))),
                ],
              ),
            ],
          ],
        ),
      ),
    ];
  }

  Widget _latestRound(SinhalaInsights i) {
    final r = i.latest;
    if (r == null) return _line('No full round played yet.');
    final trend = i.trend;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _stat(r.firstTry, 'right first time', '⭐', _P.green, _P.greenBg),
            const SizedBox(width: 8),
            _stat(r.afterRetry, 'right after another try', '🔁', _P.blue, _P.blueBg),
            const SizedBox(width: 8),
            _stat(r.shown, 'answer shown', '💡', _P.orange, _P.orangeBg),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 14,
            child: Row(
              children: [
                if (r.firstTry > 0) Expanded(flex: r.firstTry, child: Container(color: _P.green)),
                if (r.afterRetry > 0) Expanded(flex: r.afterRetry, child: Container(color: _P.blue)),
                if (r.shown > 0) Expanded(flex: r.shown, child: Container(color: _P.orange)),
              ],
            ),
          ),
        ),
        if (trend != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                trend > 0
                    ? Icons.trending_up_rounded
                    : (trend < 0 ? Icons.trending_down_rounded : Icons.trending_flat_rounded),
                color: trend > 0 ? _P.green : (trend < 0 ? _P.orange : _P.soft),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(i.trendText!, style: const TextStyle(fontSize: 16, color: _P.ink))),
            ],
          ),
        ],
      ],
    );
  }

  Widget _stat(int value, String label, String emoji, Color color, Color background) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(14)),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              Text('$value', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: color)),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: _P.ink, height: 1.2)),
            ],
          ),
        ),
      );

  /// Stage progress bar plus the skills in three coloured groups.
  Widget _sounds(SinhalaInsights i) {
    final groups = [
      (SkillStatus.needsHelp, '🟠', _P.orangeBg),
      (SkillStatus.gettingThere, '📘', _P.blueBg),
      (SkillStatus.mastered, '✅', _P.greenBg),
    ];
    final later = i.skillsWith(SkillStatus.notStarted).length;
    final stages = i.bank.stageCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(i.stageText, style: const TextStyle(fontSize: 17, color: _P.ink, height: 1.35).merge(_si)),
        if (!i.nextIsWarmUp && stages > 0) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: i.currentStage / stages,
              minHeight: 14,
              color: _P.blue,
              backgroundColor: _P.grey,
            ),
          ),
        ],
        for (final (status, emoji, background) in groups)
          if (i.skillsWith(status).isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('$emoji  ${status.text}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _P.ink)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in i.skillsWith(status))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
                    child: Text(s.label, style: const TextStyle(fontSize: 16, color: _P.ink).merge(_si)),
                  ),
              ],
            ),
          ],
        if (later > 0) ...[
          const SizedBox(height: 14),
          Text('$later more stage${later == 1 ? '' : 's'} will come later.',
              style: const TextStyle(fontSize: 14, color: _P.soft)),
        ],
      ],
    );
  }

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
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _P.ink)),
              const SizedBox(height: 10),
            ],
            child,
          ],
        ),
      );

  Widget _line(String text) =>
      Text(text, style: const TextStyle(fontSize: 17, color: _P.ink, height: 1.35).merge(_si));

  Widget _bullet(String text, {Color color = _P.ink}) => Padding(
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
}
