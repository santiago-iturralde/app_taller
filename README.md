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
- **Caja**: cobros con recibo numerado (se anulan, no se borran) y gastos por categoría.
- **Reportes (PRO)**: cobrado, gastos, resultado, comparación con el mes anterior, desgloses.
- **Búsqueda** por nombre, teléfono, documento, patente o número.
- **Diseño adaptable**: barra lateral en PC, barra inferior en celular, modo oscuro.

## Arquitectura

```
lib/
  app/        Arranque, sesión, navegación (shell) y datos del producto
  core/       Tema, componentes de UI, formularios, PDF y utilidades
  data/       Modelos, repositorios (acceso a Firestore) y migración
  features/   Una carpeta por sección: inicio, trabajos, clientes, …
```

- Las pantallas **no hablan con Firestore**: usan los repositorios de `data/repositories`
  a través de `Sesion.of(context)`.
- Operaciones que deben ser atómicas (numeración, cobros, anulaciones, convertir presupuesto)
  usan **transacciones**.
- Los cálculos de negocio (saldos, reportes, migración) son **funciones puras con tests**.

### Datos (Firestore)

```
negocios/{negocioId}                   datos del negocio, rubro y plan
negocios/{negocioId}/miembros/{uid}    usuarios con acceso y su rol
negocios/{negocioId}/clientes|ordenes|presupuestos|pagos|gastos
negocios/{negocioId}/meta/contadores   numeración correlativa
negocios/{negocioId}/meta/branding     logo
users/{uid}                            a qué negocio pertenece (+ datos del sistema anterior)
```

### Seguridad

Las reglas están en [`firestore.rules`](firestore.rules) y tienen tests en
[`tools/reglas_test`](tools/reglas_test). Garantizan, entre otras cosas, que:

- cada negocio sólo es visible para sus miembros;
- **el plan PRO no se puede activar desde la app** (sólo desde la consola o un backend);
- los cobros no se borran ni se editan (sólo se anulan) y la numeración no retrocede;
- un trabajo con cobros no se puede eliminar.

## Desarrollo

```bash
flutter pub get
flutter run -d chrome                       # contra el proyecto real
```

Para probar sin tocar datos reales, con los emuladores de Firebase:

```bash
firebase emulators:start --only auth,firestore
flutter run -d chrome --dart-define=EMULADORES=true
```

### Tests

```bash
flutter analyze
flutter test                                # lógica y componentes
cd tools/reglas_test && npm install && npm test   # reglas de seguridad (requiere Java)
```

## Publicar una versión

1. `firebase deploy --only firestore:rules,firestore:indexes`
   (la versión anterior de la app sigue funcionando con estas reglas).
2. `flutter build web --release && firebase deploy --only hosting:app`
3. En la consola de Firestore, `configuracion/app_info` → `version: 4`
   para que las pestañas abiertas con la versión vieja pidan recargar.

Al ingresar, los usuarios del sistema anterior ven una pantalla de
actualización que **copia** sus datos al nuevo formato (no borra nada de
`users/{uid}`). Si tenían plan premium, hay que asignarlo en la consola:
`negocios/{uid}` → `plan: "pro"` (y opcionalmente `planVence`).
