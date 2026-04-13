# Preparacion Flutter + AI

Fecha de preparacion: 2026-04-13

Este repo queda preparado para trabajar con Flutter + AI, priorizando desarrollo de UI movil. No se ha generado todavia una app Flutter: no existe `pubspec.yaml`, `lib/`, `android/`, `ios/`, `package.json`, `.cursor/` ni `.gemini/`.

## Estado real del entorno

Comprobado antes y despues de la instalacion:

- Node: `v22.20.0`
- npm: `11.10.0` usando `npm.cmd`
- npx: `11.10.0` usando `npx.cmd`
- Codex CLI: `0.119.0-alpha.28`
- Dart SDK: disponible desde Flutter SDK, version `3.11.4`; tambien queda instalado Dart standalone por winget como fallback
- Python: instalado Python `3.12.10`; `python` fuera del sandbox tambien resuelve a `3.11.9`
- Flutter SDK: instalado en `C:\Users\Perez\develop\flutter`, version `3.41.6`, channel `stable`

Notas de Windows:

- En PowerShell, `npm` puede fallar por Execution Policy al cargar `npm.ps1`. Usar `npm.cmd` y `npx.cmd`.
- Flutter esta al inicio del User PATH:

```text
C:\Users\Perez\develop\flutter\bin
```

- `flutter` y `dart` resuelven primero al SDK de Flutter:

```text
C:\Users\Perez\develop\flutter\bin\flutter.bat
C:\Users\Perez\develop\flutter\bin\dart.bat
```

- Dart standalone fue instalado por winget y queda despues en PATH:

```text
C:\Users\Perez\AppData\Local\Microsoft\WinGet\Packages\Google.DartSDK_Microsoft.Winget.Source_8wekyb3d8bbwe\dart-sdk\bin\dart.exe
```

- Dart Pub aviso que `C:\Users\Perez\AppData\Local\Pub\Cache\bin` no esta en PATH. Marionette se registro en Codex via `dart pub global run marionette_mcp`, sin depender del `.bat`.

## Comandos ejecutados

Prerequisitos globales:

```powershell
winget install --id Google.DartSDK -e --accept-package-agreements --accept-source-agreements
winget install --id Python.Python.3.12 -e --accept-package-agreements --accept-source-agreements
```

Verificacion:

```powershell
cmd.exe /c C:\Users\Perez\develop\flutter\bin\flutter.bat --version
flutter --version
dart --version
flutter doctor
& "C:\Users\Perez\AppData\Local\Microsoft\WinGet\Packages\Google.DartSDK_Microsoft.Winget.Source_8wekyb3d8bbwe\dart-sdk\bin\dart.exe" --version
& "C:\Users\Perez\AppData\Local\Programs\Python\Python312\python.exe" --version
npm.cmd --version
npx.cmd --version
codex --version
```

Skills:

```powershell
npx.cmd skills add flutter/skills --yes
npm.cmd install -g uipro-cli
uipro --version
uipro versions
uipro init --ai codex
```

MCP:

```powershell
codex mcp add dart -- "C:\Users\Perez\AppData\Local\Microsoft\WinGet\Packages\Google.DartSDK_Microsoft.Winget.Source_8wekyb3d8bbwe\dart-sdk\bin\dart.exe" mcp-server --force-roots-fallback
& "C:\Users\Perez\AppData\Local\Microsoft\WinGet\Packages\Google.DartSDK_Microsoft.Winget.Source_8wekyb3d8bbwe\dart-sdk\bin\dart.exe" pub global activate marionette_mcp
codex mcp add marionette -- "C:\Users\Perez\AppData\Local\Microsoft\WinGet\Packages\Google.DartSDK_Microsoft.Winget.Source_8wekyb3d8bbwe\dart-sdk\bin\dart.exe" pub global run marionette_mcp
codex mcp list
codex mcp get dart
codex mcp get marionette
```

Verificacion de `ui-ux-pro-max`:

```powershell
& "C:\Users\Perez\AppData\Local\Programs\Python\Python312\python.exe" .codex\skills\ui-ux-pro-max\scripts\search.py "mobile app booking dashboard flutter" --stack flutter --max-results 3
```

## Skills instaladas

### Flutter official skills

Instaladas con:

```powershell
npx.cmd skills add flutter/skills --yes
```

Ubicacion:

```text
.agents/skills/
```

Resultado verificado: `22` skills instaladas.

Skills instaladas:

- `flutter-adding-home-screen-widgets`
- `flutter-animating-apps`
- `flutter-architecting-apps`
- `flutter-building-forms`
- `flutter-building-layouts`
- `flutter-building-plugins`
- `flutter-caching-data`
- `flutter-embedding-native-views`
- `flutter-handling-concurrency`
- `flutter-handling-http-and-json`
- `flutter-implementing-navigation-and-routing`
- `flutter-improving-accessibility`
- `flutter-interoperating-with-native-apis`
- `flutter-localizing-apps`
- `flutter-managing-state`
- `flutter-reducing-app-size`
- `flutter-setting-up-on-linux`
- `flutter-setting-up-on-macos`
- `flutter-setting-up-on-windows`
- `flutter-testing-apps`
- `flutter-theming-apps`
- `flutter-working-with-databases`

Limitacion:

- El repo oficial `flutter/skills` indica que esta en desarrollo y todavia no esta listo para uso estable. Usarlas como apoyo de desarrollo, no como autoridad unica.

Actualizacion futura:

```powershell
npx.cmd skills update flutter/skills
```

Fuente:

- https://github.com/flutter/skills
- https://skills.sh/docs/cli

### UI/UX Pro Max

Instalado con:

```powershell
npm.cmd install -g uipro-cli
uipro init --ai codex
```

Verificado:

- `uipro --version` devuelve `2.2.3`
- `uipro versions` lista `v2.5.0` como latest
- La skill responde con Python 3.12 usando `search.py`

Ubicacion:

```text
.codex/skills/ui-ux-pro-max/
```

Por que se usa:

- Aporta guia UI/UX con datos de estilos, paletas, tipografias, guidelines y stack Flutter.
- Encaja como apoyo para revisar decisiones visuales antes de implementar pantallas.

Uso recomendado para este proyecto:

```powershell
& "C:\Users\Perez\AppData\Local\Programs\Python\Python312\python.exe" .codex\skills\ui-ux-pro-max\scripts\search.py "mobile app booking dashboard flutter" --stack flutter --design-system --project-name "Focus Club"
```

Fuente:

- https://github.com/nextlevelbuilder/ui-ux-pro-max-skill

## MCP configurados

## Flutter SDK

Estado verificado:

```text
Flutter 3.41.6 • channel stable • https://github.com/flutter/flutter.git
Framework • revision db50e20168 • 2026-03-25 16:21:00 -0700
Tools • Dart 3.11.4 • DevTools 2.54.2
```

Ruta del SDK:

```text
C:\Users\Perez\develop\flutter
```

PATH configurado:

```text
C:\Users\Perez\develop\flutter\bin
```

Verificacion final:

```text
where.exe flutter -> C:\Users\Perez\develop\flutter\bin\flutter.bat
where.exe dart -> C:\Users\Perez\develop\flutter\bin\dart.bat
flutter doctor -> Doctor found issues in 2 categories
```

Resultado de `flutter doctor`:

- `[√] Flutter`
- `[√] Windows Version`
- `[!] Android toolchain`: falta `cmdline-tools` y queda pendiente `flutter doctor --android-licenses`
- `[√] Chrome`
- `[!] Visual Studio`: faltan componentes para Windows desktop: MSVC C++ build tools, C++ CMake tools y Windows 10 SDK
- `[√] Connected device`
- `[√] Network resources`

No se instalo Android Studio, Android cmdline-tools ni componentes adicionales de Visual Studio en este paso.

### Dart MCP oficial

Registrado en Codex como `dart`.

Configuracion verificada:

```text
command: C:\Users\Perez\AppData\Local\Microsoft\WinGet\Packages\Google.DartSDK_Microsoft.Winget.Source_8wekyb3d8bbwe\dart-sdk\bin\dart.exe
args: mcp-server --force-roots-fallback
status: enabled
```

Uso esperado:

- Contexto y herramientas de Dart/Flutter.
- Ayuda con analisis, errores y dependencias.
- Uso mas completo cuando el repo tenga un proyecto Flutter real.

Fuente:

- https://dart.dev/tools/mcp-server

### Marionette MCP

Instalado con Dart Pub:

```powershell
& "C:\Users\Perez\AppData\Local\Microsoft\WinGet\Packages\Google.DartSDK_Microsoft.Winget.Source_8wekyb3d8bbwe\dart-sdk\bin\dart.exe" pub global activate marionette_mcp
```

Resultado verificado:

```text
marionette_mcp 0.5.0
```

