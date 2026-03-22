import 'package:flutter_test/flutter_test.dart';

import 'package:user_app1/main.dart';

void main() {
  testWidgets('Driver app builds', (WidgetTester tester) async {
    await tester.pumpWidget(
      const WasteDriverApp(initialApiBase: 'http://127.0.0.1:3000'),
    );
    expect(find.text('سائق النفايات الذكية'), findsOneWidget);
  });
}
