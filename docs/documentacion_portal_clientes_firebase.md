# Documentacion para recrear el portal de clientes en Firebase

Documento centrado exclusivamente en el portal autenticado de clientes (`/portal`) y en las dependencias internas minimas que lo alimentan. No documenta CMS publico, media library, backoffice avanzado ni funcionalidades no existentes.

## 1. Resumen del portal de clientes

### Actual detectado en codigo
- El portal vive en `src/app/portal/page.tsx`, componente `PortalPage`.
- Permite login, registro, recuperacion de password, completar perfil Google, dashboard, reserva de sesion, detalle de cita y edicion de perfil/avatar.
- La entrada al portal requiere `user.emailVerified` y `userProfile.phone` (`PortalPage`, `isAuthenticated`).
- La autenticacion se implementa en `src/contexts/AuthContext.tsx` con Firebase Auth: email/password, Google, email verification y reset password.
- Datos usados: `users`, `appointments`, `bonos`, `trainers`, `blocked_slots`, `slot_occupancy`, `site_config/main` y Storage `user-avatars/{uid}`.

### Inferido con alta confianza
- El flujo real es: cliente se registra o entra, tiene bono activo con minutos, elige duracion/franja, crea una cita `pending`, espera gestion interna y consulta el resultado.
- El cliente no compra bonos desde el portal; los bonos los asigna o modifica el admin en `src/app/admin/page.tsx`.

### Propuesto para Firebase
- Recrear solo este dominio en una unica fuente de verdad compartida por web y app movil: `users`, `appointments`, `bonos`, `trainers`, `blocked_slots`, `slot_occupancy`, `site_config/main` y Storage de avatares.

## 2. Alcance exacto del analisis

### Actual detectado en codigo

| Entra | Trazabilidad | Motivo |
| --- | --- | --- |
| Portal cliente | `src/app/portal/page.tsx` | UI y flujos cliente |
| Auth | `src/contexts/AuthContext.tsx` | Login, registro, Google, verificacion |
| Firestore/Storage | `src/lib/firestore.ts` | Lecturas/escrituras usadas |
| Tipos | `src/types/index.ts` | Contratos de datos |
| Validacion | `src/lib/validation.ts` | Telefono/password |
| Calendario | `src/components/ui/interactive-calendar.tsx` | Disponibilidad |
| Reglas | `firestore.rules`, `storage.rules` | Permisos reales |
| Indices | `firestore.indexes.json` | Consultas actuales |
| Soporte admin minimo | `src/app/admin/page.tsx` | Bonos, aprobacion, bloqueos, aforo, webhook |

Quedan fuera: CMS publico `site_content`, paginas `centro`, `servicios`, `galeria`, `contacto`, `sandra`, media library, testimonios, servicios publicos, `activity_logs` salvo auditoria interna, admin CMS, pagos, chat, QR, rutinas, compra de bonos y notificaciones push.

### Inferido con alta confianza
- El admin solo debe documentarse cuando produce datos visibles o necesarios para el portal: bonos, estados de cita, slots bloqueados, ocupacion y entrenador asignado.

### Propuesto para Firebase
- Mantener el alcance reducido. Si app/web necesitan branding o contacto, tratarlo como presentacional y no como modelo central del portal.

## 3. Stack tecnico relevante para el portal

### Actual detectado en codigo

| Area | Tecnologia | Trazabilidad |
| --- | --- | --- |
| Frontend | Next.js 16, React 19 | `package.json`, `src/app/portal/page.tsx` |
| UI | Framer Motion, Tailwind, lucide-react | imports de `PortalPage` |
| Auth | Firebase Auth | `src/contexts/AuthContext.tsx`, `src/lib/firebase.ts` |
| DB | Firestore SDK cliente | `src/lib/firestore.ts` |
| Storage | Firebase Storage | `uploadUserAvatar`, `storage.rules` |
| Hosting | Firebase Hosting/export estatico | `firebase.json`, `package.json` |
| Externo | Webhook Make.com | `src/app/admin/page.tsx`, `sendWebhook` |

### Inferido con alta confianza
- No hay backend compartido propio detectado; varias escrituras sensibles se hacen desde cliente web/admin.

### Propuesto para Firebase
- Mantener Firestore/Auth/Storage. Anadir Cloud Functions o backend compartido solo para operaciones sensibles: reserva, aprobacion/rechazo, asignacion/expiracion de bonos, aforo y webhook.

## 4. Pantallas, rutas y modulos del portal de clientes

### Actual detectado en codigo

| Pantalla/modulo | Ruta/estado | Datos consulta | Datos crea/actualiza | Permiso |
| --- | --- | --- | --- | --- |
| Login | `/portal`, `authMode='login'` | Auth, `users/{uid}` | sesion Auth | publico |
| Registro | `authMode='register'` | ninguno del portal | Auth user, `users/{uid}` | usuario recien creado |
| Recuperar password | `forgot-password` | Auth | email reset | publico |
| Completar perfil Google | `complete-profile` | `users/{uid}` parcial | `users.name`, `users.phone` | usuario autenticado |
| Dashboard | `portalView='dashboard'` | `users`, `appointments`, `bonos`, `trainers` | ninguno | owner |
| Reservar sesion | `showReservaDrawer` | `bonos`, disponibilidad | `appointments` | owner verificado |
| Detalle cita | `appointment-detail` | `appointments`, `trainers` | ninguno | owner |
| Mi perfil | `showProfileModal` | `users`, Storage | `users`, Storage, password Auth | owner |
| Calendario | `InteractiveCalendar` | `site_config/main`, `blocked_slots`, `slot_occupancy` | ninguno | verificado |

