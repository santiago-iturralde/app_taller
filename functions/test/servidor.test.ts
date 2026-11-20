import assert from 'node:assert/strict';
import { AddressInfo } from 'node:net';
import { after, before, describe, test } from 'node:test';

import { crearServidor } from '../src/servidor';

const WEB = 'https://taller-app-admin.web.app';

describe('servidor HTTP (protocolo callable)', () => {
  const servidor = crearServidor({
    claveMaestra: Buffer.alloc(32).toString('base64'),
    origenes: [WEB],
    limitePorMinuto: 3,
    verificarToken: async (t) => {
      if (t !== 'token-valido') throw new Error('token inválido');
      return { uid: 'u1', email: 'u1@x.com' };
    },
  });
  let base = '';

  before(async () => {
    await new Promise<void>((r) => servidor.listen(0, '127.0.0.1', r));
    base = `http://127.0.0.1:${(servidor.address() as AddressInfo).port}`;
  });
  after(() => servidor.close());

  const llamar = (ruta: string, init: RequestInit = {}) =>
    fetch(`${base}/${ruta}`, {
      method: 'POST',
      ...init,
      headers: { 'Content-Type': 'application/json', ...(init.headers ?? {}) },
      body: init.body ?? JSON.stringify({ data: {} }),
    });

  test('responde a la verificación de salud y al pedido de despertar', async () => {
    assert.equal((await fetch(`${base}/salud`)).status, 200);
    const r = await llamar('despertar');
    assert.deepEqual(await r.json(), { result: { ok: true } });
  });

  test('CORS: permite la app web y rechaza otros sitios', async () => {
    const pre = await fetch(`${base}/arcaProbarConexion`, { method: 'OPTIONS', headers: { Origin: WEB } });
    assert.equal(pre.status, 204);
    assert.equal(pre.headers.get('access-control-allow-origin'), WEB);
    assert.match(pre.headers.get('access-control-allow-headers') ?? '', /Authorization/);

    const ajeno = await llamar('arcaProbarConexion', { headers: { Origin: 'https://malicioso.com' } });
    assert.equal(ajeno.status, 403);
  });

  test('sin sesión o con token inválido: no autenticado', async () => {
    const sin = await llamar('arcaProbarConexion');
    assert.equal(sin.status, 401);
    assert.equal(((await sin.json()) as any).error.status, 'UNAUTHENTICATED');

    const malo = await llamar('arcaProbarConexion', { headers: { Authorization: 'Bearer otro' } });
    assert.equal(malo.status, 401);
  });

  test('valida los datos con el mismo formato de error que las Cloud Functions', async () => {
    const r = await llamar('arcaProbarConexion', { headers: { Authorization: 'Bearer token-valido' } });
    assert.equal(r.status, 400);
    const { error } = (await r.json()) as any;
    assert.equal(error.status, 'INVALID_ARGUMENT');
    assert.match(error.message, /negocio/);
  });

  test('acciones inexistentes, métodos incorrectos y pedidos mal formados', async () => {
    assert.equal((await llamar('constructor')).status, 404);
    assert.equal((await llamar('__proto__')).status, 404);
    assert.equal((await fetch(`${base}/arcaEmitirFactura`)).status, 404);
    assert.equal((await llamar('arcaProbarConexion', { body: '{no es json' })).status, 400);
    assert.equal((await llamar('arcaProbarConexion', { body: JSON.stringify({ data: 'x'.repeat(70_000) }) })).status, 400);
  });

  test('limita los pedidos por usuario', async () => {
    const pedir = () => llamar('arcaReintentar', { headers: { Authorization: 'Bearer token-valido' } });
    const estados: number[] = [];
    for (let i = 0; i < 4; i++) estados.push((await pedir()).status);
    assert.equal(estados.at(-1), 429);
  });
});
