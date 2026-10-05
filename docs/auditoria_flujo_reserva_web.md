# Auditoría técnica del flujo de reserva y migración del portal cliente

## Resumen ejecutivo

Este documento describe el flujo real actual del portal cliente web de Focus Club para tres áreas que deberán replicarse o revisarse en la futura app móvil:

1. reserva de citas
2. avisos de citas
3. foto de perfil del cliente

Conclusión principal de la reserva: **B) La web escribe directamente en Firestore y habría que cambiarla**.

La evidencia del repositorio muestra que la creación de la cita del cliente no pasa por Cloud Functions ni por una API HTTP propia. El flujo actual termina en una escritura directa con Firebase client SDK sobre la colección `appointments`. Los avisos de citas no forman parte del alta inicial de la reserva, sino de acciones administrativas posteriores. El avatar del cliente sí usa Firebase Storage y después persiste `photoURL` en `users/{uid}`.

## Flujo real de reserva paso a paso

### 1. Punto de entrada UI

La reserva se inicia en el dashboard del portal cliente en [src/app/portal/page.tsx](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/app/portal/page.tsx).

- El botón `Reservar Sesión` solo se muestra si existe `activeBono` y tiene al menos 30 minutos disponibles ([src/app/portal/page.tsx](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/app/portal/page.tsx):1123).
- El click ejecuta `setShowReservaDrawer(true)` ([src/app/portal/page.tsx](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/app/portal/page.tsx):1128).
- El drawer de reserva aparece cuando `showReservaDrawer` es `true` ([src/app/portal/page.tsx](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/app/portal/page.tsx):1515).

### 2. Formulario dentro del drawer

El drawer contiene tres piezas funcionales:

- selección de duración (`30`, `45`, `60`) ([src/app/portal/page.tsx](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/app/portal/page.tsx):1552)
- selección de franja mediante `InteractiveCalendar` ([src/app/portal/page.tsx](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/app/portal/page.tsx):1596)
- comentario opcional `reason` ([src/app/portal/page.tsx](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/app/portal/page.tsx):1605)

El botón final `Enviar Solicitud` llama a `handleSubmitAppointment` ([src/app/portal/page.tsx](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/app/portal/page.tsx):1625).

### 3. Validación y envío desde cliente

La función `handleSubmitAppointment` está en [src/app/portal/page.tsx](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/app/portal/page.tsx):479.

Flujo exacto:

1. Sale si falta `user`, `userProfile` o `formData.preferredSlot`.
2. Relee el bono activo con `getActiveBonoByUser(user.uid)`.
3. Convierte `formData.duration` a minutos.
4. Si no hay bono activo o no hay minutos suficientes, muestra `alert` y no escribe nada.
5. Si pasa esa comprobación, llama a `addAppointmentFS(...)`.
6. Después de guardar, relee las citas con `getAppointmentsByUser(user.uid)`.
7. Marca éxito local y cierra el drawer después de un `setTimeout`.

### 4. Capa de servicio utilizada

En [src/app/portal/page.tsx](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/app/portal/page.tsx):50, `addAppointmentFS` es un alias importado de `addAppointment` desde [src/lib/firestore.ts](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/lib/firestore.ts).

La implementación real está en [src/lib/firestore.ts](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/lib/firestore.ts):601:

- `addAppointment(data)` ejecuta `addDoc(collection(db, 'appointments'), {...})`
- fuerza `status: 'pending'`
- añade `createdAt: new Date().toISOString()`

La instancia `db` viene del Firebase client SDK inicializado en [src/lib/firebase.ts](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/lib/firebase.ts):16.

### 5. Disponibilidad y calendario

El calendario usado por la reserva es `InteractiveCalendar` en [src/components/ui/interactive-calendar.tsx](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/components/ui/interactive-calendar.tsx).

Su flujo es:

- suscribe disponibilidad mensual con `subscribeMonthAvailability` ([src/components/ui/interactive-calendar.tsx](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/components/ui/interactive-calendar.tsx):137)
- suscribe configuración de franjas con `subscribeSiteConfig` ([src/components/ui/interactive-calendar.tsx](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/components/ui/interactive-calendar.tsx):156)
- al hacer click en una franja, `handleSlotClick` valida:
  - que no esté bloqueada
  - que no supere el aforo
  - que el usuario no tenga ya una sesión propia en esa franja

