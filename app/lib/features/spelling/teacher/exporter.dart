import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../data/skill_labels.dart';
import '../engine/feature_extractor.dart';
import '../engine/spelling_engine.dart';
import 'teacher_insights.dart';

/// Writes the report and the data exports to the app's files folder. On Android this is
/// Android/data/com.akurin.akurin/files/spelling_exports, readable over USB
/// or with `adb pull`.
class SpellingExporter {
  SpellingExporter(this.engine);

  final SpellingEngine engine;

  Future<Directory> _dir() async {
    Directory? base;
    try {
      base = await getExternalStorageDirectory();
    } catch (_) {}
    base ??= await getApplicationDocumentsDirectory();
    return Directory('${base.path}/spelling_exports').create(recursive: true);
  }

  String get _stamp => DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;

  /// All feature rows, all children.
  Future<File> featuresCsv() async {
    final rows = await engine.storage.loadRows();
    final lines = [
      FeatureRow.columns.join(','),
      for (final r in rows) r.toCsvCells().join(','),
    ];
    final f = File('${(await _dir()).path}/spelling_features_$_stamp.csv');
    return f.writeAsString('${lines.join('\n')}\n');
  }

  /// Raw per-word event lists, all children.
  Future<File> eventsJson() async {
    final events = await engine.storage.loadEvents();
    final f = File('${(await _dir()).path}/spelling_events_$_stamp.json');
    return f.writeAsString(const JsonEncoder.withIndent('  ').convert(events));
  }

  /// Full learner-model state of every child plus the current settings.
  Future<File> modelJson() async {
    final f = File('${(await _dir()).path}/spelling_model_$_stamp.json');
    return f.writeAsString(const JsonEncoder.withIndent('  ').convert({
      'settings': engine.settings.toJson(),
      'children': [for (final c in engine.children) c.toJson()],
    }));
  }

  /// A printable one-page report for parents (open in a browser → Print /
  /// Save as PDF).
  Future<File> reportHtml(TeacherInsights i) async {
    String esc(String s) =>
        s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
    String list(List<String> items, String empty) =>
        items.isEmpty ? '<p>${esc(empty)}</p>' : '<ul>${items.map((s) => '<li>${esc(s)}</li>').join()}</ul>';

    final c = i.child;
    final latest = i.latest;
    String group(SkillStatus status) => i.skillsWith(status).map((s) => esc(skillLabel(s).full)).join(', ');
    final sounds = [
      for (final st in [SkillStatus.needsHelp, SkillStatus.gettingThere, SkillStatus.mastered])
        if (i.skillsWith(st).isNotEmpty) '<li><b>${st.text}:</b> ${group(st)}</li>',
    ];
    final bars = i.progress
        .map((p) => '<div class="bar"><span>${p.$2}</span><i style="height:${p.$2 * 10}px"></i><b>R${p.$1}</b></div>')
        .join();
    final html = '''<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Spelling report – ${esc(c.displayName)}</title>
<style>
body{font-family:system-ui,Arial,sans-serif;color:#243042;max-width:720px;margin:24px auto;padding:0 16px;line-height:1.45}
h1{font-size:26px;margin:0} h2{font-size:19px;margin:22px 0 6px;border-bottom:1px solid #e1e5ee;padding-bottom:4px}
.meta{color:#5b6678} .chart{display:flex;align-items:flex-end;gap:8px;height:140px}
.bar{display:flex;flex-direction:column;align-items:center;font-size:12px} .bar i{display:block;width:26px;background:#5b9be6;border-radius:4px;margin:2px 0}
@media print{body{margin:0}}
</style></head><body>
<h1>${c.avatar} ${esc(c.displayName)} — spelling progress</h1>
<p class="meta">${i.sessionsPlayed} session(s) played · last played ${esc(i.lastPlayed)} · report made ${DateTime.now().toString().split(' ').first}</p>
${latest == null ? '' : '<p><b>Latest round:</b> ${latest.firstTry} of ${latest.total} right first time, ${latest.afterRetry} right after another try, ${latest.shown} answer${latest.shown == 1 ? '' : 's'} shown.${i.trendText == null ? '' : ' ${esc(i.trendText!)}.'}</p>'}
<h2>Needs help with</h2>${list(i.needsHelp.map((n) => n.sentence).toList(), 'Nothing worrying right now.')}
<h2>Mistake habits</h2>${list([...i.habits.map((h) => '${h.sentence} (${h.countText})'), ...i.hesitationNotes], 'No repeated mistake habits right now.')}
<h2>Sounds</h2><p>${esc(i.stageText)}</p>${sounds.isEmpty ? '<p>Sounds appear here after the first round.</p>' : '<ul>${sounds.join()}</ul>'}${i.improving.isEmpty ? '' : '<p class="meta">Getting better lately: ${i.improving.map((s) => esc(skillLabel(s).full)).join(', ')}</p>'}
<h2>Progress</h2>${bars.isEmpty ? '<p>The chart appears after the first round.</p>' : '<p class="meta">Words right first time (out of 10), each round</p><div class="chart">$bars</div>'}
<h2>What's next</h2><p>${esc(i.nextSentence)}</p>${list(i.tips.map((t) => 'Tip: $t').toList(), '')}
</body></html>
''';
    final safe = c.displayName.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    final f = File('${(await _dir()).path}/spelling_report_${safe}_$_stamp.html');
    return f.writeAsString(html);
  }
}