Registrado en Codex como `marionette`.

Configuracion verificada:

```text
command: C:\Users\Perez\AppData\Local\Microsoft\WinGet\Packages\Google.DartSDK_Microsoft.Winget.Source_8wekyb3d8bbwe\dart-sdk\bin\dart.exe
args: pub global run marionette_mcp
status: enabled
```

Tambien se verifico que responde:

```powershell
& "C:\Users\Perez\AppData\Local\Microsoft\WinGet\Packages\Google.DartSDK_Microsoft.Winget.Source_8wekyb3d8bbwe\dart-sdk\bin\dart.exe" pub global run marionette_mcp --help
```

Validacion pendiente:

- No se valido end-to-end contra una UI Flutter porque este repo todavia no tiene app runnable.
- Cuando exista app Flutter, hay que anadir `marionette_flutter`, inicializar `MarionetteBinding` en debug y conectar al VM service URI.

Fuente:

- https://pub.dev/packages/marionette_mcp
- https://pub.dev/packages/marionette_flutter
- https://github.com/leancodepl/marionette_mcp

## Uso diario recomendado

1. Reiniciar Codex para que detecte las skills y MCP nuevos.

2. Para trabajar la interfaz:

- Usar Flutter official skills para patrones propios de Flutter: layout, theming, state, routing, accessibility y testing.
- Usar `ui-ux-pro-max` para revisar direccion visual, paletas, UX y guidelines Flutter.
- Usar Dart MCP para contexto tecnico de Dart/Flutter.
- Usar Marionette MCP cuando ya exista una app en debug.

3. Cuando toque iniciar Flutter:

```powershell
flutter create .
```

El SDK ya esta instalado y en PATH. Antes de crear la app, revisar si hacen falta los pendientes de `flutter doctor` para el target elegido: Android requiere `cmdline-tools` y licencias; Windows desktop requiere componentes C++ de Visual Studio.

4. Cuando exista la app, preparar Marionette en Flutter:

```powershell
flutter pub add marionette_flutter
```

Ejemplo minimo para `lib/main.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:marionette_flutter/marionette_flutter.dart';

void main() {
  if (kDebugMode) {
    MarionetteBinding.ensureInitialized();
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }

  runApp(const MyApp());
}
```

5. Ejecutar la app y copiar el VM service URI:

```powershell
flutter run
```

El URI debe parecerse a:

```text
ws://127.0.0.1:<puerto>/ws
```

Prompt recomendado:

```text
Conecta Marionette MCP a ws://127.0.0.1:<puerto>/ws, inspecciona los elementos interactivos visibles, toma una screenshot y valida la pantalla actual antes de proponer cambios.
```

## Problemas y limitaciones conocidas

- Flutter SDK esta instalado en `C:\Users\Perez\develop\flutter` y `flutter`/`dart` funcionan desde PATH.
- `flutter doctor` todavia reporta pendientes de Android toolchain: falta `cmdline-tools` y aceptar licencias con `flutter doctor --android-licenses`.
- `flutter doctor` todavia reporta pendientes de Visual Studio para Windows desktop: MSVC C++ build tools, C++ CMake tools y Windows 10 SDK.
- `marionette_mcp.bat` falla si `dart` no esta en PATH. El registro de Codex evita esto usando `dart.exe pub global run marionette_mcp`.
- Marionette requiere una app Flutter en debug y el paquete `marionette_flutter`; no se puede validar contra UI real hasta inicializar la app.
- `MarionetteBinding` debe ser el unico binding inicializado en el proceso; revisar tests que llamen a `main()`.
- Git sigue mostrando `unable to access 'C:\Users\Perez/.config/git/ignore': Permission denied`. Es configuracion local/global, no del repo.
- `npx.cmd skills add flutter/skills --yes` tambien genero carpetas `.claude/` y `.kiro/`; se eliminaron porque este repo se esta preparando para Codex y no se quieren configuraciones extra de otros agentes.
- `skills-lock.json` se conserva porque lo genera el instalador de Flutter skills para registrar origen y hashes de las skills instaladas.

## Fuera de alcance en este paso

- No se ejecuta `flutter create .`.
- No se generan pantallas, widgets ni logica de app.
- No se crea `package.json`.
- No se crean configs de Cursor ni Gemini.
- No se integra `flutter_mcp`/`mcp_flutter`; Marionette + Dart MCP cubren mejor el flujo actual sin sobrecargar el repo.
