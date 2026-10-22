import 'package:akurin/features/spelling/engine/model_evaluation.dart';
import 'package:akurin/features/spelling/engine/simulator.dart';
import 'package:flutter_test/flutter_test.dart';

import 'spelling_test_helpers.dart';

void main() {
  final bank = loadTestBank();

  test('precision / recall / F1 counting', () {
    final prf = Prf()
      ..add({'a', 'b'}, {'a', 'c'})
      ..add({}, {});
    expect(prf.precision, 0.5);
    expect(prf.recall, 0.5);
    expect(prf.f1, 0.5);
    expect(Prf().f1, isNull);
  });

  test('evaluation runs pretend children and exports a CSV', () async {
    final ev = ModelEvaluation(bank);
    final on = await ev.runPreset(SimulatedChildProfile.presets.first, useBehaviour: true, children: 8);
    expect(on.detection.keys, [2, 4, 6]);
    expect(on.roundsToFocus.length, 8);
    expect(on.detection[2]!.tp + on.detection[2]!.fn, greaterThan(0));
    final strong = await ev.runPreset(SimulatedChildProfile.presets.last, useBehaviour: true, children: 4);
    expect(strong.detection[6]!.fp, 0); // no false alarms for a strong child

    final csv = ModelEvaluation.toCsv([on, strong], []).split('\n');
    expect(csv.first, startsWith('table,preset,use_behaviour'));
    expect(csv[1], startsWith('behaviour,"Weak at ""sh"" + mixes up b/d",true'));
  });
}
