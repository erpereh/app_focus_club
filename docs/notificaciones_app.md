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

**Tokens en `users/{uid}/fcmTokens/{token}`:**
- **Registro:** el token se guarda al activar el push y al cargar el perfil si ya estaba activado. El servicio recuerda el último token registrado.
- **Renovación** (`onTokenRefresh`): se guarda el token nuevo y se borra el documento del anterior.
- **Cerrar sesión o borrar la cuenta:** antes de `signOut` (las reglas exigen estar autenticado) se borra el documento del token y se llama a `deleteToken()`. Así el dispositivo deja de recibir los avisos de ese cliente. Los fallos se registran pero no bloquean el logout.
- **Tokens inválidos:** el backend sigue podándolos tras un envío fallido.

## 6. Cloud Functions antiguas de este repositorio: posibles conflictos

`functions/src/index.ts` usa el codebase `portal` y el mismo proyecto (`focus-club-f73b8`) y la misma región (`europe-west1`) que `web_focus_club`, que usa el codebase `default`. **No se ha borrado nada.** Hay que revisar lo siguiente antes de cualquier deploy desde este repo:

| Función móvil | Posible conflicto con la web |
|---|---|
| `createAppointment` | **Mismo nombre** que una callable de la web. Dos codebases no pueden tener el mismo nombre de función: un `firebase deploy --only functions` desde aquí puede reclamar o sustituir la versión web, que es la que estampa los datos que usan los triggers de notificación. |
| `requestAppointment` | Alias de la misma lógica móvil. La web no la tiene. Las citas que crea generan `appointment_requested` a través del trigger web, sin conflicto directo. |
| `approveAppointment` | Descuenta minutos **al aprobar**. El contrato web reserva los minutos **al solicitar**, así que se podrían descontar dos veces o generar un `bono_exhausted` antes de tiempo. Además, el webhook de Make (`MAKE_WEBHOOK_ENABLED`) es un aviso paralelo si está activado. |
| `rejectAppointment` | Devuelve minutos solo si la cita estaba aprobada. Mismo riesgo de semántica de minutos que `approveAppointment`. El aviso `appointment_rejected` lo envía el trigger web. |
| `updateAppointmentSlot` | Mueve una cita aprobada sin `notificationOperationId`. El trigger web enviará `appointment_rescheduled` (correcto para una cita individual). |
| `assignBonoToUser` | Marca los bonos anteriores como `eliminado`. El contrato web, al renovar, pasa el anterior a `agotado` sin aviso. Un estado distinto puede confundir la detección de `bono_renewed` / `bono_exhausted`. |
| `expireOverdueBonos` (diaria) | Hace lo mismo que `expireOverdueBonosScheduled` (web, cada hora). Es redundante. El aviso `bono_expired` está deduplicado (`bono:{id}:expired`), así que no habrá avisos dobles. |
| `deleteOwnAccount` | Lo usa la app y no existe en la web. Hace `recursiveDelete(users/{uid})`, que borra también `notifications` y `fcmTokens`. Compatible. |

Otros riesgos:
- `firestore.rules` de este repo está **desactualizado**: no tiene reglas para `notifications`, `fcmTokens` ni `support_conversations`, y no permite escribir `pushNotificationsEnabled`. **No se debe desplegar** desde aquí. Las reglas válidas son las de `web_focus_club`.
- La función `onAppointmentStatusPushNotification`, ya desplegada (ver `docs/publicacion_android_ios.md`), es la que hoy envía los push `appointment_status`. Se elimina al desplegar la web. Hasta entonces, los push antiguos (sin `route`) siguen funcionando gracias al modo de compatibilidad.

Recomendación: retirar `createAppointment`, `approveAppointment`, `rejectAppointment`, `updateAppointmentSlot`, `assignBonoToUser` y `expireOverdueBonos` del codebase `portal`, o renombrarlas, una vez se confirme que ni la app ni el panel web las usan.

## 7. Dependencias pendientes

1. **Desplegar la web** (manual): las functions de `a7496df` y su `firestore.rules`. Sin la regla de `notifications`, la app no puede leer el historial: el historial muestra error y el contador queda a 0.
2. **iOS:** `Runner.entitlements` tiene `aps-environment = development`. Para TestFlight o App Store hace falta `production` (o que lo fije el perfil de distribución), además de la clave APNs subida a Firebase. Se ha añadido `UIBackgroundModes: remote-notification` a `Info.plist`.
3. **Android:** sin canal propio, FCM usa su canal de respaldo ("Miscellaneous"). Para tener un canal "Focus Club" con importancia alta hay que crearlo de forma nativa (Kotlin o `flutter_local_notifications`) y declarar `com.google.firebase.messaging.default_notification_channel_id`.
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

Tests automáticos:
- `test/notification_target_test.dart`
- `test/notifications_history_test.dart`
- `test/notification_navigation_test.dart`
- `test/push_notification_service_test.dart`
