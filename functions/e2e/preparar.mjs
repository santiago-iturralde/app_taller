// Crea la clave maestra local para el emulador (functions/.secret.local,
// ignorado por git) si todavía no existe.
import { existsSync, writeFileSync } from 'node:fs';
import { randomBytes } from 'node:crypto';

if (!existsSync('.secret.local')) {
  writeFileSync('.secret.local', `ARCA_CLAVE_MAESTRA=${randomBytes(32).toString('base64')}\n`);
  console.log('Clave maestra local creada en functions/.secret.local');
}
