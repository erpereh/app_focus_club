# Pendientes implantacion Firebase movil

Fecha: 2026-04-14

## Implementado en el repo

- Dependencias Flutter Firebase anadidas para Auth, Firestore, Storage, Functions y Google Sign-In.
- Contratos Dart del portal cliente para `users`, `appointments`, `bonos`, `trainers`, `blocked_slots`, `slot_occupancy` y `site_config/main`.
- Logica pura de disponibilidad con sub-slots internos de 15 minutos y capacidad fija `2`.
- Regla de negocio de maximo un bono `activo` util por usuario en la capa de dominio.
- Repositorio Firebase/Fake para lecturas del portal y callable `requestAppointment`.
- Repositorios base para Auth y avatar Storage.
- Auth real integrado en la app Flutter:
  - Login email/password, registro email/password, reset password y logout usan Firebase Auth.
  - Registro crea perfil minimo en `users/{uid}`, envia verificacion y cierra sesion.
  - Login bloquea email no verificado y reenvia enlace de verificacion.
  - Google Sign-In crea/carga perfil parcial y exige telefono antes de entrar al dashboard.
  - Splash resuelve sesion persistida con Firebase Auth.
- Google Sign-In nativo configurado:
  - iOS `Info.plist` contiene `GIDClientID` y URL scheme de Google.
  - Android tiene SHA1 debug registrada en Firebase (`F6:85:2E:7B:B2:19:58:7E:24:C0:71:3A:37:8E:CF:31:0B:4D:9E:85`) y `google-services.json` refrescado.
- ViewModel base del portal cliente para sustituir progresivamente `MockClientData`.
- Scaffold local de Firebase: `firebase.json`, `.firebaserc`, `firestore.rules`, `storage.rules`, `firestore.indexes.json`.
- Apps Android/iOS registradas en `focus-club-f73b8` con FlutterFire CLI:
  - Android: `es.focusclub.clientes.app_focus_club` (`1:1555015411:android:8f12201d8f5b521fe67986`).
  - iOS: `es.focusclub.clientes.appFocusClub` (`1:1555015411:ios:5438e5635dd12b16e67986`).
- Configuracion oficial Flutter generada en `lib/firebase_options.dart`, `android/app/google-services.json` e `ios/Runner/GoogleService-Info.plist`.
- Inicializacion base integrada con `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`.
- Scaffold local de Cloud Functions TypeScript para `requestAppointment`, `approveAppointment`, `rejectAppointment`, `updateAppointmentSlot`, `assignBonoToUser` y `expireOverdueBonos`.
- Punto de integracion Make.com preparado en backend para `Reserva confirmada`, desactivado por defecto y mediante secreto `MAKE_RESERVATION_WEBHOOK_URL`.
- Tests puros para sub-slots, capacidad, solape, bono activo unico y parsing de campos opcionales.

## Preparado pero no desplegado

- Reglas Firestore/Storage locales. No se han desplegado al proyecto `focus-club-f73b8`.
- Functions locales. No se han instalado dependencias npm, compilado ni desplegado.
- Integracion Make.com. No se ha guardado el webhook como secreto y no se han hecho llamadas reales.
- `requestAppointment` esta preparado como callable, pero la app todavia no lo invoca desde UI real.
- La UI movil sigue usando `MockClientData` mientras se conecta el ViewModel a pantallas concretas.
- Dashboard, citas, bonos, reserva, perfil visual y avatar siguen en modo mock salvo el perfil minimo usado por Auth/Google.
- No se ha desplegado App Hosting, web, reglas, Functions ni datos a produccion.

## Pendiente por confirmar

- Confirmar en Firebase Console que los providers Email/Password y Google estan habilitados en Auth si aparece `operation-not-allowed`.
- Registrar SHA de release/play signing en Firebase antes de probar Google Sign-In fuera de debug local.
- Confirmar cuando endurecer reglas en produccion, porque la web/admin existente aun puede depender de creacion directa de `appointments`.
- Confirmar payload exacto esperado por Make.com para `Reserva confirmada`.
- Confirmar si el backend administrativo emitira `Reserva eliminada`; no pertenece a la app movil V1.

## Pasos recomendados para Android/iOS

1. Ejecutar `flutter analyze` y `flutter test` tras cada cambio relevante.
2. Probar login, registro, reset, Google Sign-In y logout en emulador/dispositivo.
3. Probar lecturas de dashboard contra emulador antes de sustituir `MockClientData`.

## Riesgos abiertos

- Storage en produccion esta mas abierto que la regla local preparada; no desplegar sin revisar impacto en CMS/media.
- Firestore en produccion aun permite crear citas desde cliente; cerrar esto requiere coordinar web/admin y app movil con `requestAppointment`.
- Cloud Functions API aparecio deshabilitada o sin uso en `focus-club-f73b8`; habilitarla es una accion de proyecto que requiere autorizacion.
- `slot_occupancy` usa sub-slots internos de 15 minutos; cualquier reconciliacion futura debe comparar por bloques internos, no por cita completa.
- La app aun necesita reemplazar `MockClientData` por repositorios/ViewModels en las pantallas.