### Inferido con alta confianza
- El cliente final corresponde a `users.role == 'user'`. `admin` y `trainer` pertenecen a `/admin`, no al portal cliente.

### Propuesto para Firebase
- La app movil debe mapear estas mismas pantallas a UX mobile sin crear modelos alternativos.

## 5. Entidades de negocio necesarias para el portal

### Actual detectado en codigo

**`users/{uid}` (`UserProfile`)**. Trazabilidad: `src/types/index.ts`, `AuthContext.register`, `loginWithGoogle`, `completeGoogleProfile`, `src/lib/firestore.ts` `getUserProfile/createUserProfile/updateUserProfile`, `firestore.rules`.

| Campo | Tipo | Uso |
| --- | --- | --- |
| `uid` | string | doc id y ownership |
| `email` | string | login/contacto |
| `name` | string | perfil y snapshot en cita |
| `phone` | string opcional pero requerido para portal | perfil y snapshot en cita |
| `role` | `admin|trainer|user` | permisos |
| `isTrainer` | boolean opcional | compatibilidad |
| `photoURL` | string opcional | avatar |
| `createdAt` | string ISO | auditoria basica |

**`appointments/{appointmentId}` (`Appointment`)**. Trazabilidad: `src/types/index.ts`, `addAppointment`, `getAppointmentsByUser`, `updateAppointmentStatus`, `updateAppointmentSlot`, `PortalPage.handleSubmitAppointment`, `firestore.rules`.

| Campo | Tipo | Uso |
| --- | --- | --- |
| `userId` | string | ownership |
| `name/email/phone` | string | snapshot cliente |
| `serviceType` | string | servicio mostrado |
| `duration` | `30|45|60` string | bono y slot |
| `preferredSlots` | `TimeSlot[]` | franja propuesta; reglas exigen size 1 |
| `reason` | string | comentario |
| `status` | `pending|approved|rejected` | estado visible |
| `approvedSlot` | `TimeSlot` opcional | franja confirmada |
| `assignedTrainer` | string opcional | ref a `trainers/{id}` |
| `sessionType` | string opcional | tipo mostrado |
| `trainerNotes` | string opcional | nota interna |
| `createdAt/updatedAt` | string ISO | orden/cambios |

**`bonos/{bonoId}` (`Bono`)**. Trazabilidad: `src/types/index.ts`, `getBonosByUser`, `getActiveBonoByUser`, `assignBono`, `deductBonoMinutes`, `returnBonoMinutes`, `firestore.rules`.

| Campo | Tipo | Uso |
| --- | --- | --- |
| `userId` | string | ownership |
| `tamano` | `240|360|480` | minutos totales |
| `minutosTotales` | number | progreso |
| `minutosRestantes` | number | permite reservar |
| `fechaAsignacion/fechaExpiracion` | string ISO | vigencia |
| `estado` | `activo|agotado|expirado|eliminado` | ciclo de vida |
| `historial` | `BonoHistorialEntry[]` | sesiones/descuentos |
| `asignadoPor` | string | admin email |
| `createdAt` | string ISO | orden |
| legacy `tipo/sesionesTotales/sesionesRestantes/modalidad` | opcional | compatibilidad lectura |

**`trainers/{trainerId}` (`Trainer`)**: `uid`, `name`, `specialties?`, `active`, `createdAt`. Usado para mostrar nombre del entrenador asignado (`subscribeActiveTrainers`).

**`blocked_slots/{slotId}` (`BlockedSlot`)**: `date`, `time`, `reason?`, `createdBy`, `createdAt`. Usado por `InteractiveCalendar`.

**`slot_occupancy/{date_time}` (`SlotOccupancy`)**: `date`, `time`, `count`. Derivado operativo para aforo.

**`site_config/main` (`SiteConfig`)**: `startHour`, `endHour`, `slotInterval`, `bonoExpirationMonths`, `maintenanceMode`, legacy `sessionDuration`.

### Inferido con alta confianza
- `appointments.name/email/phone` son snapshots; el ownership real es `userId`.
- `Bono.historial` es array embebido, porque se usa `arrayUnion` y `arrayRemove`.

### Propuesto para Firebase
- Mantener estas entidades sin nuevas colecciones para V1. Las funciones backend deben escribir los mismos campos.

## 6. Relaciones entre entidades

### Actual detectado en codigo

| Relacion | Implementacion | Trazabilidad |
| --- | --- | --- |
| Cliente -> perfil | `users/{uid}` con doc id igual a Auth uid | `AuthContext`, reglas `users/{uid}` |
| Cliente -> muchas citas | `appointments.userId == uid` | `getAppointmentsByUser`, `subscribeAppointmentsByUser` |
| Cliente -> muchos bonos | `bonos.userId == uid` | `getBonosByUser`, `subscribeBonosByUser` |
| Cita -> entrenador | `appointments.assignedTrainer` guarda id de `trainers` | detalle de cita en `PortalPage` |
| Entrenador -> usuario | `trainers.uid` referencia `users/{uid}` | `getTrainerByUid`, regla `isTrainerAssignedByUid` |
| Cita aprobada -> ocupacion | `approvedSlot` incrementa/decrementa `slot_occupancy` | `admin.handleStatusUpdate`, `incrementSlotOccupancy` |
| Bloqueo -> disponibilidad | `blocked_slots.date/time` bloquea calendario | `InteractiveCalendar` |
| Bono -> cita | `bonos.historial[].appointmentId` | `deductBonoMinutes`, `returnBonoMinutes` |

