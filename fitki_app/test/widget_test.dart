import 'package:flutter_test/flutter_test.dart';
import 'package:fitki_app/main.dart';

void main() {
  testWidgets('Splash Screen displays App Title', (WidgetTester tester) async {
    // Construir la app y disparar un frame
    await tester.pumpWidget(const FitkiApp());

    // Verificar que el título 'FITKI' se dibuje en pantalla
    expect(find.text('FITKI'), findsOneWidget);
  });
}
