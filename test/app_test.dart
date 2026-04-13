import 'package:app_focus_club/app/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders splash and moves to auth', (tester) async {
    await tester.pumpWidget(const FocusClubApp());

    expect(find.text('Focus Club'), findsOneWidget);
    expect(find.text('Portal del Cliente'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 950));
    await tester.pumpAndSettle();

    expect(find.text('Focus Club Vallecas'), findsOneWidget);
    expect(find.text('Iniciar Sesion'), findsOneWidget);
    expect(find.text('Registrarse'), findsOneWidget);
  });

  testWidgets('switches between login and register', (tester) async {
    await _pumpAuth(tester);

    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Crear Cuenta'), findsNothing);

    await tester.tap(find.text('Registrarse'));
    await tester.pumpAndSettle();

    expect(find.text('Nombre completo'), findsOneWidget);
    expect(find.text('Crear Cuenta'), findsOneWidget);
  });

  testWidgets('navigates to reset password', (tester) async {
    await _pumpAuth(tester);

    await tester.tap(find.text('Has olvidado tu contrasena?'));
    await tester.pumpAndSettle();

    expect(find.text('Recuperar Contrasena'), findsOneWidget);
    expect(find.text('Enviar enlace'), findsOneWidget);
  });

  testWidgets('google button opens complete profile flow', (tester) async {
    await _pumpAuth(tester);

    await tester.tap(find.text('Continuar con Google'));
    await tester.pumpAndSettle();

    expect(find.text('Completa tu Perfil'), findsOneWidget);
    expect(find.text('Guardar y Continuar'), findsOneWidget);
  });

  testWidgets('register form validates main fields', (tester) async {
    await _pumpAuth(tester);

    await tester.tap(find.text('Registrarse'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Crear Cuenta'));
    await tester.tap(find.text('Crear Cuenta'));
    await tester.pumpAndSettle();

    expect(find.text('Introduce tu nombre completo.'), findsOneWidget);
    expect(find.text('Introduce tu email.'), findsOneWidget);
    expect(find.text('Introduce un telefono espanol valido.'), findsOneWidget);
    expect(
      find.text('La contrasena debe tener al menos 8 caracteres.'),
      findsOneWidget,
    );
    expect(
      find.text('Debes aceptar la Politica de Privacidad.'),
      findsOneWidget,
    );
  });
}

Future<void> _pumpAuth(WidgetTester tester) async {
  await tester.pumpWidget(const FocusClubApp());
  await tester.pump(const Duration(milliseconds: 950));
  await tester.pumpAndSettle();
}