Esquema textual: Cliente -> tiene muchos -> Citas. Cliente -> tiene muchos -> Bonos. Cita -> pertenece a -> Cliente. Cita -> referencia opcionalmente -> Entrenador. Bono -> pertenece a -> Cliente. Bono.historial -> referencia opcionalmente -> Cita. Bloqueos y ocupacion -> condicionan -> disponibilidad.

### Inferido con alta confianza
- Debe existir como maximo un bono `activo` util por cliente, porque el portal toma el primer bono activo y el admin desactiva el existente antes de asignar uno nuevo. No hay constraint transaccional visible. **Pendiente por confirmar** como regla fuerte.

### Propuesto para Firebase
- Preservar relaciones por IDs simples y ownership por `userId`.
- Mover asignacion/renovacion de bono a backend compartido con transaccion para garantizar un unico bono activo.

## 7. Datos estrictamente necesarios para recrear el portal

### Actual detectado en codigo

| Prioridad | Datos | Pantallas/flujos |
| --- | --- | --- |
| V1 imprescindible | `users.uid,email,name,phone,role,createdAt` | Auth, dashboard, perfil |
| V1 imprescindible | `appointments.userId,status,duration,preferredSlots,createdAt,name,email,phone,serviceType,reason` | Reserva, Mis Citas, Detalle |
| V1 imprescindible | `bonos.userId,estado,tamano,minutosTotales,minutosRestantes,fechaExpiracion,fechaAsignacion,historial` | Bono, reservar, historial |
| V1 imprescindible | `site_config/main.startHour,endHour,slotInterval` | Calendario |
| V1 imprescindible | `blocked_slots.date,time` | Calendario |
| V1 imprescindible | `slot_occupancy.date,time,count` | Calendario |
| Paridad actual | `appointments.approvedSlot,assignedTrainer,sessionType,updatedAt` | Cita confirmada |
| Paridad actual | `trainers.id,name,active,uid` | Nombre entrenador |
| Paridad actual | `users.photoURL` + Storage | Avatar |
| Accesorio V1 | `trainerNotes` | Nota interna; no editable por cliente |
| Accesorio V1 | `Trainer.specialties` | No usado por portal cliente detectado |

### Inferido con alta confianza
- `services` no es imprescindible para el portal actual: la reserva usa `bonoServiceLabel = 'Bono Mensual de Entrenamiento'` y `serviceLabels` local como fallback legacy.

### Propuesto para Firebase
- Migrar primero los datos V1 imprescindibles. Anadir paridad despues: avatar, entrenador asignado, historial completo y aforo/bloqueos.

## 8. Base de datos actual relevante para el portal

### Actual detectado en codigo

| Coleccion/documento | Consultas detectadas | Indices actuales/inferidos |
| --- | --- | --- |
| `users/{uid}` | `getDoc(doc(db,'users',uid))`; scan admin | doc lookup |
| `appointments` | `where userId == uid + orderBy createdAt desc`; `assignedTrainer + status + createdAt`; `orderBy createdAt` | indices actuales en `firestore.indexes.json` |
| `bonos` | `userId + createdAt desc`; `userId + estado`; `estado == activo` | posibles compuestos a anadir |
| `trainers` | `active == true`; `uid == uid` | single-field |
| `blocked_slots` | `date >= start`, `date < end`, `orderBy date` | single-field `date` |
| `slot_occupancy` | `date >= start`, `date < end`; doc id directo para update | single-field `date` |
| `site_config/main` | doc fijo `getDoc/onSnapshot` | no indice |

### Inferido con alta confianza
- No hay subcolecciones para el portal. Los historiales de bono son arrays en `bonos`.
- El portal no pagina citas ni bonos; escucha todo el historial del usuario.

### Propuesto para Firebase
- Mantener colecciones top-level. Anadir indices `bonos(userId, createdAt desc)` y `bonos(userId, estado)` si Firestore los solicita.

## 9. Autenticacion, autorizacion y roles del portal

### Actual detectado en codigo
- Email/password: `AuthContext.login` y `AuthContext.register`.
- Google: `AuthContext.loginWithGoogle` con `googleProvider` de `src/lib/firebase.ts`.
- Email verification: `sendEmailVerification`; `login` bloquea si `!emailVerified`.
- Reset password: `sendPasswordResetEmail`.
- Roles: `users.role` puede ser `user`, `admin`, `trainer`.
- Reglas: `firestore.rules` `isVerified`, `isAdmin`, `isTrainer`, `createsOwnUserProfile`, `onlyOwnUserProfileFieldsChanged`, `isValidUserAppointmentCreate`.
- Storage avatar: `storage.rules` permite owner en `user-avatars/{uid}` con imagen <= 5 MB.