La combinación de lecturas se hace en [src/lib/firestore.ts](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/lib/firestore.ts):1109, donde `subscribeMonthAvailability` agrega:

- `slot_occupancy`
- `blocked_slots`

La generación de horas visibles se hace con `generateTimeSlots` a partir de `site_config/main` ([src/lib/firestore.ts](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/lib/firestore.ts):1335).

## Archivos y funciones clave

### Archivos implicados

- [src/app/portal/page.tsx](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/app/portal/page.tsx)
- [src/components/ui/interactive-calendar.tsx](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/components/ui/interactive-calendar.tsx)
- [src/lib/firestore.ts](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/lib/firestore.ts)
- [src/lib/firebase.ts](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/lib/firebase.ts)
- [src/contexts/AuthContext.tsx](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/contexts/AuthContext.tsx)
- [src/types/index.ts](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/types/index.ts)
- [firestore.rules](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/firestore.rules)
- [storage.rules](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/storage.rules)
- [firebase.json](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/firebase.json)
- [.firebaserc](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/.firebaserc)
- [src/app/admin/page.tsx](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/app/admin/page.tsx)

### Funciones implicadas en reserva

- `handleSubmitAppointment`
- `addAppointment`
- `getAppointmentsByUser`
- `getActiveBonoByUser`
- `subscribeAppointmentsByUser`
- `subscribeBonosByUser`
- `subscribeMonthAvailability`
- `subscribeSiteConfig`
- `generateTimeSlots`
- `isValidUserAppointmentCreate`

### Tipos implicados

En [src/types/index.ts](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/types/index.ts):

- `Appointment`
- `TimeSlot`
- `BlockedSlot`
- `SlotOccupancy`
- `Bono`
- `UserProfile`

## Firestore/API afectada

### Colecciones y documentos leídos por la reserva

- `bonos`
  - `userId`
  - `estado`
  - `minutosRestantes`
  - `tamano`
  - `minutosTotales`
  - `fechaExpiracion`
- `appointments`
  - `userId`
  - `status`
  - `preferredSlots`
  - `approvedSlot`
  - `duration`
- `blocked_slots`
  - `date`
  - `time`
  - `reason`
- `slot_occupancy`
  - `date`
  - `time`
  - `count`
- `site_config/main`
  - `startHour`
  - `endHour`
  - `slotInterval`
  - `bonoExpirationMonths`
  - `maintenanceMode`

### Colección escrita por la reserva

La web escribe directamente en `appointments` con estos campos:

- `userId`
- `name`
- `email`
- `phone`
- `serviceType`
- `duration`
- `preferredSlots`
- `reason`
- `status: 'pending'`
- `createdAt`

### Evidencia de backend o capa intermedia

Resultado real de la auditoría:

- **No hay Cloud Function usada para crear la reserva.**
- **No hay API HTTP propia usada para crear la reserva.**
- **No hay capa intermedia entre el cliente y Firestore en la creación de la cita.**

Evidencias:

- no existe carpeta `functions` en el repo
- [firebase.json](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/firebase.json) no declara bloque `functions`
- existen `src/app/api/images` y `src/app/api/upload`, pero ambas carpetas están vacías y no participan en reserva
- la búsqueda en el repo no encontró `httpsCallable`, `firebase/functions`, `getFunctions` ni `axios`
- la comprobación remota con Firebase CLI sobre el proyecto `focus-club-f73b8` devolvió: `No functions found in project focus-club-f73b8`

## Validaciones actuales

### Validaciones en cliente

Reserva:

- el cliente exige `user`, `userProfile` y `preferredSlot` antes de enviar ([src/app/portal/page.tsx](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/app/portal/page.tsx):480)
- relee el bono activo justo antes de escribir con `getActiveBonoByUser`
- compara `getBonoMinutosRestantes(currentBono)` con la duración solicitada
- la UI de duración deshabilita opciones sin minutos suficientes ([src/app/portal/page.tsx](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/app/portal/page.tsx):1565)
- el calendario bloquea:
  - días pasados
  - horas pasadas
  - slots bloqueados
  - slots con aforo completo
  - solape con citas propias `pending` o `approved`

Perfil:

- el portal valida teléfono con `validateSpanishPhone` antes de guardar perfil ([src/app/portal/page.tsx](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/app/portal/page.tsx):535)
- si se cambia contraseña, valida con `validatePassword`
- el input del avatar usa `accept="image/*"` ([src/app/portal/page.tsx](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/app/portal/page.tsx):1692)
- no hay validación explícita de tamaño del fichero en TypeScript

### Validaciones en reglas

En [firestore.rules](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/firestore.rules):

- `appointments.create` permite creación al owner verificado si:
  - `request.resource.data.userId == request.auth.uid`
  - `status == 'pending'`
  - la estructura pasa `isValidUserAppointmentCreate()`
- `isValidUserAppointmentCreate()` exige:
  - claves exactas
  - `duration` en `['30', '45', '60']`
  - `preferredSlots` sea lista
  - `preferredSlots.size() == 1`

En [storage.rules](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/storage.rules):

- `user-avatars/{uid}/{fileName}`:
  - read: owner o admin
  - create/update: owner verificado y archivo imagen hasta 5 MB
  - delete: owner o admin

En [firestore.rules](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/firestore.rules):7:

- `users/{uid}` solo permite al owner verificado actualizar `name`, `phone`, `photoURL`

## Riesgos actuales

### Reserva

- la reserva no es atómica: el cliente lee bono y disponibilidad, y después escribe
- no se descuenta bono al crear la cita `pending`
- el descuento del bono ocurre después en admin al aprobar la cita
- las reglas validan la forma mínima del documento, pero no validan:
  - disponibilidad real
  - aforo
  - fecha futura
  - bloqueo operativo
  - solape de citas del usuario
  - saldo real del bono
- cualquier cliente autenticado que cumpla las reglas podría reproducir esta escritura directa

### Perfil

- la restricción de tamaño/tipo depende sobre todo de reglas, no de validación previa fuerte en UI
- `deleteStorageAssetByUrl` ignora errores de limpieza, lo que evita romper el guardado pero también oculta fallos de borrado del archivo anterior

## Conclusión final: B

**B) La web escribe directamente en Firestore y habría que cambiarla.**

La creación de la cita del cliente termina en `addDoc(collection(db, 'appointments'), ...)` desde el cliente web. No se ha encontrado Cloud Function, backend propio ni endpoint HTTP del flujo de reserva. Los avisos de citas dependen de acciones admin y no forman parte del alta inicial de la cita del cliente.

## Avisos de citas

En el momento de la auditoría, el panel admin disparaba desde el navegador un aviso externo al aprobar o eliminar una cita, sin reintentos ni cola. Esa integración está retirada. Hoy los avisos de citas salen del backend y el único sistema es Brevo (email), FCM (push) y el historial en Firestore; ver `notifications-contract.md` en `web_focus_club/docs`.

## Flujo actual de foto de perfil del cliente

### Dónde se implementa

La UI del avatar del cliente está en [src/app/portal/page.tsx](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/app/portal/page.tsx), dentro del modal de perfil y del dashboard.

Las funciones de persistencia están en [src/lib/firestore.ts](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/lib/firestore.ts):

- `updateUserProfile` ([src/lib/firestore.ts](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/lib/firestore.ts):494)
- `uploadUserAvatar` ([src/lib/firestore.ts](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/lib/firestore.ts):537)
- `deleteUserAvatar` ([src/lib/firestore.ts](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/lib/firestore.ts):548)
- helper `deleteStorageAssetByUrl` ([src/lib/firestore.ts](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/lib/firestore.ts):526)

El refresco del perfil se apoya en [src/contexts/AuthContext.tsx](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/contexts/AuthContext.tsx):

- `subscribeUserProfile` se usa para mantener `userProfile` actualizado ([src/contexts/AuthContext.tsx](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/contexts/AuthContext.tsx):102)
- `refreshUserProfile` relee el perfil tras guardar cambios ([src/contexts/AuthContext.tsx](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/contexts/AuthContext.tsx):335)

### Flujo real del avatar

#### Selección visual

En el modal de perfil:

- el input es `type="file"` con `accept="image/*"` ([src/app/portal/page.tsx](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/app/portal/page.tsx):1690)
- al elegir un archivo:
  - se toma el primer `File`
  - si había preview anterior, se libera con `URL.revokeObjectURL`
  - se guarda en `profilePhotoFile`
  - se genera preview local con `URL.createObjectURL(file)`
  - se limpia el flag `profilePhotoRemoved`

