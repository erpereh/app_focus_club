# Notificaciones en la app móvil

La app consume el sistema de notificaciones de `web_focus_club` (commit `a7496df`). La fuente de verdad es el contrato `web_focus_club/docs/notifications-contract.md`.

**Qué hace y qué no hace la app:**
- **No envía** emails ni push.
- **No crea** entradas de historial.
- **Solo** recibe los push, muestra el historial, marca avisos como leídos y navega al destino de cada aviso.

## 1. Arquitectura

| Pieza | Archivo | Qué hace |
|---|---|---|
| Modelo y parseo | `lib/features/notifications/domain/notification_models.dart` | `NotificationTarget` (destino), `AppNotification` (documento de historial) |
| Iconos y fechas | `lib/features/notifications/domain/notification_presentation.dart` | Icono, color y etiqueta por `event`; fecha relativa en español |
| Historial | `lib/features/notifications/data/notifications_repository.dart` | Lee y marca como leído `users/{uid}/notifications` |
| Estado | `lib/features/notifications/application/notifications_view_model.dart` | Lista, contador de no leídas, marcar una, marcar todas |
| Navegación | `lib/features/notifications/application/notification_navigator.dart` | Guarda el destino hasta que hay sesión y la shell está montada |
| UI | `lib/features/notifications/presentation/` | Pantalla de historial, campana con contador, banner en primer plano |
| Push | `lib/features/client/data/push_notification_service.dart` | Permisos, tokens, mensajes en primer plano |
| Arranque | `lib/firebase/push_messaging_bootstrap.dart` | Handler de segundo plano y opciones de presentación en iOS |

## 2. Recepción por estado de la app

| Estado | Comportamiento |
|---|---|
| Primer plano | `FirebaseMessaging.onMessage` muestra un banner propio, negro y lima, en la parte superior. Se cierra solo a los 5 s y al pulsarlo navega. En iOS el banner del sistema está desactivado (`alert: false`) para que no salgan dos avisos. Si llega un `support_message` de la conversación que ya está abierta, no hay banner y la entrada del historial se marca como leída. |
| Segundo plano / app cerrada | El backend envía un bloque `notification`, así que el sistema operativo muestra el aviso. `firebaseMessagingBackgroundHandler` solo inicializa Firebase; no hay nada que guardar, porque el historial ya está en Firestore. |
| Pulsar el aviso | `getInitialMessage` (arranque en frío) y `onMessageOpenedApp` (segundo plano) convierten `data` en un `NotificationTarget` y se lo pasan a `NotificationNavigator.handle`. |

La app nunca programa notificaciones locales. El banner no escribe nada. El historial de Firestore es la única fuente, así que no hay avisos duplicados.

## 3. Navegación

| `route` | Destino |
|---|---|
| `appointment` | Pestaña Citas y después el detalle de la cita (`AppointmentDetailScreen`). Si la cita ya no existe, se queda en Citas y muestra "La cita ya no está disponible." |
| `appointments` | Pestaña Citas (series recurrentes) |
| `bono` | Pestaña Inicio, donde está la tarjeta del bono activo. No hay pantalla de bono propia. |
| `chat` | Pestaña Chat y después la conversación (`SupportChatScreen`), que se carga por `conversationId` |

**Destino pendiente.** `NotificationNavigator` guarda el destino mientras no haya una `ClientShellScreen` montada: splash, login, completar el perfil de Google o sesión caducada. La shell lo consume en cuanto se monta, después de la puerta de autenticación del splash. Antes, el tap en frío saltaba esa puerta. Al cerrar sesión, el destino pendiente se descarta.

**Al abrir un destino:**
- se cierran las pantallas que hubiera encima de la shell;
- la entrada del historial (`notificationId`) se marca como leída.

### Compatibilidad con tipos antiguos

Si no viene `route`, el destino se deduce de `type`:

| `type` | Destino deducido |
|---|---|
| `appointment_status` con `appointmentId` | `appointment` |
| `appointment_status` sin `appointmentId` | `appointments` |
| `support_message` | `chat` |
| `bono_status` | `bono` |

Otros detalles:
- Las entradas antiguas del historial sin `event` ni `navigation` también funcionan.
- `AppRouter.dashboardTabForNotificationType` se mantiene y ahora también cubre `bono_status`.
- Un `type` desconocido no navega. En el historial se muestra con un icono genérico.

## 4. Historial (`users/{uid}/notifications`)

**Lectura:**
- `orderBy('createdAt', desc).limit(100)`.
- El contador de no leídas usa `where('read', isEqualTo: false)`.
- Ninguna de las dos consultas necesita índices compuestos.

**Marcado:**
- Una entrada: `update({read: true, readAt: serverTimestamp()})`. Las reglas web solo permiten modificar esos dos campos.
- Marcar todas: lotes de hasta 450 escrituras.

**Acceso desde la app:**
- Campana con contador en la cabecera de Inicio (`dashboard-notifications-bell`). El contador muestra `99+` a partir de 100.

**Cada entrada muestra:**
- icono según `event`;
- título y cuerpo;
- fecha relativa ("Ahora", "Hace 5 min", "Hace 3 h", "Ayer, 18:30", `dd/MM/yyyy, HH:mm`);
- un punto lima si no está leída.

## 5. Preferencias y tokens

**Preferencias:** sin cambios. El interruptor de Perfil escribe `users/{uid}.pushNotificationsEnabled`, y el backend no envía push si no es `true`. El historial se genera igualmente, así que el usuario ve sus avisos aunque tenga el push desactivado.

