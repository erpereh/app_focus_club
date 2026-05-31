# Publicacion Android e iOS - Focus Club

Estado revisado el 30/05/2026 para preparar la app Flutter de Focus Club para Google Play y, mas adelante, App Store Connect/TestFlight.

## Estado actual

- Nombre publico: `Focus Club`.
- Android mantiene `applicationId` y `namespace`: `es.focusclub.clientes.app_focus_club`.
- iOS mantiene Bundle Identifier: `es.focusclub.clientes.appFocusClub`.
- Proyecto Firebase: `focus-club-f73b8`.
- App Firebase Android: `app_focus_club (android)`, app id `1:1555015411:android:8f12201d8f5b521fe67986`.
- App Firebase iOS: `app_focus_club (ios)`, app id `1:1555015411:ios:5438e5635dd12b16e67986`.
- `google-services.json`, `GoogleService-Info.plist` y `lib/firebase_options.dart` apuntan a `focus-club-f73b8`.
- SHA debug Android ya registrada en Firebase: `F6:85:2E:7B:B2:19:58:7E:24:C0:71:3A:37:8E:CF:31:0B:4D:9E:85`.
- SHA release pendiente: debe generarse desde el keystore real y anadirse a Firebase antes de probar Google Sign-In en release.

Bloqueos manuales:

- Falta crear `android/upload-keystore.jks`.
- Falta crear `android/key.properties` con passwords reales.
- Falta anadir SHA release a Firebase y descargar de nuevo `android/app/google-services.json` si Firebase lo actualiza.
- Falta configurar ficha, testers y declaracion de datos en Google Play Console.
- iOS requiere Mac, Xcode y Apple Developer Program.
- No se debe desplegar Functions desde esta copia sin revisar antes: Firebase remoto tiene funciones desplegadas que no coinciden completamente con `functions/src/index.ts`.

## Android / Google Play

Identificadores que no deben cambiar:

- `applicationId`: `es.focusclub.clientes.app_focus_club`
- `namespace`: `es.focusclub.clientes.app_focus_club`
- paquete Kotlin `MainActivity`: `es.focusclub.clientes.app_focus_club`

Firma release:

- La release no usa debug signing.
- Si falta `android/key.properties`, `flutter build appbundle --release` debe fallar con un mensaje claro.
- No subir a Git `android/key.properties`, `.jks` ni `.keystore`.

Crear el keystore manualmente desde la raiz del proyecto:

