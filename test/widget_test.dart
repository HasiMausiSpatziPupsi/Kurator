import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:inventur_app_v1/app.dart';

void main() {
  testWidgets('App startet mit Bibliothek-Titel', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: InventurApp()),
    );
    await tester.pump();
    expect(find.text('Bibliothek'), findsOneWidget);
  });
}
