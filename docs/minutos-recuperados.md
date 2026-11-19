# Capacidad efectiva y minutos recuperados

Entrega local de la app `1.5.2+22`, coordinada con `web_focus_club`. No se ha publicado la app ni activado la compensación.

`Bono` conserva `tamano` como tamaño contratado y lee los campos aditivos `minutosCapacidadBase` y `minutosExtraRecuperados`. El total efectivo coincide con `minutosTotales` del backend. Las tarjetas, el progreso y los saldos usan esa capacidad, preservando las ampliaciones legacy que ya reconocía la web.

Ejemplo: 240 contratados + 60 recuperados permite mostrar 300, 240, 180 o 0 disponibles sobre un total de 300. El historial da prioridad a `minutosAbonados` cuando existe, de modo que un intento auditado con 0 abonados no aparece como una devolución de 60.

Las reglas económicas, la selección de bono y la idempotencia pertenecen a las Functions compartidas de la web. La app no escribe saldos ni calcula devoluciones. No cambian los contratos de las callables utilizadas por Android e iOS.

Validación: `flutter analyze --no-pub` y `flutter test --no-pub`. La cobertura nueva está en `test/recovered_minutes_test.dart`; se actualizan los casos legacy para que móvil y web utilicen el mismo total efectivo.

La activación exige publicar Android e iOS, verificar la versión mínima obligatoria y entonces activar manualmente `site_config/main.automaticMinuteRefundsEnabled`. El runbook completo y la auditoría de los dos históricos están en `web_focus_club/docs/despliegue-integrado-aforo-devoluciones.md`. Los históricos siguen requiriendo revisión expresa de su informe.

Compilación Android: `flutter build appbundle --release`. En macOS, con firma configurada: `flutter build ipa --release`. Comprobar antes que el build 22 no esté ocupado por otro lanzamiento; si lo está, incrementar el número y exigir el publicado en ambos mínimos. Publicar únicamente `functions:portal:deleteOwnAccount` desde este repositorio, en el paso indicado por el procedimiento integrado. Las reglas y las demás Functions pertenecen al repositorio web.

Las citas pendientes y aprobadas ocupan plaza desde la creación. Los cambios de horario descuentan la plaza propia en ambos estados y conservan los bloques compartidos. La pantalla de mantenimiento sigue la configuración en vivo; el bloqueo efectivo de escrituras lo impone el servidor, también para versiones antiguas.
