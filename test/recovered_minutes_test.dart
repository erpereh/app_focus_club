import 'package:flutter_test/flutter_test.dart';
import 'package:app_focus_club/features/client/domain/portal_models.dart';
import 'package:app_focus_club/features/client/widgets/appointment_display.dart';

void main() {
  for (final remaining in [300, 240, 180, 0]) {
    test('240 contracted + 60 recovered keeps $remaining available', () {
      final bono = Bono.fromMap('b', {
        'userId': 'u',
        'tamano': 240,
        'minutosCapacidadBase': 240,
        'minutosExtraRecuperados': 60,
        'minutosTotales': 300,
        'minutosRestantes': remaining,
        'estado': 'activo',
      });
      expect(bono.effectiveTotalMinutes, 300);
      expect(bono.displayTotalMinutes, 300);
      expect(bono.displayRemainingMinutes, remaining);
      expect(bono.usedMinutes, 300 - remaining);
      expect(bono.nameLabel, '240 min contratados + 60 recuperados');
      expect(bono.progress, inInclusiveRange(0, 1));
      expect(bono.canBook, remaining >= 30);
    });
  }
  test('legacy manually extended capacity is preserved', () {
    final bono = Bono.fromMap('b', {
      'userId': 'u',
      'tamano': 240,
      'minutosTotales': 270,
      'minutosRestantes': 270,
      'estado': 'activo',
    });
    expect(bono.displayTotalMinutes, 270);
    expect(bono.displayRemainingMinutes, 270);
    expect(bono.nameLabel, '240 min contratados + 30 de ampliaciones previas');
  });
  test('an audited zero-credit attempt never claims a 60 minute refund', () {
    final entry = BonoHistorialEntry.fromMap({
      'tipo': 'Intento de devolución · sin abono',
      'duracion': '60',
      'minutosAbonados': 0,
    });
    expect(entry.minutos, 0);
  });
}