```powershell
keytool -genkeypair -v -keystore android/upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Crear `android/key.properties` copiando `android/key.properties.example`:

```properties
storeFile=upload-keystore.jks
storePassword=TU_PASSWORD_REAL
keyAlias=upload
keyPassword=TU_PASSWORD_REAL
```

Generar el `.aab`:

```powershell
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release
```

Salida esperada del `.aab`:

```text
build/app/outputs/bundle/release/app-release.aab
```

Obtener SHA release para Firebase:

```powershell
keytool -list -v -keystore android/upload-keystore.jks -alias upload
```

En Firebase Console:

1. Abrir proyecto `focus-club-f73b8`.
2. Ir a Project settings > Your apps > Android `es.focusclub.clientes.app_focus_club`.
3. Anadir SHA-1 y SHA-256 del keystore de subida.
4. Descargar `google-services.json` si Firebase lo regenera.
5. Reemplazar `android/app/google-services.json`.
6. Ejecutar de nuevo `flutter build appbundle --release`.

Google Play Console, test interno:

1. Crear app con nombre `Focus Club`.
2. Categoria: `Salud y bienestar / Health & Fitness`.
3. Package name: `es.focusclub.clientes.app_focus_club`.
4. Configurar App signing by Google Play.
5. Subir `app-release.aab` a Internal testing.
6. Anadir testers.
7. Completar Data safety, Privacy policy, contenido de la app y datos de contacto.
8. Enviar el track de test interno a revision.

## iOS / App Store Connect

No compilar iOS en Windows. Revisar y terminar en Mac.

Identificador que no debe cambiar:

- Bundle Identifier: `es.focusclub.clientes.appFocusClub`

Pasos en Mac:

1. Instalar Flutter, Xcode y CocoaPods.
2. Abrir `ios/Runner.xcworkspace` en Xcode.
3. Seleccionar target `Runner`.
4. Mantener Bundle Identifier `es.focusclub.clientes.appFocusClub`.
5. Configurar Team de Apple Developer y Automatic signing.
6. Confirmar nombre visible `Focus Club`.
7. Confirmar `ios/Runner/GoogleService-Info.plist`.
8. Activar Push Notifications y Background Modes > Remote notifications si se van a probar notificaciones.
9. Crear APNs key en Apple Developer y subirla a Firebase Cloud Messaging.
10. Archivar desde Xcode y subir a App Store Connect/TestFlight.

Google Sign-In iOS:

- `GIDClientID` esta en `Info.plist`.
- URL scheme: `com.googleusercontent.apps.1555015411-vrde6e7h8j5klmfv35s6rus2r92pakcf`.
- `GoogleService-Info.plist` mantiene `BUNDLE_ID` `es.focusclub.clientes.appFocusClub`.

Permisos iOS:

- Fotos: `NSPhotoLibraryUsageDescription` para seleccionar foto de perfil.
- Notificaciones: la app solicita permiso mediante Firebase Messaging; APNs debe configurarse en Apple y Firebase.

## Firebase

Revisado:

- Apps Android/iOS existentes en `focus-club-f73b8`; no crear apps nuevas.
- Config FlutterFire local apunta a las apps existentes.
- Storage rules validan sin errores.
- Firestore rules validan con warnings no bloqueantes por funcion no usada.
- Functions remotas detectadas en `europe-west1`: `createAppointment`, `onAppointmentApproved`, `onAppointmentDeleted`, `onAppointmentStatusPushNotification`, `sendContactMessage`.

Pendiente antes de publicar:

- Revisar en Firebase Auth que Email/Password y Google esten habilitados.
- Anadir SHA release Android.
- Probar Google Sign-In con build release tras actualizar SHA.
- Confirmar que FCM recibe tokens en Android release.
- Configurar APNs antes de probar notificaciones iOS.
- Revisar App Check, pero no activar enforcement sin una decision separada.
- No desplegar reglas ni Functions durante esta preparacion.

## Datos de tienda

- Nombre: `Focus Club`.
- Email soporte: `infofocusclub2026@gmail.com`.
- Politica de privacidad: `https://focusclub.es/politica-de-privacidad`.
- Categoria recomendada: `Salud y bienestar / Health & Fitness`.
- Descripcion corta: `Focus Club: gestiona tus citas, bonos y perfil desde una app sencilla.`
- Descripcion larga: `Focus Club es la app para clientes del centro Focus Club Vallecas. Desde la app puedes consultar tu bono, revisar tus proximas citas, solicitar nuevas sesiones, gestionar tu perfil, actualizar tu foto y recibir notificaciones cuando tus citas sean aprobadas o rechazadas. Disenada para que tengas toda la informacion importante de tu entrenamiento en un solo lugar, de forma rapida, comoda y segura.`

Datos a declarar:

- Email y password via Firebase Auth.
- Nombre, telefono y foto de perfil.
- Citas solicitadas, citas aprobadas/rechazadas y comentarios de reserva.
- Bonos, minutos disponibles e historial asociado.
- Tokens FCM para notificaciones push.
- Imagenes de perfil en Firebase Storage.

## Checklist final

- `flutter analyze` sin errores.
- `flutter test` sin fallos.
- `flutter build appbundle --release` genera `.aab` firmado con keystore real.
- `versionCode` no usado previamente en Google Play.
- SHA release anadida a Firebase.
- Google Sign-In probado en release/internal testing.
- Push notifications probadas en Android release.
- Politica de privacidad publicada y enlazada en tienda.
- Data safety completado con los datos reales usados por la app.
- Para iOS: Team, signing, APNs, TestFlight y privacidad completados en App Store Connect.
