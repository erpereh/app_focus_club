import 'package:app_focus_club/app/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the Flutter base placeholder', (tester) async {
    await tester.pumpWidget(const FocusClubApp());

    expect(find.text('Base Flutter lista'), findsOneWidget);
    expect(find.text('Portal movil de clientes'), findsOneWidget);
    expect(find.text('Preparado para empezar'), findsOneWidget);
  });
}
