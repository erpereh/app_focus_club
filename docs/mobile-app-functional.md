# Documentacion funcional - App movil clientes

## 1. Resumen de la app

La app movil de clientes es la adaptacion mobile-first del portal de cliente actual de Focus Club Vallecas. Su objetivo es permitir que cada cliente acceda a su cuenta, consulte el estado de su bono, vea sus citas y solicite nuevas sesiones desde el movil.

La app es solo para clientes. No incluye panel de administracion, gestion interna de bonos, gestion de entrenadores, CMS ni configuracion del centro.

Funcionalidades principales:

- Acceso con email y contrasena.
- Acceso con Google.
- Registro de cuenta con verificacion de email.
- Completar perfil tras primer acceso con Google cuando falta el telefono.
- Recuperacion de contrasena por email.
- Consulta del dashboard personal.
- Consulta de bono activo, minutos disponibles y fecha de expiracion.
- Consulta de proxima cita y sesiones realizadas.
- Consulta de citas activas, historial de citas rechazadas e historial de bonos no activos.
- Solicitud de cita usando bono activo.
- Consulta del detalle de una cita.
- Edicion de perfil: nombre, telefono, avatar y nueva contrasena cuando la cuenta usa email/password.

## 2. Flujos de usuario

### Login con email/password

1. El usuario abre la app y ve la pantalla de autenticacion.
2. Introduce email y contrasena.
3. La app autentica con Firebase Auth.
4. Si el email no esta verificado, se bloquea el acceso al portal y se muestra el mensaje de verificacion con opcion de reenviar email.
5. Si el login es correcto y el perfil tiene telefono, la app entra al dashboard.
6. Si Firebase devuelve error, se muestra un mensaje recuperable.

### Registro

1. El usuario cambia a la pestana "Registrarse".
2. Introduce nombre completo, email, telefono, contrasena y confirmacion.
3. Acepta la Politica de Privacidad.
4. La app valida telefono espanol, contrasenas coincidentes y requisitos de contrasena.
5. Firebase Auth crea la cuenta con email/password.
6. Se envia email de verificacion.
7. Se crea el perfil en Firestore con rol `user`.
8. La app cierra la sesion y devuelve al login con mensaje de exito.

### Login con Google

1. El usuario pulsa "Continuar con Google".
2. Firebase Auth abre el flujo de Google.
3. Si ya existe perfil con telefono, la app entra al dashboard.
4. Si es el primer acceso o falta telefono, se crea o carga un perfil parcial y se muestra "Completa tu Perfil".
5. El usuario introduce nombre y telefono.
6. La app valida telefono espanol y actualiza el perfil.
7. Al quedar el perfil completo, la app entra al dashboard.

### Flujo principal tras login

1. La app escucha el estado de autenticacion.
2. Si el usuario esta autenticado, verificado y tiene telefono, carga datos del portal.
3. Se suscribe a las citas del usuario.
4. Se suscribe a los bonos del usuario y calcula el bono activo.
5. Se suscribe a entrenadores activos para mostrar el nombre en citas aprobadas.
6. El dashboard muestra:
   - Datos de perfil.
   - CTA "Reservar Sesion" si hay bono activo con al menos 30 minutos.
   - Aviso si no hay bono activo o no quedan minutos suficientes.
   - Card "Mi Bono".
   - Card "Proxima Cita".
   - Card "Sesiones Realizadas".
   - Lista "Mis Citas".
   - Historial de citas y bonos.

### Creacion de cita

1. Desde el dashboard, el usuario pulsa "Reservar Sesion".
2. La app abre el flujo de reserva.
3. El usuario elige duracion: 30, 45 o 60 minutos.
4. La app deshabilita duraciones que superan los minutos disponibles del bono activo.
5. El usuario selecciona una fecha y franja horaria en el calendario.
6. La app impide seleccionar franjas pasadas, bloqueadas, completas o ya reservadas por ese usuario.
7. El usuario puede anadir un comentario opcional.
8. El boton "Enviar Solicitud" se habilita solo cuando hay una franja seleccionada.
9. Antes de crear la cita, la app vuelve a comprobar el bono activo y los minutos disponibles.
10. La app crea una cita en Firestore con estado `pending`.
11. La app muestra confirmacion: "Solicitud Enviada".
12. La app refresca las citas y cierra el flujo de reserva.

### Gestion de citas

1. El dashboard lista como "Mis Citas" las citas en estado `pending` o `approved`.
2. El historial de citas muestra las citas `rejected`.
3. El usuario puede abrir el detalle de cualquier cita visible.
4. En el detalle se muestran estado, servicio, duracion, franja propuesta, datos de confirmacion si la cita esta aprobada, comentario del cliente y fecha de solicitud.
5. El usuario no puede aprobar, rechazar, editar ni eliminar citas desde la app cliente.