### Inferido con alta confianza
- El telefono es obligatorio para entrar al portal incluso si el login fue con Google, porque `isAuthenticated` exige `userProfile.phone`.

### Propuesto para Firebase
- Mantener Auth unico para web y app.
- Cliente no debe escribir `role`, `isTrainer`, estados de cita, `approvedSlot`, `assignedTrainer`, `bonos`, `blocked_slots` ni `slot_occupancy`.

## 10. Logica de negocio del portal de clientes

### Actual detectado en codigo

| Proceso | Actor | Lecturas | Escrituras | Trazabilidad |
| --- | --- | --- | --- | --- |
| Registro | Cliente | Auth | Auth user, `users/{uid}` | `AuthContext.register`, `PortalPage.handleRegister` |
| Login | Cliente | Auth, `users/{uid}` | sesion | `AuthContext.login` |
| Google profile | Cliente | Auth, `users/{uid}` | `users/{uid}` parcial o actualizado | `loginWithGoogle`, `completeGoogleProfile` |
| Reserva cita | Cliente | `bonos`, disponibilidad | `appointments` `pending` | `handleSubmitAppointment`, `addAppointment` |
| Editar perfil | Cliente | `users`, Storage | `users`, Storage, Auth password | `handleSaveProfile` |
| Aprobar cita | Admin | `appointments`, `bonos`, `trainers` | `appointments`, `slot_occupancy`, `bonos` | `admin.handleStatusUpdate` |
| Bloquear horarios | Admin | `appointments`, `blocked_slots` | `blocked_slots`, opcional delete citas/aforo | `admin/page.tsx` |

### Inferido con alta confianza
- La reserva no descuenta bono al crear `pending`; el descuento ocurre al aprobar la cita.

### Propuesto para Firebase
- Backend compartido para `requestAppointment`, `approveAppointment`, `rejectAppointment` y `updateAppointmentSlot`, con transacciones/batches sobre cita, bono y ocupacion.

## 11. Acciones del portal que escriben datos

### Actual detectado en codigo

| Accion | Funcion | Valida | Escribe |
| --- | --- | --- | --- |
| Crear perfil registro | `AuthContext.register` | telefono, password, privacidad | Auth, `users/{uid}` |
| Crear perfil Google | `loginWithGoogle` | existencia doc | `users/{uid}` parcial |
| Completar perfil | `completeGoogleProfile` | telefono | `users.name`, `users.phone` |
| Crear cita | `handleSubmitAppointment` + `addAppointment` | bono/minutos en cliente; shape en reglas | `appointments` |
| Editar perfil | `handleSaveProfile` + `updateUserProfile` | telefono/password | `users`, Auth password |
| Subir/eliminar avatar | `uploadUserAvatar`, `deleteUserAvatar` | Storage rule | Storage y `users.photoURL` |

### Inferido con alta confianza
- Cliente no actualiza ni borra citas, bonos, entrenadores, bloqueos ni ocupacion.

### Propuesto para Firebase
- Mantener perfil/avatar como escritura directa protegida. Pasar creacion de cita a Cloud Function o backend compartido para evitar condiciones de carrera.

## 12. Lecturas de datos del portal

### Actual detectado en codigo

| Lectura | Consulta | Uso |
| --- | --- | --- |
| Perfil | `users/{uid}` | Auth y perfil |
| Citas propias | `appointments where userId == uid orderBy createdAt desc` | dashboard/detalle |
| Bono activo | `bonos where userId == uid and estado == activo` | validacion reserva |
| Bonos propios | `bonos where userId == uid orderBy createdAt desc` | historial |
| Entrenadores activos | `trainers where active == true` | resolver nombre |
| Config slots | `site_config/main` | generar horas |
| Bloqueos mes | `blocked_slots` por rango de `date` | calendario |
| Ocupacion mes | `slot_occupancy` por rango de `date` | calendario |

### Inferido con alta confianza
- El portal usa `onSnapshot` para sincronizacion en tiempo real. En movil conviene activar listeners solo en vistas necesarias.

### Propuesto para Firebase
- Crear capa compartida de queries: `watchMyAppointments`, `watchMyBonos`, `watchMonthAvailability`. No crear estructuras distintas por plataforma.

## 13. Estados y ciclos de vida visibles en el portal

### Actual detectado en codigo

`appointments.status`, definido en `src/types/index.ts` y mostrado por `statusConfig` en `src/app/portal/page.tsx`:

| Estado | Significado | Quien lo cambia |
| --- | --- | --- |
| `pending` | Solicitud pendiente de revisar | Cliente al crear; admin puede cambiar |
| `approved` | Cita aprobada/confirmada | Admin |
| `rejected` | Solicitud rechazada | Admin |

`bonos.estado`, definido en `src/types/index.ts`:

| Estado | Significado | Quien lo cambia |
| --- | --- | --- |
| `activo` | Bono vigente | Admin/proceso |
| `agotado` | Sin minutos | Admin/proceso descuento |
| `expirado` | Fecha vencida | `expireOverdueBonos` o calculo local sin escritura |
| `eliminado` | Eliminado logico | Admin |

### Inferido con alta confianza
- Transiciones esperadas de cita: `pending -> approved`, `pending -> rejected`, y revertir desde `approved` implica devolver minutos y decrementar aforo.
- No hay maquina de estados formal. **Pendiente por confirmar** si se quiere impedir `rejected -> approved` o `approved -> pending`.

