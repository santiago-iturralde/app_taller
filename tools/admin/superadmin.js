// Da (o quita) el permiso de administrador de la plataforma a un usuario.
//
// Uso:
//   1. En la consola de Firebase: Configuración del proyecto > Cuentas de
//      servicio > "Generar nueva clave privada". Guardá el archivo FUERA del
//      repositorio (nunca lo subas a git).
//   2. PowerShell:
//        $env:GOOGLE_APPLICATION_CREDENTIALS="C:\ruta\clave.json"
//        node superadmin.js tu@email.com
//      Para quitarlo:  node superadmin.js tu@email.com --quitar
//      En el emulador: node superadmin.js tu@email.com --emulador
//   3. Cerrá sesión y volvé a entrar en la app para que tome el permiso.

import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

const [email, ...flags] = process.argv.slice(2);
if (!email || !email.includes('@')) {
  console.error('Uso: node superadmin.js <email> [--quitar] [--emulador]');
  process.exit(1);
}

const emulador = flags.includes('--emulador');
if (emulador) {
  process.env.FIREBASE_AUTH_EMULATOR_HOST ??= 'localhost:9099';
  initializeApp({ projectId: process.env.GCLOUD_PROJECT ?? 'taller-reparaciones-8cf11' });
} else {
  initializeApp({ credential: applicationDefault() });
}

const quitar = flags.includes('--quitar');
const usuario = await getAuth().getUserByEmail(email);
const claims = { ...(usuario.customClaims ?? {}) };
if (quitar) delete claims.superadmin;
else claims.superadmin = true;
await getAuth().setCustomUserClaims(usuario.uid, claims);

console.log(`${quitar ? 'Se quitó' : 'Se otorgó'} el permiso de administrador a ${email}${emulador ? ' (emulador)' : ''}.`);
console.log('Cerrá sesión y volvé a ingresar para que se aplique.');
