import 'package:akurin/features/spelling/engine/error_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bed → deb: two reversals', () {
    final r = analyzeErrors('bed', 'deb', 'e');
    expect(r.count(ErrorType.reversal), 2);
    expect(r.editDistance, 2);
    expect(r.targetGraphemeError, isFalse); // the short "e" itself was right
  });

  test('fish → fis: omission inside the target grapheme', () {
    final r = analyzeErrors('fish', 'fis', 'sh');
    expect(r.count(ErrorType.omission), 1);
    expect(r.targetGraphemeError, isTrue);
  });

  test('frog → fog: omission', () {
    final r = analyzeErrors('frog', 'fog', 'cl|fl|pl|gl|sl|cr|dr|fr|gr|tr|sn|sp|st|sw|sk');
    expect(r.count(ErrorType.omission), 1);
    expect(r.editDistance, 1);
  });

  test('cake → cak: omission of the magic e is a target error', () {
    final r = analyzeErrors('cake', 'cak', 'a_e');
    expect(r.count(ErrorType.omission), 1);
    expect(r.targetGraphemeError, isTrue);
  });

  test('from → form: one transposition, not two substitutions', () {
    final r = analyzeErrors('from', 'form', '');
    expect(r.count(ErrorType.transposition), 1);
    expect(r.count(ErrorType.otherSub), 0);
    expect(r.editDistance, 1);
  });

  test('cat → cot: vowel substitution', () {
    final r = analyzeErrors('cat', 'cot', 'a');
    expect(r.count(ErrorType.vowelSub), 1);
    expect(r.targetGraphemeError, isTrue);
  });

  test('extra letter is an insertion; correct answer has no errors', () {
    expect(analyzeErrors('cat', 'cart', 'a').count(ErrorType.insertion), 1);
    final ok = analyzeErrors('ship', 'ship', 'sh');
    expect(ok.editDistance, 0);
    expect(ok.targetGraphemeError, isFalse);
  });

  test('error outside the target grapheme is not a target error', () {
    final r = analyzeErrors('ship', 'shib', 'sh');
    expect(r.count(ErrorType.otherSub), 1);
    expect(r.targetGraphemeError, isFalse);
  });

  test('tricky words have no target sound: any mistake counts as a target error', () {
    expect(analyzeErrors('said', 'sed', '').targetGraphemeError, isTrue);
    expect(analyzeErrors('said', 'said', '').targetGraphemeError, isFalse);
  });
}
