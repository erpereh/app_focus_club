enum AppointmentStatus {
  pending,
  approved,
  rejected,
  cancelled;

  static AppointmentStatus fromWire(String value) {
    return AppointmentStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => throw FormatException('Unknown appointment status: $value'),
    );
  }
}

enum BonoStatus {
  activo,
  agotado,
  expirado,
  eliminado;

  static BonoStatus fromWire(String value) {
    return BonoStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => throw FormatException('Unknown bono status: $value'),
    );
  }
}

class TimeSlot {
  const TimeSlot({required this.date, required this.time});

  final String date;
  final String time;

  factory TimeSlot.fromMap(Map<String, Object?> map) {
    return TimeSlot(date: map['date'] as String, time: map['time'] as String);
  }

  Map<String, Object?> toMap() => {'date': date, 'time': time};

  String get key => '${date}_$time';

  @override
  bool operator ==(Object other) {
    return other is TimeSlot && other.date == date && other.time == time;
  }

  @override
  int get hashCode => Object.hash(date, time);
}

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    required this.isTrainer,
    required this.createdAt,
    this.phone,
    this.photoUrl,
    this.pushNotificationsEnabled = false,
  });

  final String uid;
  final String email;
  final String name;
  final String? phone;
  final String role;
  final bool isTrainer;
  final String createdAt;
  final String? photoUrl;
  final bool pushNotificationsEnabled;

  factory UserProfile.fromMap(Map<String, Object?> map) {
    return UserProfile(
      uid: map['uid'] as String,
      email: map['email'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      role: map['role'] as String? ?? 'user',
      isTrainer: map['isTrainer'] as bool? ?? false,
      createdAt: stringifyDate(map['createdAt']) ?? '',
      photoUrl: map['photoURL'] as String?,
      pushNotificationsEnabled:
          map['pushNotificationsEnabled'] as bool? ?? false,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      if (phone != null) 'phone': phone,
      'role': role,
      'isTrainer': isTrainer,
      'createdAt': createdAt,
      if (photoUrl != null) 'photoURL': photoUrl,
      'pushNotificationsEnabled': pushNotificationsEnabled,
    };
  }
}

class Appointment {
  const Appointment({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    required this.phone,
    required this.serviceType,
    required this.durationMinutes,
    required this.preferredSlots,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.approvedSlot,
    this.assignedTrainer,
    this.sessionType,
    this.trainerNotes,
    this.updatedAt,
    this.legacyDate,
    this.legacyTime,
  });

  final String id;
  final String userId;
  final String name;
  final String email;
  final String phone;
  final String serviceType;
  final int durationMinutes;
  final List<TimeSlot> preferredSlots;
  final String reason;
  final AppointmentStatus status;
  final TimeSlot? approvedSlot;
  final String? assignedTrainer;
  final String? sessionType;
  final String? trainerNotes;
  final String createdAt;
  final String? updatedAt;
  final String? legacyDate;
  final String? legacyTime;