### Propuesto para Firebase
- No crear estados nuevos. Validar transiciones en backend para que los side effects de bono y aforo ocurran juntos.

## 14. Archivos clave para entender el portal

### Actual detectado en codigo

| Archivo | Por que importa | Entidades |
| --- | --- | --- |
| `src/app/portal/page.tsx` | Flujos cliente y UI | `users`, `appointments`, `bonos`, `trainers` |
| `src/contexts/AuthContext.tsx` | Auth y perfil | Auth, `users` |
| `src/lib/firestore.ts` | CRUD/listeners | todas las colecciones relevantes |
| `src/types/index.ts` | Contratos | `UserProfile`, `Appointment`, `Bono`, `Trainer` |
| `src/lib/validation.ts` | Telefono/password | auth/perfil |
| `src/components/ui/interactive-calendar.tsx` | Disponibilidad | `blocked_slots`, `slot_occupancy`, `site_config` |
| `src/app/admin/page.tsx` | Soporte minimo operativo | citas, bonos, aforo, bloqueos |
| `firestore.rules` | Seguridad | Firestore |
| `storage.rules` | Seguridad avatar | Storage |
| `firestore.indexes.json` | Indices actuales | `appointments` |
| `docs/mobile-app-ui.md` | Alcance movil sin nuevas features | UI app |

### Inferido con alta confianza
- `docs/mobile-app-ui.md` confirma que la app movil no debe introducir pagos, chat, compra de bonos, QR, rutinas, notificaciones push ni estados nuevos.

### Propuesto para Firebase
- Usar estos archivos como baseline de migracion y crear contratos compartidos para web/app en lugar de forks por plataforma.

## 15. Validaciones y reglas criticas del portal

### Actual detectado en codigo

| Regla | Trazabilidad | Detalle |
| --- | --- | --- |
| Telefono espanol | `validateSpanishPhone` | normaliza `+34`, exige 9 digitos empezando por 6/7/8/9 |
| Password | `validatePassword` | minimo 8, letra y numero |
| Confirmacion password | `PortalPage.handleRegister` | contrasenas iguales |
| Privacidad | `handleRegister` | checkbox obligatorio |
| Email verificado | `AuthContext.login`, reglas `isVerified` | bloquea portal sin verificacion |
| Perfil completo | `PortalPage.isAuthenticated` | requiere `phone` |
| Cita cliente | `isValidUserAppointmentCreate` | campos exactos, `duration` 30/45/60, `preferredSlots.size()==1`, `status=='pending'` |
| Perfil propio | `onlyOwnUserProfileFieldsChanged` | solo `name`, `phone`, `photoURL` |
| Avatar | `storage.rules` | imagen <= 5 MB en path propio |
| Bono suficiente | `handleSubmitAppointment` | cliente relee bono activo y compara minutos |
| Slot disponible | `InteractiveCalendar.handleSlotClick` | no pasado, no bloqueado, capacidad < 2, sin cita propia solapada |

### Inferido con alta confianza
- Faltan validaciones backend para longitud de comentario/nombre, fecha futura, slot dentro de horario, capacidad real al escribir y unicidad de bono activo.

### Propuesto para Firebase
- Mover a backend compartido: bono activo/minutos, disponibilidad/no solape, fecha futura, transiciones de estado, descuentos/devoluciones y webhook.
- Mantener reglas para ownership y campos permitidos.

## 16. Procesos automaticos que afectan al cliente

### Actual detectado en codigo

| Proceso | Disparador | Datos tocados | Trazabilidad |
| --- | --- | --- | --- |
| Verificacion email | registro | Auth | `AuthContext.register` |
| Reset password | solicitud cliente | Auth | `resetPassword` |
| Reenvio verificacion | cliente semi-logueado | Auth | `resendVerification` |
| Expirar bonos | carga admin | `bonos.estado` | `expireOverdueBonos` |
| Normalizar bonos | carga admin | `minutosTotales/minutosRestantes` | `normalizeActiveBonoLimits` |
| Descontar minutos | aprobar cita | `bonos`, `historial` | `deductBonoMinutes` |
| Devolver minutos | revertir aprobacion | `bonos`, `historial` | `returnBonoMinutes` |
| Sincronizar aforo | aprobar/revertir/modificar | `slot_occupancy` | `incrementSlotOccupancy`, `decrementSlotOccupancy` |
| Webhook confirmacion | aprobacion admin | Make.com payload | `sendWebhook` |

### Inferido con alta confianza
- La expiracion de bonos depende hoy de que el admin cargue el panel o de un calculo local del cliente sin escritura real.

### Propuesto para Firebase
- Migrar expiracion a scheduled Cloud Function. Ejecutar webhook y side effects de aprobacion desde backend.

## 17. Dependencias con sistemas internos

### Actual detectado en codigo

| Dependencia | Dato generado/modificado | Necesidad portal |
| --- | --- | --- |
| Admin bonos | `bonos` | habilita reserva |
| Admin citas | `appointments.status`, `approvedSlot`, `assignedTrainer`, `sessionType` | confirma/rechaza |
| Admin disponibilidad | `blocked_slots`, `slot_occupancy` | calendario correcto |
| Admin equipo | `trainers` | nombre entrenador |
| Admin config | `site_config/main` | horarios, expiracion, mantenimiento |
| Make webhook | payload externo | **pendiente por confirmar** si es obligatorio |

