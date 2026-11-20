// Prueba de punta a punta del backend (servidor HTTP de servidor.ts, el que
// corre en Render) contra los emuladores de Auth y Firestore, sin ARCA.
// Correr desde functions/:  npm run e2e
//
// Verifica: permisos, plan requerido, generación de la solicitud de
// certificado, cifrado de la clave, carga del certificado, protección
// contra facturar dos veces y el corte al vencer o bajar el plan.
// (Los cambios de plan del administrador se prueban en tools/reglas_test.)

import assert from 'node:assert/strict';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { FieldValue, getFirestore, Timestamp } = require('firebase-admin/firestore');
const forge = require('node-forge');
const { randomBytes } = require('node:crypto');
const { crearServidor } = require('../lib/src/servidor.js');

const PROYECTO = 'demo-workcontrol';
const AUTH = process.env.FIREBASE_AUTH_EMULATOR_HOST;
assert.ok(AUTH && process.env.FIRESTORE_EMULATOR_HOST, 'Correr con firebase emulators:exec');

initializeApp({ projectId: PROYECTO });
const auth = getAuth();
const db = getFirestore();

// El servidor real, con verificación de tokens de Firebase (del emulador).
const servidor = crearServidor({ claveMaestra: randomBytes(32).toString('base64'), origenes: [] });
await new Promise((r) => servidor.listen(0, '127.0.0.1', r));
const FUNCIONES = `http://127.0.0.1:${servidor.address().port}`;

async function crearUsuario(email, claims) {
  const u = await auth.createUser({ email, password: 'clave-segura-123', emailVerified: true });
  if (claims) await auth.setCustomUserClaims(u.uid, claims);
  const r = await fetch(`http://${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password: 'clave-segura-123', returnSecureToken: true }),
  });
  const { idToken } = await r.json();
  return { uid: u.uid, token: idToken };
}

/** Llama a una función callable como lo hace la app. */
async function llamar(nombre, datos, usuario) {
  const r = await fetch(`${FUNCIONES}/${nombre}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...(usuario ? { Authorization: `Bearer ${usuario.token}` } : {}) },
    body: JSON.stringify({ data: datos }),
  });
  const cuerpo = await r.json();
  return cuerpo.error ? { error: cuerpo.error.status, mensaje: cuerpo.error.message } : { ok: cuerpo.result };
}

function certificadoDePrueba(csrPem) {
  const csr = forge.pki.certificationRequestFromPem(csrPem);
  const ca = forge.pki.rsa.generateKeyPair(1024);
  const cert = forge.pki.createCertificate();
  cert.publicKey = csr.publicKey;
  cert.serialNumber = '02';
  cert.validity.notBefore = new Date();
  cert.validity.notAfter = new Date(Date.now() + 365 * 24 * 3600 * 1000);
  cert.setSubject(csr.subject.attributes);
  cert.setIssuer([{ name: 'commonName', value: 'CA de prueba' }]);
  cert.sign(ca.privateKey, forge.md.sha256.create());
  return forge.pki.certificateToPem(cert);
}

let pasos = 0;
async function paso(nombre, fn) {
  await fn();
  pasos++;
  console.log(`  ✔ ${nombre}`);
}

const duenio = await crearUsuario('duenio@lubri.com');
const intruso = await crearUsuario('intruso@x.com');
const N = duenio.uid;

await db.doc(`negocios/${N}`).set({ nombre: 'Lubricentro Demo', rubro: 'lubricentro', ownerUid: N, plan: 'free' });
await db.doc(`negocios/${N}/miembros/${N}`).set({ rol: 'owner', email: 'duenio@lubri.com' });
await db.doc(`negocios/${N}/meta/fiscal`).set({
  razonSocial: 'Lubricentro Demo SRL', cuit: '33693450239', condicionIva: 'responsable_inscripto', domicilio: 'Calle 1',
  ingresosBrutos: '', inicioActividades: '', puntoVenta: 3, alicuotaIva: 21, ambiente: 'homologacion', concepto: 3,
});
await db.doc(`negocios/${N}/ordenes/facturada`).set({ numero: 1, total: 100, pagado: 0, estado: 'entregado', items: [], facturaId: 'f-existente' });

console.log('Backend de punta a punta:');

await paso('sin sesión no se puede llamar', async () => {
  assert.equal((await llamar('arcaGenerarSolicitud', { negocioId: N })).error, 'UNAUTHENTICATED');
});

await paso('un usuario de otro negocio no tiene acceso', async () => {
  assert.equal((await llamar('arcaGenerarSolicitud', { negocioId: N }, intruso)).error, 'PERMISSION_DENIED');
});

await paso('con plan Gratis la facturación está bloqueada', async () => {
  const r = await llamar('arcaGenerarSolicitud', { negocioId: N }, duenio);
  assert.equal(r.error, 'FAILED_PRECONDITION');
  assert.match(r.mensaje, /plan/i);
});

