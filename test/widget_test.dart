import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medsync_flutter/main.dart';

void main() {
  testWidgets('abre a tela inicial do MedSync', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = MedStore(ApiClient(prefs));
    await tester.pumpWidget(AppScope(notifier: store, child: const MedSyncApp()));
    await tester.pumpAndSettle();
    expect(find.text('MedSync'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