Eso ocurre en [src/app/portal/page.tsx](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/app/portal/page.tsx):1694.

#### Eliminación visual

Si el usuario pulsa `Eliminar foto`:

- se revoca la preview si era `blob:`
- `profilePhotoFile` pasa a `null`
- `profilePhotoPreview` pasa a cadena vacía
- `profilePhotoRemoved` pasa a `true`

Eso ocurre en [src/app/portal/page.tsx](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/app/portal/page.tsx):1709.

#### Guardado real

El guardado completo se hace en `handleSaveProfile` ([src/app/portal/page.tsx](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/app/portal/page.tsx):530).

Comportamiento exacto:

1. arranca con `let photoURL = userProfile.photoURL || ''`
2. si hay `profilePhotoFile`, llama a `uploadUserAvatar(user.uid, profilePhotoFile, userProfile.photoURL)`
3. si no hay fichero nuevo pero sí `profilePhotoRemoved` y había foto previa, llama a `deleteUserAvatar(userProfile.photoURL)` y deja `photoURL = ''`
4. actualiza Firestore con `updateUserProfile(user.uid, { name, phone, photoURL })`
5. refresca perfil con `refreshUserProfile()`

### Uso de Firebase Storage

Sí, el avatar usa Firebase Storage.

La ruta usada en `uploadUserAvatar` es:

- `user-avatars/{uid}/profile-{timestamp}.{ext}`

Implementación en [src/lib/firestore.ts](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/lib/firestore.ts):539.

Proceso exacto:

- calcula extensión con `getFileExtension(file)`
- crea `storageRef`
- sube el binario con `uploadBytes(storageRef, file, { contentType: file.type || 'image/jpeg' })`
- intenta borrar el archivo anterior usando la URL previa
- obtiene la nueva URL con `getDownloadURL(storageRef)`
- devuelve esa URL al flujo del perfil

### Campo de Firestore actualizado

El campo persistido en Firestore es `users/{uid}.photoURL`.

La actualización se hace mediante `updateUserProfile`, que ejecuta `updateDoc(doc(db, 'users', uid), data)` ([src/lib/firestore.ts](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/lib/firestore.ts):494).

### Reutilización y borrado de la foto anterior

El portal reutiliza `userProfile.photoURL` como valor actual del avatar.

Al subir una nueva:

- usa la foto actual como `currentPhotoURL`
- intenta borrarla con `deleteStorageAssetByUrl(currentPhotoURL)`

Al eliminar sin reemplazo:

- llama a `deleteUserAvatar(currentPhotoURL)`
- deja `photoURL` vacío en Firestore

`deleteStorageAssetByUrl` hace `deleteObject(ref(storage, url))` y silencia errores si el archivo no existe o es legacy ([src/lib/firestore.ts](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/lib/firestore.ts):526).

### Comportamiento visual cuando `photoURL` está vacío

El portal sí tiene fallback visual.

En el dashboard:

- si `userProfile.photoURL` existe, renderiza `<img src={userProfile.photoURL}>`
- si no existe, muestra un círculo con degradado y la inicial `userProfile?.name?.charAt(0)` ([src/app/portal/page.tsx](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/app/portal/page.tsx):1106)

En el modal de perfil:

- `displayedProfilePhoto` usa prioridad:
  1. `profilePhotoPreview`
  2. `userProfile.photoURL`, salvo que `profilePhotoRemoved` sea `true`
- si no hay imagen efectiva, renderiza también un círculo degradado con la inicial del nombre ([src/app/portal/page.tsx](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/app/portal/page.tsx):284 y [src/app/portal/page.tsx](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/app/portal/page.tsx):1677)

Resumen visual real a replicar:

- la preview local tiene prioridad sobre `photoURL`
- si `photoURL` está vacío o no existe, se muestra inicial
- si `profilePhotoRemoved` está activo, desaparece la imagen actual y se usa el fallback de inicial
- no hay avatar por defecto distinto de esa inicial con fondo degradado

### Validaciones y reglas aplicables

En cliente:

- el input restringe selección a `image/*`
- no hay validación explícita de tamaño en el código del portal
- no hay compresión ni resize en cliente

En Storage:

- `user-avatars/{uid}/{fileName}`
- lectura: owner o admin
- create/update: owner verificado y tamaño máximo 5 MB con contenido imagen
- delete: owner o admin

En Firestore:

- el owner verificado solo puede cambiar `name`, `phone`, `photoURL`

### Qué habría que replicar exactamente en móvil

Para que Flutter funcione igual que la web actual, habría que replicar:

- selección de imagen del dispositivo
- preview local antes de guardar
- subida a Storage en path `user-avatars/{uid}/profile-{timestamp}.{ext}`
- borrado del avatar anterior al reemplazar
- persistencia del `photoURL` resultante en `users/{uid}`
- lectura reactiva del perfil para refrescar avatar
- fallback visual a la inicial cuando `photoURL` no exista

## Implicaciones para replicarlo en la app móvil

### 1. Reserva

Qué hace hoy la web:

- lee bono, citas, bloqueos, aforo y configuración
- valida en cliente
- escribe directamente en `appointments` con estado `pending`

Qué habría que replicar en móvil:

- modelos `Appointment`, `TimeSlot`, `Bono`, `BlockedSlot`, `SlotOccupancy`
- lectura del bono activo
- lectura de disponibilidad mensual
- lógica visual de calendario y bloqueo de solapes

Qué se puede reutilizar tal cual:

- estructura de datos
- reglas de negocio visuales del calendario
- shape actual de `appointments`

Qué debería cambiarse o moverse a backend:

- la creación de la cita
- la validación de disponibilidad real
- la validación del bono y de aforo
- cualquier operación sensible que hoy depende del cliente

### 2. Avisos de citas

Nada que replicar en la app cliente: los avisos los genera el backend. Hoy los avisos de citas salen del backend y el único sistema es Brevo (email), FCM (push) y el historial en Firestore; ver `notifications-contract.md` en `web_focus_club/docs`. La app solo registra su token FCM y muestra el historial.

### 3. Foto de perfil

Qué hace hoy la web:

- permite seleccionar imagen
- muestra preview local
- sube a Storage al guardar
- actualiza `users.photoURL`
- borra foto anterior al reemplazar o al eliminar
- muestra fallback de inicial si no hay foto

Qué habría que replicar en móvil:

- selector de imagen
- preview local
- subida a `user-avatars/{uid}/...`
- actualización de `users/{uid}.photoURL`
- borrado del avatar anterior
- fallback visual a inicial

Qué se puede reutilizar tal cual:

- estructura de Storage path
- campo `photoURL`
- reglas de ownership
- comportamiento funcional de reemplazo y borrado

Qué debería cambiarse o moverse a backend:

- no hay una necesidad equivalente a la reserva; este flujo puede mantenerse cliente + Storage/Firestore si se quiere conservar el mismo comportamiento actual
- lo que sí debería mantenerse consistente es la validación por reglas y el path de Storage por usuario

## Verificaciones realizadas

- búsqueda de términos: `appointments`, `bookings`, `reservations`, `slot_occupancy`, `blocked_slots`, `bonos`, `users`, `functions`, `httpsCallable`, `addDoc`, `setDoc`, `updateDoc`, `runTransaction`, `fetch`, `axios`
- lectura directa de:
  - [src/app/portal/page.tsx](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/app/portal/page.tsx)
  - [src/components/ui/interactive-calendar.tsx](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/components/ui/interactive-calendar.tsx)
  - [src/lib/firestore.ts](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/lib/firestore.ts)
  - [src/lib/firebase.ts](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/lib/firebase.ts)
  - [src/contexts/AuthContext.tsx](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/contexts/AuthContext.tsx)
  - [src/types/index.ts](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/types/index.ts)
  - [firestore.rules](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/firestore.rules)
  - [storage.rules](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/storage.rules)
  - [firebase.json](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/firebase.json)
  - [.firebaserc](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/.firebaserc)
  - [src/app/admin/page.tsx](C:/Users/Perez/Documents/AA_Clientes/web_focus_club/src/app/admin/page.tsx)
- comprobación remota con Firebase CLI:
  - proyecto `focus-club-f73b8`
  - resultado: `No functions found in project focus-club-f73b8`