### Inferido con alta confianza
- Se puede simplificar el backoffice a operaciones minimas; no hace falta migrar CMS ni media manager para que funcione el portal.

### Propuesto para Firebase
- Mantener una interfaz interna minima o funciones admin que operen las mismas colecciones compartidas.

## 18. Adaptacion propuesta a Firebase para portal compartido web + app

### Actual detectado en codigo
- El proyecto ya usa Firestore, Firebase Auth y Storage (`src/lib/firebase.ts`).
- Las reglas actuales ya expresan ownership y roles principales.

### Inferido con alta confianza
- La migracion principal es de consistencia y arquitectura compartida, no de modelo SQL a Firestore.

### Propuesto para Firebase

Estructura:

```text
users/{uid}
appointments/{appointmentId}
bonos/{bonoId}
trainers/{trainerId}
blocked_slots/{slotId}
slot_occupancy/{YYYY-MM-DD_HH:MM}
site_config/main
storage/user-avatars/{uid}/{fileName}
```

Lectura directa cliente: perfil propio, citas propias, bonos propios, disponibilidad, entrenadores activos y config de slots.

Escritura directa cliente: perfil seguro y avatar. Escritura via backend: crear cita, aprobar/rechazar/modificar cita, asignar/ajustar/expirar bono, sincronizar aforo y webhook.

## 19. Modelo de datos compartido recomendado para web y app

### Actual detectado en codigo
- El contrato actual esta en `src/types/index.ts`; las operaciones estan en `src/lib/firestore.ts`.

### Inferido con alta confianza
- Los campos legacy de bonos solo deben leerse durante migracion si existen documentos antiguos.

### Propuesto para Firebase

| Coleccion | Fuente | Campos minimos | Quien lee | Quien escribe |
| --- | --- | --- | --- | --- |
| `users` | verdad | `uid,email,name,phone,role,createdAt` | owner/admin | owner campos seguros, admin/backend |
| `appointments` | verdad | `userId,name,email,phone,serviceType,duration,preferredSlots,reason,status,createdAt` | owner/admin/trainer asignado | backend/admin; cliente solo via backend |
| `bonos` | verdad | `userId,tamano,minutosTotales,minutosRestantes,fechaAsignacion,fechaExpiracion,estado,historial,createdAt` | owner/admin | backend/admin |
| `trainers` | soporte | `uid,name,active` | verificados/admin | admin |
| `blocked_slots` | soporte | `date,time` | verificados/admin | admin/backend |
| `slot_occupancy` | derivada operativa | `date,time,count` | verificados/admin | backend/admin |
| `site_config/main` | config | `startHour,endHour,slotInterval,bonoExpirationMonths,maintenanceMode` | portal/admin | admin/backend |

No crear agregados para dashboard en V1; el dashboard actual se calcula con citas y bonos.

## 20. Reglas funcionales de seguridad en Firebase

### Actual detectado en codigo
- `firestore.rules` permite owner read/update parcial en `users`, owner read/create en `appointments`, owner read en `bonos`, admin writes en entidades operativas, trainer update limitado a `trainerNotes`.
- `storage.rules` permite avatar propio con imagen <= 5 MB.

### Inferido con alta confianza
- Las reglas no garantizan disponibilidad, minutos de bono, unicidad de bono activo ni sincronizacion de aforo.

### Propuesto para Firebase
- `users`: owner edita solo `name`, `phone`, `photoURL`.
- `appointments`: owner lee; cliente no debe modificar estado/campos de aprobacion; creacion preferiblemente via callable.
- `bonos`: owner solo lectura.
- `blocked_slots`, `slot_occupancy`, `trainers`: lectura verificada, escritura admin/backend.
- `site_config/main`: lectura para portal; escritura admin.
- Storage avatar: mantener owner path/tamano/tipo.

## 21. Indices necesarios en Firebase

### Actual detectado en codigo

`firestore.indexes.json` contiene indices de `appointments`:

| Coleccion | Campos | Motivo |
| --- | --- | --- |
| `appointments` | `userId ASC`, `createdAt DESC` | citas del usuario |
| `appointments` | `status ASC`, `createdAt DESC` | filtro admin por estado |
| `appointments` | `assignedTrainer ASC`, `status ASC`, `createdAt DESC` | citas de trainer |

Tambien existe indice `gallery_items(active, createdAt)`, excluido del portal.

### Inferido con alta confianza

Indices derivados de consultas reales:

| Prioridad | Coleccion | Campos |
| --- | --- | --- |
| Alta | `bonos` | `userId ASC`, `createdAt DESC` |
| Alta | `bonos` | `userId ASC`, `estado ASC` |
| Media | `blocked_slots` | `date ASC` |
| Media | `slot_occupancy` | `date ASC` |
| Baja | `trainers` | `active ASC`, `uid ASC` como single-field |

### Propuesto para Firebase
- Mantener indices actuales de `appointments`.
- Anadir indices de `bonos` si Firestore los solicita en entorno limpio.
- No migrar indice de `gallery_items` como parte del portal.

## 22. Cloud Functions necesarias para el portal

