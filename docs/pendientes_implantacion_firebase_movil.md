# Pendientes implantacion Firebase movil

Fecha: 2026-04-14

## Implementado en el repo

- Dependencias Flutter Firebase anadidas para Auth, Firestore, Storage, Functions y Google Sign-In.
- Contratos Dart del portal cliente para `users`, `appointments`, `bonos`, `trainers`, `blocked_slots`, `slot_occupancy` y `site_config/main`.
- Logica pura de disponibilidad con sub-slots internos de 15 minutos y capacidad fija `2`.
- Regla de negocio de maximo un bono `activo` util por usuario en la capa de dominio.
- Repositorio Firebase/Fake para lecturas del portal y callable `requestAppointment`.
- Repositorios base para Auth y avatar Storage.
- ViewModel base del portal cliente para sustituir progresivamente `MockClientData`.
- Scaffold local de Firebase: `firebase.json`, `.firebaserc`, `firestore.rules`, `storage.rules`, `firestore.indexes.json`.
- Scaffold local de Cloud Functions TypeScript para `requestAppointment`, `approveAppointment`, `rejectAppointment`, `updateAppointmentSlot`, `assignBonoToUser` y `expireOverdueBonos`.
- Punto de integracion Make.com preparado en backend para `Reserva confirmada`, desactivado por defecto y mediante secreto `MAKE_RESERVATION_WEBHOOK_URL`.
- Tests puros para sub-slots, capacidad, solape, bono activo unico y parsing de campos opcionales.

## Preparado pero no desplegado

- Reglas Firestore/Storage locales. No se han desplegado al proyecto `focus-club-f73b8`.
- Functions locales. No se han instalado dependencias npm, compilado ni desplegado.
- Integracion Make.com. No se ha guardado el webhook como secreto y no se han hecho llamadas reales.
- `requestAppointment` esta preparado como callable, pero la app todavia no lo invoca desde UI real.
- La UI movil sigue usando `MockClientData` mientras se conecta el ViewModel a pantallas concretas.

## Pendiente por confirmar

- Registrar apps Android/iOS en `focus-club-f73b8` o proporcionar `android/app/google-services.json` y `ios/Runner/GoogleService-Info.plist`.
- Confirmar si se permite aplicar los plugins nativos de Firebase Android/iOS cuando existan los archivos de configuracion.
- Confirmar cuando endurecer reglas en produccion, porque la web/admin existente aun puede depender de creacion directa de `appointments`.
- Confirmar payload exacto esperado por Make.com para `Reserva confirmada`.
- Confirmar si el backend administrativo emitira `Reserva eliminada`; no pertenece a la app movil V1.

## Pasos recomendados para Android/iOS

1. Registrar app Android en Firebase con package actual `es.focusclub.clientes.app_focus_club`.
2. Descargar `google-services.json` y colocarlo en `android/app/google-services.json`.
3. Registrar app iOS con el bundle id que se vaya a usar en Xcode.
4. Descargar `GoogleService-Info.plist` y colocarlo en `ios/Runner/GoogleService-Info.plist`.
5. Aplicar la configuracion nativa de Firebase en Gradle/iOS o generar `firebase_options.dart` con FlutterFire CLI.
6. Ejecutar `flutter analyze` y `flutter test`.
7. Probar login/lecturas contra emulador antes de usar produccion.

## Riesgos abiertos

- Storage en produccion esta mas abierto que la regla local preparada; no desplegar sin revisar impacto en CMS/media.
- Firestore en produccion aun permite crear citas desde cliente; cerrar esto requiere coordinar web/admin y app movil con `requestAppointment`.
- Cloud Functions API aparecio deshabilitada o sin uso en `focus-club-f73b8`; habilitarla es una accion de proyecto que requiere autorizacion.
- `slot_occupancy` usa sub-slots internos de 15 minutos; cualquier reconciliacion futura debe comparar por bloques internos, no por cita completa.
- La app aun necesita reemplazar `MockClientData` por repositorios/ViewModels en las pantallas.