### Perfil

1. El usuario abre "Mi Perfil" desde el avatar del dashboard.
2. Puede cambiar nombre visible y telefono.
3. Puede subir o eliminar avatar.
4. Si la cuenta usa email/password, puede establecer una nueva contrasena.
5. La app valida telefono espanol y requisitos de contrasena cuando aplica.
6. Se actualiza el perfil en Firestore y, si procede, el avatar en Firebase Storage.

## 3. Pantallas funcionales

### Login / Registro

- Objetivo: autenticar o crear una cuenta de cliente.
- Acciones del usuario: introducir credenciales, cambiar entre login y registro, iniciar con Google, solicitar recuperacion de contrasena, reenviar email de verificacion cuando aplica.
- Datos que usa: email, contrasena, nombre, telefono, confirmacion de contrasena, aceptacion de privacidad, estado de verificacion de Firebase Auth.
- Operaciones:
  - Leer estado de Auth.
  - Crear usuario en Auth.
  - Crear perfil en `users`.
  - Leer perfil de `users`.
  - Enviar email de verificacion.
  - Reenviar email de verificacion.

### Recuperar contrasena

- Objetivo: enviar un enlace de recuperacion al email del cliente.
- Acciones del usuario: introducir email y enviar solicitud.
- Datos que usa: email.
- Operaciones:
  - Enviar email de reset password con Firebase Auth.

### Completar perfil Google

- Objetivo: completar los datos minimos cuando el acceso con Google no tiene telefono.
- Acciones del usuario: introducir nombre y telefono.
- Datos que usa: perfil parcial de Firebase/Firestore, telefono introducido.
- Operaciones:
  - Leer perfil de `users`.
  - Actualizar `name` y `phone` en `users`.

### Dashboard

- Objetivo: mostrar el estado actual del cliente y dar acceso a la reserva.
- Acciones del usuario: abrir perfil, reservar sesion, abrir detalle de cita, cambiar tab de historial, cerrar sesion.
- Datos que usa: `userProfile`, citas del usuario, bonos del usuario, entrenadores activos.
- Operaciones:
  - Leer/suscribirse a `appointments` filtrado por `userId`.
  - Leer/suscribirse a `bonos` filtrado por `userId`.
  - Leer/suscribirse a `trainers` activos.
  - Calcular bono activo, proxima cita y minutos usados.

### Reservar sesion

- Objetivo: crear una solicitud de cita pendiente.
- Acciones del usuario: elegir duracion, seleccionar fecha/franja, escribir comentario opcional, enviar solicitud o cancelar.
- Datos que usa: bono activo, minutos restantes, configuracion horaria, ocupacion de franjas, franjas bloqueadas, citas activas del usuario.
- Operaciones:
  - Leer bono activo de `bonos`.
  - Leer/suscribirse a `site_config`.
  - Leer/suscribirse a `slot_occupancy` del mes visible.
  - Leer/suscribirse a `blocked_slots` del mes visible.
  - Crear documento en `appointments` con estado `pending`.

### Detalle de cita

- Objetivo: mostrar la informacion completa de una cita del cliente.
- Acciones del usuario: revisar datos y volver al dashboard.
- Datos que usa: cita seleccionada, estado, duracion, franja propuesta, franja aprobada, entrenador asignado, tipo de sesion, comentario y fecha de solicitud.
- Operaciones:
  - Leer datos ya cargados desde `appointments`.
  - Leer nombre de entrenador desde `trainers` activos cuando existe `assignedTrainer`.

### Mi perfil

- Objetivo: permitir al cliente actualizar datos de perfil existentes.
- Acciones del usuario: cambiar nombre, telefono, avatar, eliminar avatar y cambiar contrasena si aplica.
- Datos que usa: `userProfile`, proveedor de autenticacion, archivo de imagen seleccionado.
- Operaciones:
  - Actualizar `users/{uid}` con `name`, `phone` y `photoURL`.
  - Subir avatar a `user-avatars/{uid}/...`.
  - Eliminar avatar anterior cuando aplica.
  - Actualizar contrasena en Firebase Auth para cuentas email/password.

## 4. Estados y edge cases

