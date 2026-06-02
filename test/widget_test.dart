// Smoke test for ChaliyNav splash.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chaliy_nav/app.dart';

void main() {
  testWidgets('App boots into splash', (WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(child: ChaliyNavApp()));
    await tester.pump();
    expect(find.text('ChaliyNav'), findsOneWidget);
  });
}
