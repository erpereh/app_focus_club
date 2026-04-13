# Documentacion UI - App movil clientes para Stitch

## 1. Resumen de diseno

La app movil debe adaptar el portal web actual de cliente a una experiencia mobile-first. No debe redisenarse desde cero ni introducir nuevas funcionalidades. La referencia visual es el portal existente: interfaz oscura, tarjetas tipo glass, bordes sutiles, acento verde esmeralda y CTAs con gradiente.

Principios visuales:

- Fondo base oscuro cercano a negro.
- Superficies tipo glass con transparencia ligera y blur.
- Acento principal verde esmeralda para CTAs, iconos importantes, estados activos y progreso.
- Texto principal claro y texto secundario con baja opacidad.
- Bordes finos y sutiles.
- Cards compactas, legibles y apiladas en mobile.
- Animaciones suaves solo como apoyo: transiciones de entrada, cambio de estado y feedback de botones.
- Una accion principal clara por pantalla.

## 2. Adaptacion web a mobile

### Dashboard

En desktop el portal usa una cabecera con perfil/CTA, tres cards resumen y una distribucion de dos columnas para citas e historial. En mobile debe reorganizarse como una unica columna vertical:

1. Header compacto.
2. Bloque de perfil con avatar, nombre y email.
3. CTA "Reservar Sesion" cuando el bono permite reservar.
4. Aviso de bono si no hay minutos disponibles.
5. Card "Mi Bono".
6. Card "Proxima Cita".
7. Card "Sesiones Realizadas".
8. Seccion "Mis Citas".
9. Historial con tabs "Historial Citas" y "Historial Bonos".

### Cards

Las cards existentes se mantienen como unidades visuales, pero se convierten a ancho completo. Deben conservar:

- Fondo glass oscuro.
- Borde sutil.
- Icono pequeno en verde.
- Titulo corto en mayusculas o estilo de etiqueta.
- Dato principal con mas peso visual.
- Texto secundario breve.
- Badges de estado cuando aplica.

### Simplificacion UI

- Evitar columnas paralelas en mobile.
- Evitar mostrar demasiados datos secundarios al primer nivel.
- Priorizar CTA, bono y proxima cita.
- Mover detalle extenso a pantallas stack o paneles dedicados.
- Adaptar drawers laterales de desktop a pantalla completa mobile o bottom sheet alto.
- Mantener el calendario usable con targets tactiles claros.

## 3. Lista de pantallas UI

### Login / Registro

Estructura visual:

- Pantalla centrada verticalmente.
- Card principal glass.
- Icono superior en bloque con gradiente verde.
- Titulo "Portal del Cliente".
- Subtitulo "Focus Club Vallecas".
- Tabs "Iniciar Sesion" y "Registrarse".
- Formulario segun modo.
- CTA principal.
- Separador "o".
- Boton "Continuar con Google".
- Enlace secundario "Volver al inicio".

Jerarquia:

1. Icono y titulo.
2. Selector login/registro.
3. Inputs.
4. Mensajes de error/exito.
5. CTA principal.
6. Google.
7. Navegacion secundaria.

Componentes visibles:

- Input email.
- Input contrasena con mostrar/ocultar en login.
- Inputs nombre, telefono, contrasena y confirmar contrasena en registro.
- Checkbox de Politica de Privacidad.
- Boton "Entrar" o "Crear Cuenta".
- Boton Google.
- Enlace "Has olvidado tu contrasena?".
- Mensaje de email no verificado con accion "Reenviar email de verificacion".

### Recuperar contrasena

Estructura visual:

- Misma card de autenticacion.
- Icono de llave.
- Titulo "Recuperar Contrasena".
- Texto de ayuda.
- Input email.
- CTA "Enviar enlace".
- Boton/enlace "Volver al inicio de sesion".

Componentes visibles:

- Input email.
- Mensaje de exito o error.
- Boton principal.
- Navegacion secundaria.

### Completar perfil Google

Estructura visual:

- Card glass de autenticacion.
- Icono de usuario.
- Titulo "Completa tu Perfil".
- Texto "Necesitamos algunos datos mas".
- Inputs de nombre y telefono.
- CTA "Guardar y Continuar".

Componentes visibles:

- Input nombre.
- Input telefono.
- Mensaje de error.
- Boton principal.

### Dashboard

Estructura visual:

