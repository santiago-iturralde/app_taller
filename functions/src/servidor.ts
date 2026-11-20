/**
 * Servidor HTTP del backend (para hostings como Render, sin plan Blaze).
 *
 * Habla el mismo protocolo que las Cloud Functions "callable": la app lo
 * llama con httpsCallableFromUrl y envía el token de sesión de Firebase,
 * que acá se verifica con firebase-admin. Las acciones son las mismas que
 * exponen las Cloud Functions (handlers/arca.ts).
 *
 * Variables de entorno:
 *   ARCA_CLAVE_MAESTRA        32 bytes en base64 (cifra claves y tickets).
 *   FIREBASE_SERVICE_ACCOUNT  JSON de la cuenta de servicio (texto o base64).
 *   ORIGENES                  orígenes web permitidos, separados por coma.
 *   PORT                      puerto (lo define el hosting).
 */
import { IncomingMessage, Server, ServerResponse, createServer } from 'node:http';

import { cert, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { HttpsError } from 'firebase-functions/v2/https';

import { ACCIONES_ARCA, Accion } from './handlers/arca';
import { Sesion } from './util/seguridad';

const ACCIONES: Record<string, Accion> = ACCIONES_ARCA;

/** Tamaño máximo del pedido (el certificado ocupa ~2 KB). */
const MAX_CUERPO = 64 * 1024;

export interface ConfigServidor {
  claveMaestra: string;
  /** Orígenes web permitidos (CORS). Las apps móviles no envían origen. */
  origenes: string[];
  /** Verifica el token de sesión (inyectable para tests). */
  verificarToken?: (token: string) => Promise<Sesion>;
  /** Pedidos por minuto por usuario. */
  limitePorMinuto?: number;
}

async function verificarConFirebase(token: string): Promise<Sesion> {
  const t = await getAuth().verifyIdToken(token);
  return { uid: t.uid, email: String(t.email ?? '') };
}

function responder(res: ServerResponse, status: number, cuerpo: unknown): void {
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
    'X-Content-Type-Options': 'nosniff',
  });
  res.end(JSON.stringify(cuerpo));
}

function responderError(res: ServerResponse, e: HttpsError): void {
  responder(res, e.httpErrorCode.status, { error: e.toJSON() });
}

function leerCuerpo(req: IncomingMessage): Promise<unknown> {
  return new Promise((resolve, reject) => {
    const partes: Buffer[] = [];
    let total = 0;
    req.on('data', (c: Buffer) => {
      total += c.length;
      // Se sigue leyendo (sin guardar) para poder responder el error.
      if (total <= MAX_CUERPO) partes.push(c);
    });
    req.on('end', () => {
      if (total > MAX_CUERPO) {
        reject(new HttpsError('invalid-argument', 'El pedido es demasiado grande.'));
        return;
      }
      try {
        resolve(JSON.parse(Buffer.concat(partes).toString('utf8') || '{}'));
      } catch {
        reject(new HttpsError('invalid-argument', 'Pedido inválido.'));
      }
    });
    req.on('error', reject);
  });
}

/** Límite simple de pedidos por usuario y minuto (en memoria). */
function crearLimitador(maximo: number) {
  const ventanas = new Map<string, { desde: number; cantidad: number }>();
  return (uid: string): boolean => {
    const ahora = Date.now();
    const v = ventanas.get(uid);
    if (!v || ahora - v.desde > 60_000) {
      if (ventanas.size > 10_000) ventanas.clear();
      ventanas.set(uid, { desde: ahora, cantidad: 1 });
      return true;
    }
    v.cantidad++;
    return v.cantidad <= maximo;
  };
}

