enum AppointmentStatus { pending, approved, rejected }

class ClientProfile {
  const ClientProfile({
    required this.name,
    required this.email,
    required this.phone,
    required this.initials,
    required this.usesPasswordProvider,
    this.hasAvatar = true,
  });

  final String name;
  final String email;
  final String phone;
  final String initials;
  final bool usesPasswordProvider;
  final bool hasAvatar;
}

class ClientPass {
  const ClientPass({
    required this.name,
    required this.totalMinutes,
    required this.remainingMinutes,
    required this.expiresAtLabel,
    required this.statusLabel,
  });

  final String name;
  final int totalMinutes;
  final int remainingMinutes;
  final String expiresAtLabel;
  final String statusLabel;

  int get usedMinutes => totalMinutes - remainingMinutes;
  double get progress => usedMinutes / totalMinutes;
  bool get canBook => remainingMinutes >= 30;
}

class Appointment {
  const Appointment({
    required this.id,
    required this.serviceType,
    required this.durationMinutes,
    required this.dateLabel,
    required this.timeLabel,
    required this.status,
    required this.createdAtLabel,
    this.reason,
    this.assignedTrainer,
    this.sessionType,
    this.approvedDateLabel,
    this.approvedTimeLabel,
  });

  final String id;
  final String serviceType;
  final int durationMinutes;
  final String dateLabel;
  final String timeLabel;
  final AppointmentStatus status;
  final String createdAtLabel;
  final String? reason;
  final String? assignedTrainer;
  final String? sessionType;
  final String? approvedDateLabel;
  final String? approvedTimeLabel;
}

class PassHistoryItem {
  const PassHistoryItem({
    required this.name,
    required this.statusLabel,
    required this.periodLabel,
    required this.minutesLabel,
  });

  final String name;
  final String statusLabel;
  final String periodLabel;
  final String minutesLabel;
}

class BookingSlot {
  const BookingSlot({
    required this.dateLabel,
    required this.timeLabel,
    required this.stateLabel,
    required this.isEnabled,
  });

  final String dateLabel;
  final String timeLabel;
  final String stateLabel;
  final bool isEnabled;
}

class MockClientData {
  const MockClientData._();

  static const profile = ClientProfile(
    name: 'Laura Perez',
    email: 'laura.perez@email.com',
    phone: '+34 612 345 678',
    initials: 'LP',
    usesPasswordProvider: true,
  );

  static const activePass = ClientPass(
    name: 'Bono Mensual de Entrenamiento',
    totalMinutes: 360,
    remainingMinutes: 210,
    expiresAtLabel: 'Valido hasta el 30 abr 2026',
    statusLabel: 'Activo',
  );

  static const upcomingAppointments = [
    Appointment(
      id: 'FC-1042',
      serviceType: 'Bono Mensual de Entrenamiento',
      durationMinutes: 60,
      dateLabel: 'Viernes, 17 abr',
      timeLabel: '18:00 - 19:00',
      status: AppointmentStatus.approved,
      createdAtLabel: 'Solicitada el 10 abr 2026',
      reason: 'Trabajo de fuerza y movilidad de cadera.',
      assignedTrainer: 'Marta Sanchez',
      sessionType: 'Entrenamiento personal',
      approvedDateLabel: 'Viernes, 17 abr',
      approvedTimeLabel: '18:00 - 19:00',
    ),
    Appointment(
      id: 'FC-1047',
      serviceType: 'Bono Mensual de Entrenamiento',
      durationMinutes: 45,
      dateLabel: 'Lunes, 20 abr',
      timeLabel: '09:30 - 10:15',
      status: AppointmentStatus.pending,
      createdAtLabel: 'Solicitada el 12 abr 2026',
      reason: 'Preferencia por trabajo de tren superior.',
    ),
  ];

  static const historyAppointments = [
    Appointment(
      id: 'FC-1018',
      serviceType: 'Bono Mensual de Entrenamiento',
      durationMinutes: 60,
      dateLabel: 'Jueves, 02 abr',
      timeLabel: '19:00 - 20:00',
      status: AppointmentStatus.rejected,
      createdAtLabel: 'Solicitada el 29 mar 2026',
      reason: 'Franja completa.',
    ),
    Appointment(
      id: 'FC-1009',
      serviceType: 'Bono Mensual de Entrenamiento',
      durationMinutes: 30,
      dateLabel: 'Martes, 24 mar',
      timeLabel: '08:30 - 09:00',
      status: AppointmentStatus.approved,
      createdAtLabel: 'Solicitada el 20 mar 2026',
      assignedTrainer: 'Carlos Martin',
      sessionType: 'Tecnica y fuerza',
      approvedDateLabel: 'Martes, 24 mar',
      approvedTimeLabel: '08:30 - 09:00',
    ),
  ];

  static const passHistory = [
    PassHistoryItem(
      name: 'Bono Marzo',
      statusLabel: 'Agotado',
      periodLabel: '01 mar - 31 mar 2026',
      minutesLabel: '360 de 360 minutos usados',
    ),
    PassHistoryItem(
      name: 'Bono Febrero',
      statusLabel: 'Expirado',
      periodLabel: '01 feb - 28 feb 2026',
      minutesLabel: '300 de 360 minutos usados',
    ),
  ];

  static const bookingDates = [
    'Mar 14 abr',
    'Mie 15 abr',
    'Jue 16 abr',
    'Vie 17 abr',
    'Lun 20 abr',
  ];

  static const bookingSlots = [
    BookingSlot(
      dateLabel: 'Mar 14 abr',
      timeLabel: '08:30',
      stateLabel: 'Pasado',
      isEnabled: false,
    ),
    BookingSlot(
      dateLabel: 'Mar 14 abr',
      timeLabel: '18:00',
      stateLabel: 'Disponible',
      isEnabled: true,
    ),
    BookingSlot(
      dateLabel: 'Mar 14 abr',
      timeLabel: '19:00',
      stateLabel: '1 plaza',
      isEnabled: true,
    ),
    BookingSlot(
      dateLabel: 'Mar 14 abr',
      timeLabel: '20:00',
      stateLabel: 'Completo',
      isEnabled: false,
    ),
    BookingSlot(
      dateLabel: 'Mie 15 abr',
      timeLabel: '09:30',
      stateLabel: 'Disponible',
      isEnabled: true,
    ),
    BookingSlot(
      dateLabel: 'Mie 15 abr',
      timeLabel: '18:30',
      stateLabel: 'Tu sesion',
      isEnabled: false,
    ),
    BookingSlot(
      dateLabel: 'Jue 16 abr',
      timeLabel: '10:00',
      stateLabel: 'Disponible',
      isEnabled: true,
    ),
    BookingSlot(
      dateLabel: 'Vie 17 abr',
      timeLabel: '17:00',
      stateLabel: 'Bloqueado',
      isEnabled: false,
    ),
    BookingSlot(
      dateLabel: 'Lun 20 abr',
      timeLabel: '09:30',
      stateLabel: 'Disponible',
      isEnabled: true,
    ),
  ];
}