- Header compacto fijo o sticky con logo, accion "Ver web" si se conserva en mobile y accion "Salir".
- Contenido con padding lateral reducido.
- Bloque superior de perfil: avatar, nombre, email y acceso a ajustes.
- CTA "Reservar Sesion" alineado bajo el perfil o como boton full width.
- Aviso amber cuando no hay minutos disponibles.
- Cards resumen apiladas.
- Lista de citas activas.
- Historial con tabs.

Jerarquia:

1. Perfil del cliente.
2. CTA principal.
3. Estado del bono.
4. Proxima cita.
5. Sesiones realizadas.
6. Citas activas.
7. Historial.

Componentes visibles:

- Avatar circular con inicial o imagen.
- Boton "Reservar Sesion".
- Aviso "No tienes minutos disponibles...".
- Card "Mi Bono" con barra de progreso y fecha de validez.
- Card "Proxima Cita" con fecha, hora y badge.
- Card "Sesiones Realizadas".
- Cards de cita activa con servicio, fecha/hora y badge.
- Tabs "Historial Citas" / "Historial Bonos".
- Cards pequenas de historial.

### Reservar sesion

Estructura visual:

- Pantalla stack o bottom sheet de altura completa.
- Header interno con titulo "Reservar Sesion" y cerrar.
- Contenido en pasos verticales.
- Acciones finales "Cancelar" y "Enviar Solicitud".

Jerarquia:

1. Titulo del flujo.
2. Paso 1: duracion de la sesion.
3. Paso 2: franja horaria.
4. Paso 3: comentario opcional.
5. CTA de envio.

Componentes visibles:

- Selector de duracion: 30 minutos, 45 minutos, 60 minutos.
- Texto de minutos disponibles del bono.
- Calendario mensual.
- Leyenda: Disponible, Casi lleno, Completo.
- Selector de horas.
- Estado de franja seleccionada.
- Textarea de comentario.
- Boton "Cancelar".
- Boton "Enviar Solicitud".
- Estado de exito "Solicitud Enviada".

### Detalle de cita

Estructura visual:

- Pantalla stack con boton "Volver a mis citas".
- Card principal glass.
- Header con titulo "Detalle de la Cita" y badge de estado.
- Bloques informativos apilados.

Jerarquia:

1. Navegacion atras.
2. Estado actual.
3. Servicio y duracion.
4. Franja propuesta.
5. Datos de cita confirmada si aplica.
6. Comentario del cliente si existe.
7. Metadatos: id corto y fecha de solicitud.

Componentes visibles:

- Badge Pendiente, Aprobada o Rechazada.
- Mensaje descriptivo de estado.
- Card de servicio.
- Card de duracion.
- Lista de franja propuesta.
- Bloque "Cita confirmada" cuando `status` es `approved` y hay datos de confirmacion.
- Bloque "Tu comentario" cuando existe comentario.
- Fecha de solicitud.

### Mi perfil

Estructura visual:

- Pantalla stack o bottom sheet de altura completa.
- Header con titulo "Mi Perfil" y cerrar.
- Avatar centrado.
- Formulario simple.
- CTA "Guardar cambios".

Jerarquia:

1. Avatar.
2. Accion de subir/cambiar foto.
3. Accion de eliminar foto si hay avatar.
4. Nombre visible.
5. Telefono.
6. Nueva contrasena solo para email/password.
7. Mensajes de error/exito.
8. Guardar cambios.

Componentes visibles:

- Avatar con imagen o inicial.
- Boton icono de camara.
- Boton "Eliminar foto".
- Input nombre visible.
- Input telefono.
- Input nueva contrasena si aplica.
- Mensaje de perfil actualizado.
- Boton "Guardar cambios".

## 4. Componentes reutilizables

### Botones

- Primario/CTA: "Reservar Sesion", "Enviar Solicitud", "Entrar", "Crear Cuenta", "Guardar cambios".
- Secundario/ghost: "Cancelar", "Volver", "Salir", "Volver al inicio".
- Google: boton full width con icono Google y texto "Continuar con Google".
- Icon button: cerrar, cambiar foto, mostrar/ocultar contrasena, navegar meses.

Reglas:

- CTA con gradiente verde.
- Radio pequeno/medio coherente con el portal.
- Estado loading con spinner.
- Estado disabled con opacidad reducida.

### Inputs

- Email.
- Contrasena.
- Nombre.
- Telefono.
- Confirmar contrasena.
- Nueva contrasena.
- Textarea de comentario.