export function crearServidor(cfg: ConfigServidor): Server {
  const verificar = cfg.verificarToken ?? verificarConFirebase;
  const permitir = crearLimitador(cfg.limitePorMinuto ?? 30);

  return createServer(async (req, res) => {
    const origen = req.headers.origin;
    if (origen && cfg.origenes.includes(origen)) {
      res.setHeader('Access-Control-Allow-Origin', origen);
      res.setHeader('Vary', 'Origin');
      res.setHeader('Access-Control-Allow-Methods', 'POST, GET, OPTIONS');
      res.setHeader(
        'Access-Control-Allow-Headers',
        'Authorization, Content-Type, X-Firebase-AppCheck, X-Firebase-GMPID, X-Firebase-Client, Firebase-Instance-ID-Token',
      );
      res.setHeader('Access-Control-Max-Age', '3600');
    } else if (origen) {
      // Un sitio web ajeno no puede usar el backend desde el navegador.
      responderError(res, new HttpsError('permission-denied', 'Origen no permitido.'));
      return;
    }
    if (req.method === 'OPTIONS') {
      res.writeHead(204).end();
      return;
    }

    const ruta = new URL(req.url ?? '/', 'http://local').pathname.replace(/^\/+|\/+$/g, '');

    // Salud / despertar: el hosting gratuito duerme el servidor sin uso y
    // la app lo despierta antes de facturar.
    if (ruta === '' || ruta === 'salud' || ruta === 'despertar') {
      responder(res, 200, req.method === 'POST' ? { result: { ok: true } } : { ok: true });
      return;
    }

    const accion = Object.prototype.hasOwnProperty.call(ACCIONES, ruta) ? ACCIONES[ruta] : undefined;
    if (!accion || req.method !== 'POST') {
      responderError(res, new HttpsError('not-found', 'No existe.'));
      return;
    }

    try {
      const cuerpo = (await leerCuerpo(req)) as { data?: unknown };

      let sesion: Sesion | null = null;
      const auth = req.headers.authorization ?? '';
      if (auth.startsWith('Bearer ')) {
        try {
          sesion = await verificar(auth.slice(7).trim());
        } catch {
          throw new HttpsError('unauthenticated', 'Tu sesión venció. Volvé a ingresar.');
        }
        if (!permitir(sesion.uid)) {
          throw new HttpsError('resource-exhausted', 'Demasiados pedidos seguidos. Esperá un minuto.');
        }
      }

      const resultado = await accion(cuerpo?.data ?? null, sesion, cfg.claveMaestra);
      responder(res, 200, { result: resultado ?? null });
    } catch (e) {
      if (e instanceof HttpsError) {
        responderError(res, e);
      } else {
        console.error(`Error en ${ruta}:`, e);
        responderError(res, new HttpsError('internal', 'Ocurrió un error en el servidor. Probá de nuevo.'));
      }
    }
  });
}

/** Lee la cuenta de servicio (JSON en texto o en base64). */
function leerCuentaDeServicio(valor: string): Record<string, string> {
  const texto = valor.trim().startsWith('{') ? valor : Buffer.from(valor, 'base64').toString('utf8');
  return JSON.parse(texto);
}

function iniciar(): void {
  const clave = process.env.ARCA_CLAVE_MAESTRA ?? '';
  if (Buffer.from(clave.trim(), 'base64').length !== 32) {
    console.error('Falta ARCA_CLAVE_MAESTRA (32 bytes en base64).');
    process.exit(1);
  }
  const cuenta = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (cuenta) {
    initializeApp({ credential: cert(leerCuentaDeServicio(cuenta)) });
  } else if (process.env.FIRESTORE_EMULATOR_HOST) {
    initializeApp({ projectId: process.env.GCLOUD_PROJECT ?? 'demo-workcontrol' });
  } else {
    console.error('Falta FIREBASE_SERVICE_ACCOUNT.');
    process.exit(1);
  }

  const origenes = (process.env.ORIGENES ?? 'https://taller-app-admin.web.app,https://taller-app-admin.firebaseapp.com')
    .split(',')
    .map((o) => o.trim())
    .filter(Boolean);
  const puerto = Number(process.env.PORT ?? 8080);
  const servidor = crearServidor({ claveMaestra: clave.trim(), origenes });
  servidor.listen(puerto, () => console.log(`WorkControl backend escuchando en el puerto ${puerto}`));
  process.on('SIGTERM', () => servidor.close(() => process.exit(0)));
}

if (require.main === module) iniciar();
