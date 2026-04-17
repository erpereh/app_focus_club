# Implantación segura del flujo de reserva web

## Estado real verificado antes del cambio

- La reserva del portal se creaba desde `src/app/portal/page.tsx` con `handleSubmitAppointment`.
- Ese flujo terminaba en `addAppointment()` de `src/lib/firestore.ts`, que hacía `addDoc()` directo sobre `appointments`.
- No existía infraestructura previa de Firebase Functions en el repo.
- El webhook de Make estaba expuesto en frontend admin en `src/app/admin/page.tsx`.
- Make solo se usaba para eventos de citas:
  - aprobación -> `confirmed`
  - borrado individual o masivo -> `deleted`
- `slot_occupancy` sigue siendo la fuente de verdad del aforo visible, pero solo para citas `approved`.

## Qué se ha cambiado

### Frontend

- El portal mantiene la misma UI y UX.
- `Enviar Solicitud` ya no escribe en Firestore directamente.
- Ahora llama a una Firebase Callable Function `createAppointment`.
- Los errores críticos devueltos por backend se muestran en español dentro del drawer.

### Backend

- Se ha creado una base mínima de Firebase Functions en `functions/`.
- Nueva callable `createAppointment`:
  - valida usuario autenticado y verificado
  - relee perfil, bono, configuración, bloqueos, aforo y citas propias
  - crea la cita `pending` desde backend
- Nuevos triggers backend para Make:
  - `onAppointmentApproved`
  - `onAppointmentDeleted`

### Reglas

- `appointments.create` queda bloqueado para cliente no admin.
- La creación de reservas del portal pasa obligatoriamente por backend.

## Cómo queda Make

- Make no se elimina ni cambia de propósito.
- Sigue disparándose solo en los mismos eventos reales actuales:
  - aprobación de cita -> `confirmed`
  - eliminación de cita -> `deleted`
- El webhook sale del frontend y pasa a backend mediante el secreto `MAKE_WEBHOOK_URL`.
- La condición de aprobación evita duplicados:
  - solo envía `confirmed` cuando una cita pasa de no aprobada a aprobada
- El borrado se dispara una sola vez por documento eliminado mediante trigger `onDocumentDeleted`.

## Flujo actual vs flujo nuevo

### Antes

1. El cliente validaba en UI.
2. El cliente escribía `appointments` directamente.
3. Admin aprobaba o eliminaba.
4. Frontend admin llamaba a Make.

### Ahora

1. El cliente sigue validando visualmente igual.
2. El cliente llama a `createAppointment`.
3. Backend revalida y crea la cita `pending`.
4. Admin sigue aprobando o eliminando desde el mismo flujo.
5. Backend envía Make en aprobación o borrado.

## Atomicidad de la reserva

- La creación segura se hace en una transacción Firestore.
- Dentro de la transacción se lee:
  - `users/{uid}`
  - bono activo del usuario
  - `site_config/main`
  - `blocked_slots` del día
  - `slot_occupancy` del día
  - citas propias `pending` y `approved`
- Dentro de la transacción se escribe:
  - nuevo documento `appointments/{id}` en `pending`
- No se toca:
  - `slot_occupancy`
  - minutos del bono
- Eso mantiene exactamente la lógica funcional actual del sistema.

## Archivos principales tocados

- `functions/src/index.ts`
- `functions/package.json`
- `functions/tsconfig.json`
- `firebase.json`
- `firestore.rules`
- `src/lib/firebase.ts`
- `src/lib/firestore.ts`
- `src/app/portal/page.tsx`
- `src/app/admin/page.tsx`

## Cómo probar end-to-end

1. Configurar el secreto de Functions:
   - `firebase functions:secrets:set MAKE_WEBHOOK_URL`
2. Instalar dependencias de `functions/`.
3. Desplegar Functions y reglas cuando se autorice.
4. Probar:
   - reserva válida desde portal
   - reserva sin bono
   - reserva con minutos insuficientes
   - reserva en franja bloqueada
   - reserva en franja ya ocupada al máximo
   - reserva solapada con otra propia
   - aprobación admin y recepción en Make
   - borrado admin y recepción en Make
   - intento de escritura directa a `appointments` desde cliente

## Pendientes manuales

- Instalar dependencias en `functions/`.
- Configurar el secreto `MAKE_WEBHOOK_URL`.
- Desplegar Functions y reglas.
- Validar el flujo completo en el proyecto Firebase real.

## Riesgos abiertos

- La validación final de despliegue depende de instalar `firebase-functions` en `functions/`.
- La build estática del frontend ya tenía en este entorno un `spawn EPERM` ajeno a esta migración.
- El cambio asume que el proyecto Firebase desplegará Functions en una región compatible con la configuración propuesta (`europe-west1`).