**Tokens en `users/{uid}/fcmTokens/{token}`** (ciclo completo en el contrato web, apartado 4):
- **Registro:** el token se guarda al activar el push y al cargar el perfil si ya estaba activado. Cada guardado refresca `updatedAt`. El servicio recuerda el último token registrado.
- **Renovación** (`onTokenRefresh`): se guarda el token nuevo y se borra el documento del anterior.
- **Desactivar el push:** además de `pushNotificationsEnabled = false`, se borra el documento del token de este dispositivo. El token de FCM se conserva, así que al reactivar se vuelve a registrar.
- **Cerrar sesión o borrar la cuenta:** antes de `signOut` (las reglas exigen estar autenticado) se borra el documento del token y se llama **siempre** a `deleteToken()`. Si la sesión no registró el token (push desactivado, registro fallido o una build anterior), se obtiene de FCM con un límite de 5 s. Los fallos se registran pero no bloquean el logout.
- **Servidor:** `onFcmTokenWritten` quita el token de cualquier otra cuenta, así que un móvil que cambia de manos nunca recibe los avisos del cliente anterior. `pruneStaleFcmTokensScheduled` borra los tokens sin refrescar en 270 días, y el envío sigue borrando los tokens que FCM rechaza.

## 6. Cloud Functions de este repositorio (codebase `portal`)

`functions/` usa el codebase `portal`, en el mismo proyecto (`focus-club-f73b8`) y región (`europe-west1`) que `web_focus_club` (codebase `default`).

- **Solo exporta `deleteOwnAccount`**, que es lo único que está desplegado desde aquí (Node 22). `scripts/check-exports.cjs` falla si se exporta cualquier otra cosa, y se ejecuta en `npm test` y como `predeploy` de functions.
- Se han retirado del código las callables antiguas (`createAppointment`, `requestAppointment`, `approveAppointment`, `rejectAppointment`, `updateAppointmentSlot`, `assignBonoToUser`) y el scheduler `expireOverdueBonos`. Nunca se desplegaron desde este codebase: la `createAppointment` de producción es la de la web. Su código sigue disponible en el historial de git (commit `8429862`).
- `deleteOwnAccount` también borra las entregas de `notification_deliveries` de ese `uid`. El cambio entra en producción al desplegar el codebase `portal` (opcional; ver la checklist).
- `npm run deploy` solo despliega `functions:portal:deleteOwnAccount`.
- `firestore.rules`, `firestore.indexes.json` y `storage.rules` de este repo son **solo para emuladores**. Están desactualizados y los `predeploy` de `firebase.json` bloquean su despliegue. Las reglas, los índices y el storage válidos son los de `web_focus_club`.

## 7. Dependencias pendientes

1. **Desplegar la web** (manual): las functions de `a7496df` y su `firestore.rules`. Sin la regla de `notifications`, la app no puede leer el historial: el historial muestra error y el contador queda a 0.
2. **iOS:** la configuración Release usa `RunnerRelease.entitlements` (`aps-environment = production`). Debug y Profile siguen con `Runner.entitlements` (`development`). `UIBackgroundModes: remote-notification` ya está en `Info.plist`. **Pendiente manual:** subir la clave APNs (.p8) a Firebase Console > Configuración del proyecto > Cloud Messaging y comprobar que el App ID tiene activado Push Notifications en Apple Developer.
3. **Android:** `MainActivity` crea el canal `focus_club_default` ("Focus Club", importancia alta) y el manifest lo declara como canal por defecto de FCM. El backend envía `channelId: "focus_club_default"`, prioridad alta y sonido.
4. **Publicar** nuevas versiones Android/iOS: es manual y no forma parte de este cambio.
5. El badge del icono de la app (número sobre el icono) no se gestiona.

## 8. Pruebas manuales

Enviar un push de prueba desde la consola de Firebase (o con un script de Admin SDK) a un token del dispositivo, con un `data` del contrato, por ejemplo:

```json
{ "type": "appointment_status", "event": "appointment_confirmed", "notificationId": "<id>", "route": "appointment", "appointmentId": "<cita>", "status": "approved" }
```

Comprobaciones:
1. App en **primer plano**: aparece el banner y al pulsarlo se abre el detalle.
2. App en **segundo plano**: aparece la notificación del sistema y al pulsarla se abre el detalle.
3. App **cerrada y sin sesión**: al pulsar se abre el login; tras iniciar sesión se abre el detalle.
4. `support_message` con el chat de esa conversación abierto: no hay banner.
5. Historial: el contador baja al abrir un aviso. "Marcar todas" deja el contador a 0.
6. Cerrar sesión: el documento del token desaparece de `users/{uid}/fcmTokens`.
7. Desactivar el push en Perfil: el documento del token de este dispositivo desaparece.
8. Cerrar sesión con A e iniciar con B en el mismo móvil: los avisos de A ya no llegan a ese móvil.
9. Android 8+: en Ajustes > Notificaciones de la app aparece el canal "Focus Club".

Tests automáticos:
- `test/notification_target_test.dart`
- `test/notifications_history_test.dart`
- `test/notification_navigation_test.dart`
- `test/push_notification_service_test.dart`
- `test/push_platform_config_test.dart` (canal Android y entitlements iOS)
- `test/release_version_test.dart` (la versión de `pubspec.yaml` es posterior a la última publicada, 1.4.4+14)
- `functions/test/deleteOwnAccount.test.cjs` (con `npm test` en `functions/`)