### Actual detectado en codigo
- No hay carpeta `functions` ni backend propio detectado.
- Operaciones sensibles estan en `src/lib/firestore.ts` y `src/app/admin/page.tsx`.

### Inferido con alta confianza
- Web y app compartidas no deberian duplicar validaciones de bono, disponibilidad, aforo y webhook.

### Propuesto para Firebase

| Funcion | Tipo | Prioridad | Objetivo |
| --- | --- | --- | --- |
| `requestAppointment` | callable | V1 imprescindible | Crear `pending` validando ownership, perfil, bono, minutos, slot y fecha |
| `approveAppointment` | callable/HTTP admin | paridad | Cambiar a `approved`, set `approvedSlot`, trainer, descontar bono, incrementar aforo, webhook |
| `rejectAppointment` | callable/HTTP admin | paridad | Cambiar a `rejected`; devolver minutos/decrementar aforo si aplica |
| `updateAppointmentSlot` | callable/HTTP admin | paridad | Cambiar franja y ajustar aforo si estaba aprobada |
| `assignBonoToUser` | callable/HTTP admin | V1 imprescindible si hay bonos | Desactivar bono activo anterior y crear nuevo |
| `adjustBonoMinutes` | callable/HTTP admin | paridad | Sumar/restar minutos manualmente |
| `expireOverdueBonos` | scheduled | paridad | Marcar vencidos sin depender de admin web |
| `sendAppointmentWebhook` | integrada o trigger | pendiente/paridad | Enviar Make.com desde backend si sigue vigente |

No se propone coleccion nueva; estas funciones escriben en las colecciones existentes.

## 23. Migracion minima de datos para reconstruir el portal

### Actual detectado en codigo
Datos relevantes: `users`, `appointments`, `bonos`, `trainers`, `blocked_slots`, `slot_occupancy`, `site_config/main`, Storage `user-avatars`.

### Inferido con alta confianza
Orden recomendado:

1. Auth users y `users/{uid}`.
2. `site_config/main`.
3. `trainers`.
4. `bonos`.
5. `appointments`.
6. `blocked_slots`.
7. Migrar o recalcular `slot_occupancy`.
8. Avatares y `photoURL`.

Checks: cada `userId` existe; `duration` en `30/45/60`; `preferredSlots` size 1 en nuevas citas cliente; `minutosRestantes <= minutosTotales`; `assignedTrainer` existe si se muestra; `slot_occupancy` coincide con citas aprobadas.

### Propuesto para Firebase
- Omitir CMS, media library, testimonios, servicios publicos y `activity_logs` en V1.
- Mantener campos legacy de bonos solo para lectura/migracion; no escribirlos en documentos nuevos.

## 24. Exclusiones explicitas

### Actual detectado en codigo
Excluidos: `site_content/main` para paginas publicas, `services`, `testimonials`, `media_files`, `media_folders`, `gallery_items`, `system_config` de carpetas, admin CMS, paginas publicas y `activity_logs` salvo auditoria interna.

### Inferido con alta confianza
- Estas piezas no deben condicionar el nuevo modelo del portal; el portal funciona con auth, perfil, citas, bonos y disponibilidad.

### Propuesto para Firebase
- No migrarlas a la primera arquitectura compartida del portal. Si se migran despues, tratarlas como dominio web publica/CMS.

## 25. Dudas, ambiguedades y pendientes

### Actual detectado en codigo
- No hay constraint fuerte visible para maximo un bono activo por usuario.
- No hay Cloud Functions detectadas.
- Webhook Make.com hardcodeado en `src/app/admin/page.tsx`.
- `serviceType` se escribe como "Bono Mensual de Entrenamiento", pero existen labels legacy `training`, `competition`, `nutrition`, `assessment`.
- `trainerNotes` existe; el cliente no lo edita.

### Inferido con alta confianza
- `slot_occupancy` puede desincronizarse si falla una operacion intermedia.
- Expiracion de bonos puede quedar stale si el admin no abre el panel.
- Creacion de cita directa desde cliente puede sufrir race condition.

### Propuesto para Firebase
Pendiente por confirmar:

- unicidad exacta de bono activo;
- obligatoriedad futura del webhook Make.com;
- normalizacion definitiva de `serviceType`;
- si se quiere permitir cancelacion cliente; no existe en portal actual;
- limites maximos de `reason`, `name` y `phone` mas alla de validacion actual.

## 26. Riesgos de migracion y consistencia web + app

### Actual detectado en codigo

| Riesgo | Donde | Impacto |
| --- | --- | --- |
| Reserva no atomica | `PortalPage.handleSubmitAppointment` lee bono y luego `addAppointment` | bono/slot pueden cambiar antes de escribir |
| Aprobacion multi-escritura | `admin.handleStatusUpdate` | cita, bono y aforo pueden quedar parciales |
| Ocupacion derivada manual | `incrementSlotOccupancy`, `decrementSlotOccupancy` | `slot_occupancy` puede no coincidir |
| Expiracion dependiente del admin | `refreshData` llama `expireOverdueBonos` | cliente puede ver stale |
| Bono activo unico no garantizado | `assignBono` desactiva anterior y crea nuevo | dos writers podrian crear activos |
| Webhook en UI/admin | `sendWebhook` | fallo navegador/red pierde side effect |
| Cliente crea cita directa | reglas permiten `appointments.create` | web/app duplican logica sensible |

