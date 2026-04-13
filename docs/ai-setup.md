# Preparacion Flutter + AI

Fecha de preparacion: 2026-04-13

Este repo queda preparado para trabajar con Flutter + AI, priorizando desarrollo de UI movil. Ya existe una app Flutter base para Android e iOS, sin Firebase, autenticacion ni logica de negocio real.

## Estado actual

- Proyecto Flutter inicializado en la raiz del repo.
- Nombre tecnico Dart: `app_focus_club`.
- Package/bundle base: `es.focusclub.clientes`.
- Plataformas generadas: `android` e `ios`.
- Plataformas no generadas: `web`, `windows`, `macos`, `linux`.
- Flutter SDK: `C:\Users\Perez\develop\flutter`, version `3.41.6`, channel `stable`.
- Dart: `3.11.4`.
- DevTools: `2.54.2`.
- Dependencias runtime: solo Flutter SDK.
- Dependencias dev: `flutter_test` y `flutter_lints`.
- No hay Firebase, Firestore, Storage, autenticacion, Marionette en app ni logica de citas/bonos.

`flutter doctor` corre correctamente y queda con 2 categorias pendientes:

- Android toolchain: falta `cmdline-tools` y aceptar licencias con `flutter doctor --android-licenses`.
- Visual Studio para Windows desktop: faltan MSVC C++ build tools, C++ CMake tools y Windows 10 SDK.

## Comandos ejecutados

Prerequisitos y tooling AI:

```powershell
winget install --id Google.DartSDK -e --accept-package-agreements --accept-source-agreements
winget install --id Python.Python.3.12 -e --accept-package-agreements --accept-source-agreements
npx.cmd skills add flutter/skills --yes
npm.cmd install -g uipro-cli
uipro init --ai codex
codex mcp add dart -- "C:\Users\Perez\AppData\Local\Microsoft\WinGet\Packages\Google.DartSDK_Microsoft.Winget.Source_8wekyb3d8bbwe\dart-sdk\bin\dart.exe" mcp-server --force-roots-fallback
codex mcp add marionette -- "C:\Users\Perez\AppData\Local\Microsoft\WinGet\Packages\Google.DartSDK_Microsoft.Winget.Source_8wekyb3d8bbwe\dart-sdk\bin\dart.exe" pub global run marionette_mcp
```

Inicializacion Flutter:

```powershell
flutter create . --platforms=android,ios --org es.focusclub.clientes --project-name app_focus_club --empty
dart format lib test
flutter pub get
flutter analyze
flutter test
```

Verificacion final:

```text
flutter analyze -> No issues found
flutter test -> All tests passed
```

`flutter pub get` muestra avisos de paquetes transitivos con versiones nuevas incompatibles con constraints actuales (`meta`, `test_api`, `vector_math`), pero no requiere cambios porque no se han anadido dependencias propias.

## Estructura Flutter

```text
lib/
  main.dart
  app/
    app.dart
  features/
    home/
      presentation/
        home_placeholder_screen.dart
  navigation/
    app_router.dart
  shared/
    widgets/
      .gitkeep
  theme/
    app_theme.dart
test/
  app_test.dart
```

Base creada:

- `FocusClubApp` con `MaterialApp`, tema oscuro y router nativo.
- `AppTheme.dark` con fondo oscuro, superficies oscuras, bordes sutiles y acento esmeralda.
- `AppRouter` con ruta inicial `/` hacia `HomePlaceholderScreen`.
- `HomePlaceholderScreen` con el estado "Base Flutter lista" y copy placeholder de producto.
- Test minimo para validar que la pantalla placeholder arranca.

## Skills instaladas

Flutter official skills:

- Instaladas con `npx.cmd skills add flutter/skills --yes`.
- Ubicacion: `.agents/skills/`.
- Resultado verificado: `22` skills instaladas.
- Advertencia: el repo oficial `flutter/skills` indica que sigue en desarrollo; usarlas como apoyo, no como autoridad unica.

UI/UX Pro Max:

- Instalado con `npm.cmd install -g uipro-cli` y `uipro init --ai codex`.
- Ubicacion: `.codex/skills/ui-ux-pro-max/`.
- `uipro --version` devuelve `2.2.3`.
- Verificado con Python 3.12 ejecutando `search.py` sobre el stack Flutter.

Comando util:

```powershell
& "C:\Users\Perez\AppData\Local\Programs\Python\Python312\python.exe" .codex\skills\ui-ux-pro-max\scripts\search.py "mobile app booking dashboard flutter" --stack flutter --design-system --project-name "Focus Club"
```

## MCP configurados

Dart MCP oficial:

```text
name: dart
command: C:\Users\Perez\AppData\Local\Microsoft\WinGet\Packages\Google.DartSDK_Microsoft.Winget.Source_8wekyb3d8bbwe\dart-sdk\bin\dart.exe
args: mcp-server --force-roots-fallback
status: enabled
```

Marionette MCP:

```text
name: marionette
command: C:\Users\Perez\AppData\Local\Microsoft\WinGet\Packages\Google.DartSDK_Microsoft.Winget.Source_8wekyb3d8bbwe\dart-sdk\bin\dart.exe
args: pub global run marionette_mcp
status: enabled
package: marionette_mcp 0.5.0
```

Marionette esta instalado y registrado en Codex, pero no esta integrado dentro de la app. Cuando se decida usarlo para validar UI runtime:

```powershell
flutter pub add marionette_flutter
```

Despues se debe inicializar `MarionetteBinding` solo en debug antes de `runApp` y conectar al VM service URI de `flutter run`.

## Flujo recomendado

Para construir UI:

```powershell
flutter analyze
flutter test
```

Despues, cuando empecemos a validar visualmente en runtime:

```powershell
flutter run
```

Copiar el VM service URI con forma:

```text
ws://127.0.0.1:<puerto>/ws
```

Prompt recomendado para el agente:

```text
Conecta Marionette MCP a ws://127.0.0.1:<puerto>/ws, inspecciona los elementos interactivos visibles, toma una screenshot y valida la pantalla actual antes de proponer cambios.
```

## Limitaciones conocidas

- Android todavia requiere `cmdline-tools` y licencias.
- Windows desktop todavia requiere componentes C++ de Visual Studio si se quiere compilar para Windows.
- Firebase, autenticacion y datos reales estan fuera de alcance por ahora.
- Marionette MCP esta listo como servidor, pero la app no tiene `marionette_flutter` instalado todavia.
- Git sigue mostrando `unable to access 'C:\Users\Perez/.config/git/ignore': Permission denied`; es configuracion local/global, no del repo.
- `skills-lock.json` se conserva porque lo genera el instalador de Flutter skills para registrar origen y hashes.

## Fuera de alcance en este paso

- Integracion Firebase.
- Autenticacion, Firestore, Storage o logica de negocio.
- Pantallas finales completas.
- Dependencias extra de navegacion, estado o Marionette en app.
- Configs de Cursor o Gemini.
