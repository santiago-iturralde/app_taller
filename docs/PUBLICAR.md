# Publicar WorkControl (guía paso a paso)

Esta guía publica la versión nueva sin cortar el servicio de quienes ya lo usan.
Seguila en orden. Los comandos son para **PowerShell**, desde la carpeta del proyecto.

> Antes de empezar: `firebase login` y verificá que el proyecto activo sea el correcto
> con `firebase use` (debe decir `taller-reparaciones-8cf11`).

Hay dos partes:

- **Parte A — el sistema** (funciona con el plan gratuito Spark de Firebase): reglas,
  app web, panel de administración y planes.
- **Parte B — facturación electrónica ARCA**: necesita un servidor, que corre gratis en
  Render.

---

# Parte A — El sistema

## A0. Revisar los datos comerciales

En [`lib/app/app_info.dart`](../lib/app/app_info.dart):

- `whatsappVentas`: tu número en formato internacional sin `+`: `549` + característica + número
  (ej. `5492284203790`). Es a donde llegan los pedidos de "Renovar" y "Quiero el plan".
- `precioBasico` / `precioPro`: los precios que se muestran en la pantalla de planes.
- `diasPrueba`: días de prueba gratis del PRO para negocios nuevos (máximo 16).
- `facturacionDisponible`: dejalo en `false` hasta hacer la Parte B.

## A1. Reglas de seguridad e índices

```powershell
firebase deploy --only firestore:rules,firestore:indexes
```

La versión anterior de la app sigue funcionando con estas reglas. Los índices pueden
tardar unos minutos en construirse (la consola muestra el progreso).

## A2. App web

```powershell
flutter test      # todos deben pasar
flutter build web --release
firebase deploy --only hosting:app
```

## A3. Avisar a las pestañas abiertas que hay versión nueva

Consola → Firestore → colección `configuracion` → documento `app_info` → campo
`version` = **4** (número). Quien tenga la app abierta verá "Hay una nueva versión" y
recargará.

## A4. Tu permiso de administrador de la plataforma

1. Consola → ⚙️ Configuración del proyecto → **Cuentas de servicio** →
   **Generar nueva clave privada**. Guardá el JSON **fuera del proyecto**
   (por ejemplo en Documentos) y nunca lo compartas ni lo subas a git.
2. Ejecutá:

```powershell
cd tools/admin
npm ci
$env:GOOGLE_APPLICATION_CREDENTIALS="C:\Users\ACER\Documents\clave-workcontrol.json"
node superadmin.js TU_EMAIL
```

3. Cerrá sesión en la app y volvé a entrar: vas a ver **Administración** en el menú.
4. Cuando termines, borrá el archivo JSON (podés generar otro cuando lo necesites).

## A5. Migrar a tu papá y activar su plan

1. Tu papá entra con su cuenta de siempre: ve "Estamos actualizando tu sistema" y sus
   datos se copian al formato nuevo (los originales no se borran).
2. Desde **Administración** → su negocio → **Activar plan** (PRO, los meses que quieras).

Cada cambio de plan queda registrado (quién, cuándo, cuánto cobraste). Las reglas
rechazan cualquier cambio de plan que no venga del administrador con su registro.

---

# Parte B — Facturación electrónica ARCA

La facturación necesita un servidor propio (la clave del certificado fiscal no puede
estar en la app, y el navegador no puede hablar directo con ARCA). El servidor está en
`functions/` y corre de dos formas, con el mismo código:

- **Render (gratis)** — lo que usamos: `functions/src/servidor.ts`, configurado en
  [`render.yaml`](../render.yaml).
- **Cloud Functions** (plan Blaze de Firebase) — alternativa: `functions/src/index.ts`.

## B1. Clave maestra de cifrado

Con esta clave se cifran las claves privadas de ARCA de cada negocio.

```powershell
$b = New-Object byte[] 32; [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($b); [Convert]::ToBase64String($b)
```

**Guardala en un lugar seguro** (gestor de contraseñas). No va en el código ni en git.
Si se pierde, cada negocio tiene que volver a generar su certificado de ARCA.

## B2. Cuenta de servicio de Firebase

El servidor la usa para leer y escribir en Firestore y verificar las sesiones.
Consola de Firebase → ⚙️ → **Cuentas de servicio** → **Generar nueva clave privada**.
Se descarga un `.json`: su contenido va en Render (paso B3) y después **borrás el archivo**.

## B3. Crear el servicio en Render

1. El código tiene que estar en GitHub (recomendado: repositorio **privado**).
2. Render → **New** → **Blueprint** → elegir el repositorio. Render lee `render.yaml`.
3. Te pide dos valores secretos:
   - `ARCA_CLAVE_MAESTRA`: la clave del paso B1.
   - `FIREBASE_SERVICE_ACCOUNT`: el **contenido completo** del `.json` del paso B2.
4. **Apply**. Cuando termine, `https://workcontrol-arca.onrender.com/salud` responde
   `{"ok":true}`. Si Render le dio otra dirección, actualizá `AppInfo.urlServidor`.

El plan gratuito duerme el servidor tras 15 minutos sin uso: la app lo despierta al
entrar a facturar, pero la primera factura después de un rato puede tardar ~1 minuto.

## B4. Prender la facturación en la app

En `lib/app/app_info.dart` poné `facturacionDisponible = true`, subí `versionDatos`
en 1, repetí **A2** y **A3** con el número nuevo y generá el APK nuevo
(`flutter build apk --release`, copiándolo a `web/descargas/workcontrol.apk` antes de A2).

> Alternativa con Blaze: `firebase functions:secrets:set ARCA_CLAVE_MAESTRA`,
> `firebase deploy --only functions` y dejar `AppInfo.urlServidor` vacío.

## B5. Probar primero en homologación

Con un negocio en plan Básico o PRO:

1. Ajustes → **Facturación electrónica** → completar datos fiscales con ambiente
   **Pruebas** → guardar.
2. Generar la solicitud de certificado y seguir los pasos que muestra la pantalla
   (servicio WSASS de ARCA, con clave fiscal).
3. Pegar el certificado → **Guardar certificado y probar**.
4. Facturar un trabajo de prueba y revisar el PDF (dice "sin validez fiscal").
5. Recién después: datos fiscales → **Producción**, generar el certificado de producción
   en "Administración de Certificados Digitales", asociarlo al servicio de facturación
   electrónica y crear el punto de venta "RECE / Web Services".

---

### Si algo sale mal

- **Reglas o índices**: volver a publicar la versión anterior del archivo con
  `git checkout <commit> -- firestore.rules` y `firebase deploy --only firestore:rules`.
- **Web**: Consola → Hosting → historial de versiones → **Revertir**.
- **Servidor de facturación**: Render → el servicio → **Logs** muestra los errores.
- Los datos del sistema anterior (`users/{uid}/...`) nunca se borran: siempre se puede
  volver a migrar.
