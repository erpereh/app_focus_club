# Reprogramación de citas recurrentes

## Objetivo

La app permite reprogramar una sesión recurrente concreta o sustituir la
programación futura de su serie mediante los callables de producción, sin
escrituras directas sobre citas, bonos u ocupación.

## Alcance funcional

- Una cita `pending` o `approved` se puede modificar únicamente si su inicio
  real en Europe/Madrid está a más de 24 horas.
- En una cita recurrente se elige entre "Solo esta sesión" y "Toda la serie".
- La opción de serie requiere el documento de serie y que todas sus sesiones
  futuras activas sustituibles estén fuera de la ventana inclusiva de 24 horas.
- La modificación recurrente conserva servicio, duración, `sessionType` y
  trazabilidad. En el reemplazo completo también se mantiene el bono asociado y
  se puede elegir inicio, intervalo y fecha final.
- Cuando una occurrence pasa de `approved` a `pending`, se elimina su
  aprobación y la asignación de entrenador. El backend decidirá de nuevo la
  asignación cuando Admin vuelva a aprobarla.
- La disponibilidad se vuelve a validar inmediatamente antes de enviar y el
  estado local no se actualiza de forma optimista.

## Autoridad temporal

Toda decisión nueva de pasado/futuro y de ventana de modificación convierte la
fecha y hora civil mediante Europe/Madrid. La conversión aplica CET/CEST sin
depender del huso del dispositivo, rechaza horas inexistentes de primavera y,
en horas repetidas de otoño, usa el primer instante real.

La ventana de bloqueo es inclusiva: un inicio exactamente a 24 horas queda
bloqueado, tanto para el origen como para el destino.

## Contratos de backend

Reprogramación de una occurrence:

```text
rescheduleOwnRecurringAppointment
{
  appointmentId,
  preferredSlot: { date, time },
  scope: "single"
}
```

Sustitución de la programación futura:

```text
replaceOwnRecurringSeriesSchedule
{
  appointmentId,
  startSlot: { date, time },
  intervalDays,
  endDate
}
```

Ambos callables se invocan en `europe-west1`. La respuesta de sustitución se
valida de forma tipada, incluidos identificadores afectados, reutilizados,
creados y cancelados, número de sesiones, minutos totales y estado.

## Paridad de disponibilidad

Toda decisión de conflicto, capacidad, ocupación efectiva y crédito usa
`getCanonicalSlotBlocks`. Las claves son únicamente bloques canónicos exactos
de 15 minutos desde el inicio real de la sesión, sin floors legacy de 30.

Al excluir citas aprobadas que se sustituyen se acredita una unidad en cada una
de sus claves canónicas. Las pendientes se excluyen sin crédito. La
ocupación efectiva de una clave es `max(0, ocupación real - crédito)` y la del
slot es el máximo de todas sus claves.

Prioridad visual: inválido/pasado, bloqueado, conflicto propio, completo,
disponible, casi lleno y plazas restantes. Las etiquetas son `Disponible`,
`3 plazas`, `2 plazas`, `Casi lleno · 1 plaza`, `Tu sesión`, `Bloqueado`,
`Completo` y `No disponible`.

## No incluido

No se modifican Firebase Functions, reglas, Auth, Google Calendar, Admin web,
datos de negocio directamente, versión/build ni procesos de deploy o release.
