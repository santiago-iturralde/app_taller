# WorkControl

Sistema de gestión para talleres y negocios de servicios: trabajos, clientes,
presupuestos, cobros, gastos y reportes. Multiplataforma (web, Android, iOS)
con Flutter + Firebase.

Se adapta al **rubro** de cada negocio (reparación de herramientas, lubricentro,
taller mecánico, motos, celulares, PC, electrodomésticos u otro): cambian los
nombres, los campos (patente, kilometraje, N° de serie…) y los valores por
defecto, pero el motor es el mismo para todos.

## Funcionalidades

- **Inicio**: trabajos en curso, listos para retirar, saldo por cobrar y lo cobrado en el mes.
- **Trabajos (órdenes)**: numeración correlativa, estados (recibido → en proceso → listo → entregado),
  ítems con total, señas y cobros parciales, orden de trabajo en PDF, aviso por WhatsApp.
- **Clientes**: ficha con historial, saldo y contacto directo.
- **Presupuestos**: PDF, envío por WhatsApp, validez y conversión en trabajo con un clic.
- **Productos y servicios**: catálogo con precio, costo y margen; stock que se descuenta solo al usarlo
  en trabajos, presupuestos aprobados o ventas (y vuelve si se cancela o anula), con historial de movimientos
  y aviso de stock bajo.
- **Venta de mostrador**: vender sin abrir un trabajo; descuenta stock y genera recibo.
- **Recordatorios de service**: próximo service por fecha o kilometraje; el inicio muestra a quién avisar
  y se envía por WhatsApp con un toque.
- **Caja**: cobros con recibo numerado (se anulan, no se borran) y gastos por categoría.
- **Reportes (PRO)**: cobrado, gastos, resultado, comparación con el mes anterior, desgloses,
  lo más vendido, ganancia bruta y margen por producto, inventario valorizado.
- **Equipo (PRO)**: el dueño invita por email a administradores y empleados, con permisos por rol.
- **Facturación electrónica ARCA (Básico/PRO)**: facturas A, B y C y notas de crédito desde cada trabajo
  o venta, con CAE, código QR y PDF; configuración guiada del certificado.
- **Planes**: Gratis, Básico y PRO, prueba gratis para negocios nuevos y aviso de vencimiento.
- **Panel de administración** (sólo para el dueño de la plataforma): negocios, planes, vencimientos,
  cobros registrados y auditoría de cada cambio.
- **Búsqueda** por nombre, teléfono, documento, patente o número.
- **Diseño adaptable**: barra lateral en PC, barra inferior en celular; tema azul noche (oscuro),
  claro o según el sistema.

## Arquitectura

```
lib/          App Flutter
  app/        Arranque, sesión, navegación (shell) y datos del producto
  core/       Tema, componentes de UI, formularios, PDF y utilidades
  data/       Modelos, repositorios (acceso a Firestore) y migración
  features/   Una carpeta por sección: inicio, trabajos, clientes, …
functions/    Backend (Cloud Functions, TypeScript)
  src/arca/   Facturación electrónica: WSAA, WSFEv1, certificados, QR
  src/handlers/  Funciones que llama la app (ARCA y administración)
tools/        Tests de reglas y script de administrador
docs/         Guía de publicación
```

### Facturación ARCA (backend)

- La clave privada de cada negocio se **genera en el servidor** y se guarda cifrada (AES-256-GCM)
  con una clave maestra en Secret Manager. Nunca viaja a la app.
- Los importes salen del trabajo o cobro guardado, no de lo que envía la app.
- Una transacción reserva el trabajo/cobro antes de pedir el CAE: no se puede facturar dos veces.
- Un bloqueo por punto de venta y tipo evita que dos facturas pidan el mismo número.
- Si ARCA no responde después de enviar el pedido, la factura queda "sin confirmar" y al reintentar
  se consulta a ARCA antes de volver a pedir (nunca se duplica).
- Anular = nota de crédito (ARCA no permite borrar comprobantes).

- Las pantallas **no hablan con Firestore**: usan los repositorios de `data/repositories`
  a través de `Sesion.of(context)`.
- Operaciones que deben ser atómicas (numeración, cobros, anulaciones, convertir presupuesto)
  usan **transacciones**.
- Los cálculos de negocio (saldos, reportes, migración) son **funciones puras con tests**.

### Datos (Firestore)

```
negocios/{negocioId}                   datos del negocio, rubro y plan
negocios/{negocioId}/miembros/{uid}    usuarios con acceso y su rol
negocios/{negocioId}/clientes|ordenes|presupuestos|pagos|gastos|productos
negocios/{negocioId}/movimientosStock  historial de stock (sólo se agregan registros)
negocios/{negocioId}/meta/contadores   numeración correlativa
negocios/{negocioId}/meta/branding     logo
users/{uid}                            a qué negocio pertenece (+ datos del sistema anterior)
```

### Roles

| | Dueño | Administrador | Empleado |
|---|:-:|:-:|:-:|
| Clientes, trabajos, presupuestos, ventas y cobros | ✓ | ✓ | ✓ |
| Ver gastos, reportes y totales de caja | ✓ | ✓ | |
| Borrar registros, anular cobros | ✓ | ✓ | |
| Editar catálogo, precios y ajustar stock | ✓ | ✓ | |
| Configuración del negocio | ✓ | ✓ | |
| Invitar / quitar empleados | ✓ | ✓ | |
| Invitar administradores y cambiar roles | ✓ | | |

Las invitaciones viven en `invitaciones/{negocioId}_{email}`, vencen a los 7 días y sólo las puede
aceptar quien **verificó ese email**.

### Seguridad

Las reglas están en [`firestore.rules`](firestore.rules) y tienen tests en
[`tools/reglas_test`](tools/reglas_test). Garantizan, entre otras cosas, que:

- cada negocio sólo es visible para sus miembros;
- **el plan PRO no se puede activar desde la app** (sólo desde la consola o un backend);
- los cobros no se borran ni se editan (sólo se anulan) y la numeración no retrocede;
- un trabajo con cobros no se puede eliminar;
- los permisos de cada rol (tabla de arriba) se validan en el servidor, no sólo en la app;
- cada movimiento de stock queda firmado por el usuario que lo hizo.

## Desarrollo

```bash
flutter pub get
flutter run -d chrome                       # contra el proyecto real
```

Para probar sin tocar datos reales, con los emuladores de Firebase:

```bash
firebase emulators:start --only "auth,firestore"     # en PowerShell, con comillas
flutter run -d chrome --dart-define=EMULADORES=true
```

### Tests

```bash
flutter analyze
flutter test                                # lógica y componentes
cd tools/reglas_test && npm install && npm test   # reglas de seguridad (requiere Java; usa el puerto 8181)
cd functions && npm test                          # backend: ARCA, cifrado, planes
cd functions && npm run e2e                       # backend de punta a punta en emuladores aislados
```

## Publicar una versión

Ver la guía paso a paso: [docs/PUBLICAR.md](docs/PUBLICAR.md).
