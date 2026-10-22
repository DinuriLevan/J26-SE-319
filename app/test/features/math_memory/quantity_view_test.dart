import 'dart:math';

import 'package:akurin/core/theme/app_theme.dart';
import 'package:akurin/features/math_memory/engine/math_picture.dart';
import 'package:akurin/features/math_memory/number_quest/engine/number_quest_models.dart';
import 'package:akurin/features/math_memory/number_quest/engine/number_question_generator.dart';
import 'package:akurin/features/math_memory/number_quest/widgets/quantity_view.dart';
import 'package:akurin/features/math_memory/widgets/math_pictures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Question card content width on a 360 dp phone and on a 411 dp phone.
const _smallWidth = 292.0;
const _mediumWidth = 343.0;

Future<void> pumpQuantity(WidgetTester tester, NumberQuestion q, {required double width, double maxHeight = 260}) {
  return tester.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: width,
          child: QuantityView(question: q, maxHeight: maxHeight),
        ),
      ),
    ),
  ));
}

double pictureSize(WidgetTester tester) => tester.getSize(find.byType(MathPictureView).first).width;

void main() {
  testWidgets('9 balloons are drawn big enough to count on a typical phone', (tester) async {
    const q = NumberQuestion(
      skill: MathSkill.counting,
      level: 2,
      a: 9,
      b: 0,
      answer: 9,
      choices: [8, 9, 11],
      picture: MathPicture.balloon,
      showObjects: true,
    );
    await pumpQuantity(tester, q, width: _mediumWidth);
    expect(pictureSize(tester), greaterThanOrEqualTo(55), reason: 'was 34 dp before');
  });

  testWidgets('a few objects get the largest pictures; many get smaller ones', (tester) async {
    NumberQuestion counting(int n) => NumberQuestion(
          skill: MathSkill.counting,
          level: 1,
          a: n,
          b: 0,
          answer: n,
          choices: [n, n + 1, n + 2],
          picture: MathPicture.apple,
          showObjects: true,
        );
    await pumpQuantity(tester, counting(3), width: _mediumWidth);
    final few = pictureSize(tester);
    await pumpQuantity(tester, counting(18), width: _mediumWidth);
    final many = pictureSize(tester);
    expect(few, 72);
    expect(many, lessThan(few));
    expect(many, greaterThanOrEqualTo(40));
  });

  for (final width in [_smallWidth, _mediumWidth]) {
    testWidgets('every visual question fits without overflow at $width dp', (tester) async {
      final generator = NumberQuestionGenerator(Random(11));
      for (final skill in MathSkill.values) {
        for (var level = 1; level <= 3; level++) {
          for (var i = 0; i < 12; i++) {
            final q = generator.generate(skill, level, forceVisual: true);
            if (!q.showObjects) continue;
            await pumpQuantity(tester, q, width: width);
            expect(tester.takeException(), isNull, reason: q.toJson().toString());

            final view = tester.getRect(find.byType(QuantityView));
            final content = tester.getRect(find.byType(MathPictureView).last);
            expect(content.right, lessThanOrEqualTo(view.right + 0.5), reason: q.toJson().toString());
            expect(content.bottom - view.top, lessThanOrEqualTo(260 + 40), reason: q.toJson().toString());
            expect(pictureSize(tester), greaterThanOrEqualTo(22));
          }
        }
      }
    });
  }
}