- Sin bono activo: mostrar aviso y no mostrar CTA de reserva.
- Bono activo con menos de 30 minutos: mostrar aviso de minutos no disponibles y no permitir reservar.
- Sin citas activas: mostrar estado vacio "Sin citas activas".
- Sin citas proximas: mostrar "Sin citas proximas" en la card correspondiente.
- Sin historial de citas: mostrar "Sin historial de citas".
- Sin historial de bonos: mostrar "Sin historial de bonos".
- Loading de autenticacion: mantener estado de carga hasta resolver Firebase Auth.
- Loading de bono: mostrar spinner/texto "Cargando...".
- Loading de disponibilidad: mostrar "Cargando disponibilidad..." en calendario.
- Error de red o Firebase: mostrar mensaje recuperable y mantener la pantalla actual cuando sea posible.
- Sesion expirada o usuario no autenticado: volver al flujo de autenticacion.
- Email no verificado: bloquear dashboard y ofrecer reenvio de email de verificacion.
- Telefono invalido: mostrar error de telefono espanol valido.
- Contrasena invalida: exigir al menos 8 caracteres, una letra y un numero.
- Confirmacion de contrasena distinta: bloquear registro.
- Privacidad no aceptada: bloquear registro.
- Franja no seleccionada: deshabilitar "Enviar Solicitud".
- Franja pasada: deshabilitar.
- Franja bloqueada por admin: deshabilitar.
- Franja completa: no permitir seleccion y mostrar mensaje.
- Franja parcialmente ocupada: permitir seleccion y mostrar indicador "1 plaza".
- Franja ya reservada por el usuario: deshabilitar y mostrar "Tu sesion".
- Duracion mayor que minutos disponibles: deshabilitar esa duracion.
- Cita aprobada sin algunos campos opcionales: mostrar solo los datos disponibles.

## 5. Modelo de datos de alto nivel

### Usuarios (`users`)

- `uid`: identificador de Firebase Auth.
- `email`: email del cliente.
- `name`: nombre visible.
- `phone`: telefono normalizado.
- `role`: para clientes debe ser `user`.
- `isTrainer`: falso en clientes.
- `photoURL`: avatar opcional.
- `createdAt`: fecha de creacion.

### Citas (`appointments`)

- `id`: identificador del documento.
- `userId`: referencia logica al usuario.
- `name`, `email`, `phone`: datos del cliente copiados al crear la cita.
- `serviceType`: en el portal cliente se deriva del bono activo como "Bono Mensual de Entrenamiento".
- `duration`: `30`, `45` o `60`.
- `preferredSlots`: lista con una franja solicitada.
- `reason`: comentario opcional.
- `status`: `pending`, `approved` o `rejected`.
- `approvedSlot`: franja confirmada, si aplica.
- `assignedTrainer`: entrenador asignado, si aplica.
- `sessionType`: tipo de sesion informado por admin, si aplica.
- `trainerNotes`: notas internas del entrenador, no forman parte de la gestion cliente.
- `createdAt` y `updatedAt`: fechas de creacion y actualizacion.

### Bonos (`bonos`)

- `id`: identificador del documento.
- `userId`: referencia logica al usuario.
- `tamano`: tamano del bono en minutos, por ejemplo 240, 360 o 480.
- `minutosTotales`: minutos totales.
- `minutosRestantes`: minutos disponibles.
- `fechaAsignacion`: fecha de asignacion.
- `fechaExpiracion`: fecha de expiracion.
- `estado`: `activo`, `agotado`, `expirado` o `eliminado`.
- `historial`: movimientos asociados a sesiones o ajustes.
- `asignadoPor`: email del admin que asigno el bono.
- `createdAt`: fecha de creacion.

### Relaciones

- Un usuario tiene muchas citas.
- Un usuario puede tener muchos bonos, pero el dashboard usa el bono con estado activo.
- Una cita puede referenciar un entrenador asignado.
- El consumo de bono ocurre desde la gestion admin existente, no desde la app cliente.

## 6. Integracion con Firebase

### Firebase Auth

- Login con email/password.
- Registro con email/password.
- Login con Google.
- Verificacion de email.
- Reenvio de email de verificacion.
- Recuperacion de contrasena.
- Logout.
- Cambio de contrasena para cuentas email/password desde perfil.

### Firestore

- `users`: perfil del cliente.
- `appointments`: citas creadas y consultadas por el cliente.
- `bonos`: bono activo e historial de bonos del cliente.
- `trainers`: lectura de entrenadores activos para mostrar datos de citas confirmadas.
- `slot_occupancy`: disponibilidad por franja.
- `blocked_slots`: franjas bloqueadas por admin.
- `site_config`: horas de inicio/fin e intervalo de slots.

### Firebase Storage

- `user-avatars/{uid}/...`: subida, lectura y eliminacion de avatar del propio usuario.
- No se incluye gestion de medios publicos ni libreria de medios en la app cliente.