Reglas:

- Fondo oscuro tipo input.
- Borde sutil.
- Focus con borde/acento verde.
- Labels pequenos con icono cuando ya existe en el portal.
- Mensajes de validacion debajo o cerca del campo relacionado.

### Cards

- Card de bono.
- Card de proxima cita.
- Card de sesiones realizadas.
- Card de cita activa.
- Card de historial de bono.
- Card de paso en reserva.
- Card de detalle.

Reglas:

- Fondo glass.
- Borde fino.
- Padding mobile contenido.
- Icono pequeno en acento.
- Dato principal destacado.

### Badges de estado

- Pendiente: amarillo/ambar.
- Aprobada o confirmada: verde/acento.
- Rechazada: rojo.
- Activo: verde/acento.
- Agotado: ambar.
- Expirado: neutro/muted.
- Eliminado: rojo.

### Loaders y mensajes

- Spinner pequeno para auth, bono y calendario.
- Mensajes inline para error y exito.
- Aviso ambar para falta de bono/minutos.
- Confirmacion de exito con check en circulo verde.

### Calendario y franjas

Estados visuales:

- Disponible: borde/acento verde suave.
- Casi lleno: indicador ambar.
- Completo: rojo.
- Bloqueado: muted/deshabilitado con icono de lock.
- Tu sesion: azul suave y texto "Tu sesion".
- Elegida: borde/acento verde, ring y texto "Elegida".
- Pasado: opacidad reducida y disabled.

## 5. Navegacion

Estructura mobile:

- Stack principal:
  - Auth.
  - Dashboard.
  - Detalle de cita.
  - Reservar sesion.
  - Mi perfil.
- Tabs internos:
  - Login / Registro.
  - Historial Citas / Historial Bonos.

CTA principal:

- "Reservar Sesion" aparece en Dashboard solo si hay bono activo y al menos 30 minutos disponibles.
- En mobile debe poder mostrarse como boton full width bajo el perfil para facilitar uso tactil.

Flujo de navegacion:

1. Auth lleva a Dashboard cuando el usuario esta verificado y tiene telefono.
2. Dashboard abre Reserva desde el CTA.
3. Dashboard abre Detalle desde una card de cita.
4. Dashboard abre Perfil desde el avatar.
5. Reserva vuelve a Dashboard al cancelar o tras enviar solicitud.
6. Detalle vuelve a Dashboard con "Volver a mis citas".
7. Perfil vuelve a Dashboard al cerrar.

## 6. Estados visuales

### Loading

- Usar spinner pequeno y texto corto.
- Ejemplos:
  - "Cargando..."
  - "Cargando disponibilidad..."
- Mantener estructura estable mientras cargan bono o calendario.

### Vacio

- Usar icono tenue, titulo corto y descripcion breve.
- Casos:
  - Sin citas activas.
  - Sin citas proximas.
  - Sin historial de citas.
  - Sin historial de bonos.
  - Sin bono activo.

### Error

- Errores de auth y validacion: texto rojo con icono de alerta.
- Falta de bono/minutos: alerta ambar.
- Error de Firebase/red: mensaje recuperable, sin introducir acciones nuevas no existentes.

### Exito

- Registro: mensaje indicando que se revise el email de verificacion.
- Recuperacion: mensaje de email enviado.
- Reserva: pantalla de confirmacion con check y texto "Solicitud Enviada".
- Perfil: mensaje "Perfil actualizado correctamente.".

## 7. Reglas UX/UI

- La app debe ser mobile-first.
- No incluir panel admin ni accesos administrativos.
- No incluir pagos, chat, notificaciones push, compra de bonos, QR, rutinas, metricas nuevas ni gestion avanzada de bonos.
- No inventar nuevos estados de cita fuera de `pending`, `approved` y `rejected`.
- No inventar nuevos tipos de bono ni nuevas operaciones sobre bonos.
- Mantener el foco en la accion principal: consultar estado y reservar sesion.
- Priorizar legibilidad y targets tactiles.
- Evitar columnas en mobile.
- Evitar contenido promocional o de landing dentro de la app cliente.
- Mantener coherencia visual con el portal: dark UI, glass cards, acento verde, bordes sutiles y CTAs con gradiente.
- Usar textos concretos y funcionales, sin explicar la interfaz dentro de la propia UI.
