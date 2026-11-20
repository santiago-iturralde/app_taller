/**
 * Backend de WorkControl como Cloud Functions (2da generación, plan Blaze).
 *
 * Las mismas acciones también se pueden servir con un servidor HTTP común
 * (servidor.ts), por ejemplo en Render, sin necesitar el plan Blaze.
 *
 * - Facturación electrónica ARCA: las claves privadas y los tickets de
 *   acceso nunca salen del servidor y se guardan cifrados.
 * - Los cambios de plan los hace el administrador desde la app; las reglas
 *   de Firestore exigen el custom claim "superadmin" y la auditoría.
 */
import { initializeApp } from 'firebase-admin/app';
import { defineSecret } from 'firebase-functions/params';
import { onCall } from 'firebase-functions/v2/https';

import { REGION } from './config';
import { ACCIONES_ARCA, Accion } from './handlers/arca';

initializeApp();

/**
 * Clave maestra para cifrar claves privadas y tickets de ARCA.
 * Se configura una sola vez: firebase functions:secrets:set ARCA_CLAVE_MAESTRA
 */
const claveMaestra = defineSecret('ARCA_CLAVE_MAESTRA');

const opciones = { region: REGION, secrets: [claveMaestra], timeoutSeconds: 120, memory: '512MiB' as const };

function exponer(accion: Accion) {
  return onCall(opciones, (req) =>
    accion(req.data, req.auth ? { uid: req.auth.uid, email: String(req.auth.token.email ?? '') } : null, claveMaestra.value()),
  );
}

export const arcaGenerarSolicitud = exponer(ACCIONES_ARCA.arcaGenerarSolicitud);
export const arcaGuardarCertificado = exponer(ACCIONES_ARCA.arcaGuardarCertificado);
export const arcaProbarConexion = exponer(ACCIONES_ARCA.arcaProbarConexion);
export const arcaEmitirFactura = exponer(ACCIONES_ARCA.arcaEmitirFactura);
export const arcaReintentar = exponer(ACCIONES_ARCA.arcaReintentar);
export const arcaAnularFactura = exponer(ACCIONES_ARCA.arcaAnularFactura);
