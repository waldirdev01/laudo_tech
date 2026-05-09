import 'package:flutter_test/flutter_test.dart';
import 'package:laudo_tech/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const LaudoTechApp());

    expect(find.text('Bem-vindo ao Laudo Tech'), findsOneWidget);
    expect(find.text('Cadastrar Perito'), findsOneWidget);
  });
}