  factory Appointment.fromMap(String id, Map<String, Object?> map) {
    final rawSlots = (map['preferredSlots'] as List<Object?>? ?? const []);
    return Appointment(
      id: id,
      userId: map['userId'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      phone: map['phone'] as String,
      serviceType: map['serviceType'] as String,
      durationMinutes: parseDurationMinutes(map['duration']),
      preferredSlots: rawSlots
          .cast<Map<Object?, Object?>>()
          .map((slot) => TimeSlot.fromMap(slot.cast<String, Object?>()))
          .toList(growable: false),
      reason: map['reason'] as String? ?? '',
      status: AppointmentStatus.fromWire(map['status'] as String),
      approvedSlot: map['approvedSlot'] is Map<Object?, Object?>
          ? TimeSlot.fromMap(
              (map['approvedSlot']! as Map<Object?, Object?>)
                  .cast<String, Object?>(),
            )
          : null,
      assignedTrainer: map['assignedTrainer'] as String?,
      sessionType: map['sessionType'] as String?,
      trainerNotes: map['trainerNotes'] as String?,
      createdAt: stringifyDate(map['createdAt']) ?? '',
      updatedAt: stringifyDate(map['updatedAt']),
      legacyDate: map['date'] as String?,
      legacyTime: map['time'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'userId': userId,
      'name': name,
      'email': email,
      'phone': phone,
      'serviceType': serviceType,
      'duration': durationMinutes.toString(),
      'preferredSlots': preferredSlots.map((slot) => slot.toMap()).toList(),
      'reason': reason,
      'status': status.name,
      if (approvedSlot != null) 'approvedSlot': approvedSlot!.toMap(),
      if (assignedTrainer != null) 'assignedTrainer': assignedTrainer,
      if (sessionType != null) 'sessionType': sessionType,
      if (trainerNotes != null) 'trainerNotes': trainerNotes,
      'createdAt': createdAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }

  TimeSlot? get schedulingSlot {
    final legacySlot = legacyDate == null || legacyTime == null
        ? null
        : TimeSlot(date: legacyDate!, time: legacyTime!);
    return switch (status) {
      AppointmentStatus.approved =>
        approvedSlot ?? preferredSlots.firstOrNull ?? legacySlot,
      AppointmentStatus.pending => preferredSlots.firstOrNull ?? legacySlot,
      AppointmentStatus.rejected || AppointmentStatus.cancelled =>
        approvedSlot ?? preferredSlots.firstOrNull ?? legacySlot,
    };
  }

  DateTime? get schedulingDateTime => appointmentSlotDateTime(schedulingSlot);
}

DateTime? appointmentSlotDateTime(TimeSlot? slot) {
  if (slot == null) return null;
  final dateMatch = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(slot.date);
  final timeMatch = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(slot.time);
  if (dateMatch == null || timeMatch == null) return null;

  final year = int.parse(dateMatch.group(1)!);
  final month = int.parse(dateMatch.group(2)!);
  final day = int.parse(dateMatch.group(3)!);
  final hour = int.parse(timeMatch.group(1)!);
  final minute = int.parse(timeMatch.group(2)!);
  if (month < 1 || month > 12 || hour > 23 || minute > 59) return null;

  final parsed = DateTime(year, month, day, hour, minute);
  return parsed.year == year &&
          parsed.month == month &&
          parsed.day == day &&
          parsed.hour == hour &&
          parsed.minute == minute
      ? parsed
      : null;
}

class Bono {
  const Bono({
    required this.id,
    required this.userId,
    required this.tamano,
    required this.minutosTotales,
    required this.minutosRestantes,
    required this.fechaAsignacion,
    required this.fechaExpiracion,
    required this.estado,
    required this.historial,
    required this.asignadoPor,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final int tamano;
  final int minutosTotales;
  final int minutosRestantes;
  final String fechaAsignacion;
  final String fechaExpiracion;
  final BonoStatus estado;
  final List<BonoHistorialEntry> historial;
  final String asignadoPor;
  final String createdAt;

  factory Bono.fromMap(String id, Map<String, Object?> map) {
    final rawHistorial = (map['historial'] as List<Object?>? ?? const []);
    return Bono(
      id: id,
      userId: map['userId'] as String,
      tamano: parseIntOrZero(map['tamano']),
      minutosTotales: parseIntOrZero(map['minutosTotales']),
      minutosRestantes: parseIntOrZero(map['minutosRestantes']),
      fechaAsignacion: stringifyDate(map['fechaAsignacion']) ?? '',
      fechaExpiracion: stringifyDate(map['fechaExpiracion']) ?? '',
      estado: BonoStatus.fromWire(map['estado'] as String),
      historial: rawHistorial
          .whereType<Map<Object?, Object?>>()
          .map((entry) => BonoHistorialEntry.fromMap(entry.cast()))
          .toList(growable: false),
      asignadoPor: map['asignadoPor'] as String? ?? '',
      createdAt: stringifyDate(map['createdAt']) ?? '',
    );
  }

  bool get isActive => estado == BonoStatus.activo;
  bool get canBook => isActive && minutosRestantes >= 30;
}

class BonoHistorialEntry {
  const BonoHistorialEntry({
    required this.fecha,
    required this.tipo,
    required this.minutos,
    this.appointmentId,
    this.descripcion,
  });

  final String fecha;
  final String tipo;
  final int minutos;
  final String? appointmentId;
  final String? descripcion;

  factory BonoHistorialEntry.fromMap(Map<String, Object?> map) {
    return BonoHistorialEntry(
      fecha: stringifyDate(map['fecha']) ?? '',
      tipo: map['tipo'] as String? ?? '',
      minutos: parseInt(map['minutos'] ?? map['duracion']),
      appointmentId: map['appointmentId'] as String?,
      descripcion: map['descripcion'] as String?,
    );
  }
}

class Trainer {
  const Trainer({
    required this.id,
    required this.uid,
    required this.name,
    required this.active,
    required this.createdAt,
    required this.specialties,
  });

  final String id;
  final String uid;
  final String name;
  final bool active;
  final String createdAt;
  final List<String> specialties;

  factory Trainer.fromMap(String id, Map<String, Object?> map) {
    return Trainer(
      id: id,
      uid: map['uid'] as String,
      name: map['name'] as String,
      active: map['active'] as bool? ?? true,
      createdAt: stringifyDate(map['createdAt']) ?? '',
      specialties: (map['specialties'] as List<Object?>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
    );
  }
}

class BlockedSlot {
  const BlockedSlot({
    required this.id,
    required this.date,
    required this.time,
    this.reason,
    this.createdBy,
    this.createdAt,
  });

  final String id;
  final String date;
  final String time;
  final String? reason;
  final String? createdBy;
  final String? createdAt;

  factory BlockedSlot.fromMap(String id, Map<String, Object?> map) {
    return BlockedSlot(
      id: id,
      date: map['date'] as String,
      time: map['time'] as String,
      reason: map['reason'] as String?,
      createdBy: map['createdBy'] as String?,
      createdAt: stringifyDate(map['createdAt']),
    );
  }

  TimeSlot get slot => TimeSlot(date: date, time: time);
}

class SlotOccupancy {
  const SlotOccupancy({
    required this.id,
    required this.date,
    required this.time,
    required this.count,
  });

  final String id;
  final String date;
  final String time;
  final int count;

  factory SlotOccupancy.fromMap(String id, Map<String, Object?> map) {
    return SlotOccupancy(
      id: id,
      date: map['date'] as String,
      time: map['time'] as String,
      count: parseInt(map['count']),
    );
  }

  TimeSlot get slot => TimeSlot(date: date, time: time);
}

const int defaultMaxCapacity = 2;
const int minAllowedCapacity = 1;
const int maxAllowedCapacity = 10;

class SiteConfig {
  const SiteConfig({
    required this.startHour,
    required this.endHour,
    required this.slotInterval,
    required this.bonoExpirationMonths,
    required this.maintenanceMode,
    this.maxCapacity = defaultMaxCapacity,
    this.minAndroidBuild = 0,
    this.minIosBuild = 0,
    this.latestAndroidBuild = 0,
    this.latestIosBuild = 0,
    this.androidStoreUrl,
    this.iosStoreUrl,
    this.sessionDuration,
    this.logoUrl,
    this.logoStoragePath,
    this.updatedAt,
  });

  final int startHour;
  final int endHour;
  final int slotInterval;
  final int bonoExpirationMonths;
  final bool maintenanceMode;
  final int maxCapacity;
  final int minAndroidBuild;
  final int minIosBuild;
  final int latestAndroidBuild;
  final int latestIosBuild;
  final String? androidStoreUrl;
  final String? iosStoreUrl;
  final int? sessionDuration;
  final String? logoUrl;
  final String? logoStoragePath;
  final String? updatedAt;

  factory SiteConfig.fromMap(Map<String, Object?> map) {
    return SiteConfig(
      startHour: parseInt(map['startHour']),
      endHour: parseInt(map['endHour']),
      slotInterval: parseInt(map['slotInterval']),
      bonoExpirationMonths: parseInt(map['bonoExpirationMonths']),
      maintenanceMode: map['maintenanceMode'] as bool? ?? false,
      maxCapacity: parseMaxCapacity(map['maxCapacity']),
      minAndroidBuild: parseNonNegativeIntOrZero(map['minAndroidBuild']),
      minIosBuild: parseNonNegativeIntOrZero(map['minIosBuild']),
      latestAndroidBuild: parseNonNegativeIntOrZero(map['latestAndroidBuild']),
      latestIosBuild: parseNonNegativeIntOrZero(map['latestIosBuild']),
      androidStoreUrl: parseOptionalTrimmedString(map['androidStoreUrl']),
      iosStoreUrl: parseOptionalTrimmedString(map['iosStoreUrl']),
      sessionDuration: map['sessionDuration'] == null
          ? null
          : parseInt(map['sessionDuration']),
      logoUrl: map['logoUrl'] as String?,
      logoStoragePath: map['logoStoragePath'] as String?,
      updatedAt: stringifyDate(map['updatedAt']),
    );
  }
}

int parseDurationMinutes(Object? value) {
  final minutes = parseInt(value);
  if (minutes != 30 && minutes != 45 && minutes != 60) {
    throw FormatException('Unsupported appointment duration: $value');
  }
  return minutes;
}

int parseInt(Object? value) {
  return switch (value) {
    int() => value,
    String() => int.parse(value),
    num() => value.toInt(),
    _ => throw FormatException('Expected integer-compatible value: $value'),
  };
}

int parseIntOrZero(Object? value) {
  try {
    return parseInt(value);
  } on FormatException {
    return 0;
  }
}

int parseNonNegativeIntOrZero(Object? value) {
  final parsed = parseIntOrZero(value);
  return parsed < 0 ? 0 : parsed;
}

int parseMaxCapacity(Object? value) {
  if (value == null) return defaultMaxCapacity;
  try {
    return parseInt(value).clamp(minAllowedCapacity, maxAllowedCapacity);
  } on FormatException {
    return defaultMaxCapacity;
  }
}

String? parseOptionalTrimmedString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? stringifyDate(Object? value) {
  if (value == null) return null;
  if (value is String) return value;
  return value.toString();
}