await paso('con plan vencido se bloquea y con plan vigente se habilita', async () => {
  const dias = (n) => Timestamp.fromDate(new Date(Date.now() + n * 24 * 3600 * 1000));
  await db.doc(`negocios/${N}`).update({ plan: 'basico', planVence: dias(-1), prueba: false });
  const vencido = await llamar('arcaProbarConexion', { negocioId: N }, duenio);
  assert.equal(vencido.error, 'FAILED_PRECONDITION');
  assert.match(vencido.mensaje, /plan/i);
  await db.doc(`negocios/${N}`).update({ planVence: dias(30) });
  const vigente = await llamar('arcaProbarConexion', { negocioId: N }, duenio);
  assert.doesNotMatch(vigente.mensaje ?? '', /plan/i, 'ya no lo frena el plan (sí la falta de certificado)');
});

let csr;
await paso('genera la solicitud de certificado y guarda la clave cifrada', async () => {
  const r = await llamar('arcaGenerarSolicitud', { negocioId: N }, duenio);
  csr = r.ok?.csr;
  assert.match(csr ?? '', /BEGIN CERTIFICATE REQUEST/, JSON.stringify(r));
  const priv = (await db.doc(`negocios/${N}/privado/arca_homologacion`).get()).data();
  assert.match(priv.claveCifrada, /^v1:/);
  assert.doesNotMatch(JSON.stringify(priv), /PRIVATE KEY/);
  const estado = (await db.doc(`negocios/${N}/meta/arca`).get()).data();
  assert.equal(estado.homologacion.estado, 'esperando_certificado');
});

await paso('rechaza un certificado que no corresponde a la clave', async () => {
  const otra = forge.pki.rsa.generateKeyPair(1024);
  const otroCsr = forge.pki.createCertificationRequest();
  otroCsr.publicKey = otra.publicKey;
  otroCsr.setSubject([{ type: '2.5.4.5', value: 'CUIT 33693450239' }]);
  otroCsr.sign(otra.privateKey);
  const r = await llamar('arcaGuardarCertificado', { negocioId: N, certificado: certificadoDePrueba(forge.pki.certificationRequestToPem(otroCsr)) }, duenio);
  assert.equal(r.error, 'FAILED_PRECONDITION');
  assert.match(r.mensaje, /no corresponde/);
});

await paso('guarda el certificado correcto y queda listo', async () => {
  const r = await llamar('arcaGuardarCertificado', { negocioId: N, certificado: certificadoDePrueba(csr) }, duenio);
  assert.ok(r.ok, JSON.stringify(r));
  const estado = (await db.doc(`negocios/${N}/meta/arca`).get()).data();
  assert.equal(estado.homologacion.estado, 'listo');
});

await paso('valida los datos de la factura antes de ir a ARCA', async () => {
  const base = { negocioId: N, origen: { tipo: 'orden', id: 'facturada' } };
  const r1 = await llamar('arcaEmitirFactura', { ...base, receptor: { nombre: 'X', docTipo: 'pasaporte', condicionIva: 'consumidor_final' } }, duenio);
  assert.equal(r1.error, 'INVALID_ARGUMENT');
  const r2 = await llamar('arcaEmitirFactura', { ...base, origen: { tipo: 'orden', id: '../otro' }, receptor: { nombre: 'X', docTipo: 'consumidor_final', condicionIva: 'consumidor_final' } }, duenio);
  assert.equal(r2.error, 'INVALID_ARGUMENT');
});

await paso('no permite facturar dos veces el mismo trabajo', async () => {
  const r = await llamar('arcaEmitirFactura', {
    negocioId: N,
    origen: { tipo: 'orden', id: 'facturada' },
    receptor: { nombre: 'Cliente', docTipo: 'consumidor_final', docNro: '', condicionIva: 'consumidor_final' },
  }, duenio);
  assert.equal(r.error, 'FAILED_PRECONDITION');
  assert.match(r.mensaje, /ya tiene una factura/);
  const facturas = await db.collection(`negocios/${N}/facturas`).get();
  assert.equal(facturas.size, 0, 'no debe quedar ninguna factura a medias');
});

await paso('una factura A exige CUIT válido del cliente', async () => {
  await db.doc(`negocios/${N}/ordenes/nueva`).set({ numero: 2, total: 1210, pagado: 0, estado: 'entregado', items: [{ descripcion: 'Service', cantidad: 1, precioUnitario: 1210 }] });
  const r = await llamar('arcaEmitirFactura', {
    negocioId: N,
    origen: { tipo: 'orden', id: 'nueva' },
    receptor: { nombre: 'Empresa', docTipo: 'dni', docNro: '30111222', condicionIva: 'responsable_inscripto' },
  }, duenio);
  assert.equal(r.error, 'FAILED_PRECONDITION');
  assert.match(r.mensaje, /CUIT/);
  const orden = (await db.doc(`negocios/${N}/ordenes/nueva`).get()).data();
  assert.equal(orden.facturaId, undefined, 'el trabajo queda libre para facturar');
});

await paso('pasar a Gratis corta la facturación', async () => {
  await db.doc(`negocios/${N}`).update({ plan: 'free', planVence: FieldValue.delete() });
  assert.equal((await llamar('arcaProbarConexion', { negocioId: N }, duenio)).error, 'FAILED_PRECONDITION');
});

servidor.close();
console.log(`\n${pasos} pasos OK`);
process.exit(0);