### Inferido con alta confianza
- Compartir base entre web y app aumenta estos riesgos si cada cliente replica validaciones.

### Propuesto para Firebase
- **V1 imprescindible**: centralizar `requestAppointment`.
- **Necesario para paridad**: `approveAppointment` atomica sobre `appointments`, `bonos` y `slot_occupancy`.
- **Mejora futura**: reconciliador programado que compare citas aprobadas contra `slot_occupancy`.

## A. Resumen ejecutivo

### Actual detectado en codigo
El portal permite autenticacion Firebase, perfil, bono de minutos, reserva de sesiones, consulta de citas y edicion de perfil/avatar. La persistencia relevante ya esta en Firestore y Storage.

### Inferido con alta confianza
La nueva arquitectura no necesita copiar el backoffice completo; necesita portar el nucleo operativo y las dependencias internas minimas.

### Propuesto para Firebase
Usar una unica base Firestore compartida por web y app con las colecciones existentes, y centralizar en backend las operaciones que cruzan citas, bonos, aforo y webhook.

## B. Esquema de datos resumido

### Actual detectado en codigo

```text
users/{uid}
  -> appointments where userId == uid
  -> bonos where userId == uid

appointments/{id}
  -> optional trainer: trainers/{assignedTrainer}
  -> preferredSlots[0] / approvedSlot

bonos/{id}
  -> userId: users/{uid}
  -> historial[].appointmentId: appointments/{id} | "manual"

trainers/{id}
  -> uid: users/{uid}

blocked_slots/{id}
slot_occupancy/{YYYY-MM-DD_HH:MM}
site_config/main
storage/user-avatars/{uid}/{fileName}
```

### Inferido con alta confianza
Ownership principal: `request.auth.uid == users/{uid}.uid == appointments.userId == bonos.userId`.

### Propuesto para Firebase
Mantener este esquema sin colecciones nuevas para V1.

## C. Datos minimos para una V1

### Actual detectado en codigo
- `users`: `uid`, `email`, `name`, `phone`, `role`, `createdAt`.
- `appointments`: `userId`, `name`, `email`, `phone`, `serviceType`, `duration`, `preferredSlots`, `reason`, `status`, `createdAt`.
- `bonos`: `userId`, `tamano`, `minutosTotales`, `minutosRestantes`, `fechaAsignacion`, `fechaExpiracion`, `estado`, `historial`, `createdAt`.
- `site_config/main`: `startHour`, `endHour`, `slotInterval`, `bonoExpirationMonths`, `maintenanceMode`.
- `blocked_slots`: `date`, `time`.
- `slot_occupancy`: `date`, `time`, `count`.

### Inferido con alta confianza
Sin `trainers` se puede tener V1 funcional, pero no paridad de detalle de cita aprobada cuando hay entrenador asignado.

### Propuesto para Firebase
V1 funcional: auth, perfil, bono activo, citas propias, reserva pendiente y disponibilidad. Paridad: avatar, entrenadores, aprobacion/descuento/devolucion y webhook si aplica.

## D. Checklist de implementacion

### Actual detectado en codigo
- [ ] Migrar/validar `users`.
- [ ] Migrar/validar `bonos`.
- [ ] Migrar/validar `appointments`.
- [ ] Migrar/validar `trainers`.
- [ ] Migrar `site_config/main`.
- [ ] Migrar/recalcular `blocked_slots` y `slot_occupancy`.
- [ ] Migrar avatares si se conserva `photoURL`.
- [ ] Revisar `firestore.rules`, `storage.rules` e indices.

### Inferido con alta confianza
- [ ] Revisar bonos legacy.
- [ ] Detectar usuarios con perfil incompleto.
- [ ] Detectar citas con `duration` fuera de `30/45/60`.
- [ ] Detectar bonos con minutos inconsistentes.

### Propuesto para Firebase
- [ ] Implementar `requestAppointment`.
- [ ] Implementar aprobar/rechazar/modificar cita en backend.
- [ ] Implementar asignar/ajustar/expirar bonos en backend.
- [ ] Mover webhook Make al backend si sigue vigente.
- [ ] Exponer capa de datos comun para web y app.
- [ ] No crear estructuras distintas por plataforma.

## E. Checklist de compatibilidad web + app

### Actual detectado en codigo
- [ ] Estados de cita: `pending`, `approved`, `rejected`.
- [ ] Estados de bono: `activo`, `agotado`, `expirado`, `eliminado`.
- [ ] Duraciones: `30`, `45`, `60`.
- [ ] `preferredSlots` con una sola franja para creacion cliente.
- [ ] Ownership por `userId == auth.uid`.
- [ ] Avatar bajo `user-avatars/{uid}`.

### Inferido con alta confianza
- [ ] Web y app deben calcular minutos con la misma logica que `getBonoMinutosRestantes` y `getBonoMinutosTotales`.
- [ ] Web y app deben usar el mismo algoritmo de bloques de slot, o delegarlo al backend.

### Propuesto para Firebase
- [ ] Compartir contratos de tipos.
- [ ] Compartir funciones de lectura/escritura o backend comun.
- [ ] No permitir que app movil implemente su propia version de descuento de bono o aforo.
- [ ] No crear colecciones `mobile_*` ni campos paralelos.
- [ ] Probar el mismo usuario en web y app contra la misma base.
