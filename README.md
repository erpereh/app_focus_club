# app_focus_club

App movil de clientes para Focus Club Vallecas.

## Estado

- Proyecto Flutter inicializado para Android e iOS.
- Base de UI preparada con tema oscuro Focus Club.
- Firebase base configurado con FlutterFire para el proyecto `focus-club-f73b8` en Android e iOS.
- Inicializacion base con `DefaultFirebaseOptions.currentPlatform`.
- Auth real integrado para email/password, recuperacion, Google Sign-In, sesion persistida y logout.
- Sin despliegue de reglas/Functions ni conexion completa de dashboard/citas/bonos/reserva a datos reales todavia.

## Primeras verificaciones

```powershell
flutter pub get
flutter analyze
flutter test
```

## Ejecucion local

Esta app esta configurada solo para Android e iOS. No uses Chrome como target:

```powershell
flutter devices
flutter run -d <deviceId-android-o-ios>
```

`flutter run -d chrome` no esta soportado ahora mismo porque no hay carpeta `web/` ni configuracion Firebase Web en `lib/firebase_options.dart`. Si en el futuro se quiere web real, habra que generar soporte web y reconfigurar FlutterFire incluyendo la plataforma `web`.
