import 'package:app_focus_club/features/client/domain/portal_availability.dart';
import 'package:app_focus_club/features/client/domain/portal_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final duration in [30, 45, 60]) {
    for (final status in ['pending', 'approved']) {
      test(
        '$status holds one seat across $duration minutes, even after capacity decreases',
        () {
          const slot = TimeSlot(date: '2026-12-01', time: '10:00');
          final appointment = Appointment.fromMap('a', {
            'userId': 'u',
            'name': 'Cliente',
            'email': 'u@example.com',
            'phone': '',
            'serviceType': 'Training',
            'status': status,
            'duration': '$duration',
            'preferredSlots': [slot.toMap()],
            if (status == 'approved') 'approvedSlot': slot.toMap(),
          });
          final credits = buildOccupancyCreditsByKey([appointment]);
          expect(credits.length, duration ~/ 15);
          expect(credits.values.every((value) => value == 1), isTrue);
          final occupancy = getCanonicalSlotBlocks('10:00', duration)
              .map(
                (time) => SlotOccupancy.fromMap('2026-12-01_$time', {
                  'date': slot.date,
                  'time': time,
                  'count': 3,
                }),
              )
              .toList();
          final state = bookingSlotState(
            slot: slot,
            durationMinutes: duration,
            siteConfig: SiteConfig.fromMap({
              'startHour': 7,
              'endHour': 22,
              'slotInterval': 15,
              'bonoExpirationMonths': 3,
              'maxCapacity': 1,
            }),
            blockedSlots: [],
            occupancy: occupancy,
            appointments: [],
            occupancyCreditsByKey: credits,
            now: DateTime.utc(2026, 11, 18),
          );
          expect(state.isEnabled, isTrue);
        },
      );
    }
  }
}
