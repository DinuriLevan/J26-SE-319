import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:akurin/main.dart';

void main() {
  testWidgets('app boots to the splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: AkuRinApp()));
    await tester.pump();

    expect(find.text('AkuRin'), findsOneWidget);
  });
}
