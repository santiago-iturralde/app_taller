import { FieldValue, Timestamp, getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { REGION } from '../config';
import { Plan, exigirSuperadmin, texto } from '../util/seguridad';

type Accion = 'activar' | 'prueba' | 'gratis';

/** Suma meses respetando fin de mes (31/01 + 1 mes = 28 o 29/02). */
export function sumarMeses(d: Date, meses: number): Date {
  const r = new Date(d.getTime());
  const dia = r.getUTCDate();
  r.setUTCDate(1);
  r.setUTCMonth(r.getUTCMonth() + meses);
  const ultimo = new Date(Date.UTC(r.getUTCFullYear(), r.getUTCMonth() + 1, 0)).getUTCDate();
  r.setUTCDate(Math.min(dia, ultimo));
  return r;
}

/**
 * Calcula el nuevo vencimiento. Al renovar el mismo plan antes de que
 * venza, el tiempo se suma al que le quedaba (no se pierde lo pagado).
 */
export function nuevoVencimiento(p: { planActual: Plan; venceActual: Date | null; planNuevo: Plan; meses: number; ahora: Date }): Date {
  const vigente = p.venceActual && p.venceActual.getTime() > p.ahora.getTime() && p.planActual === p.planNuevo;
  return sumarMeses(vigente ? p.venceActual! : p.ahora, p.meses);
}

/**
 * Cambia el plan de un negocio (sólo el administrador de la plataforma).
 * Cada cambio queda registrado en auditoriaPlanes.
 */
export const adminCambiarPlan = onCall({ region: REGION }, async (req) => {
  const admin = exigirSuperadmin(req);
  const data = (req.data ?? {}) as Record<string, unknown>;
  const negocioId = texto(data.negocioId, 'el negocio', 128);
  if (negocioId.includes('/')) throw new HttpsError('invalid-argument', 'Negocio inválido.');
  const accion = data.accion as Accion;
  if (!['activar', 'prueba', 'gratis'].includes(accion)) throw new HttpsError('invalid-argument', 'Acción inválida.');

  const monto = data.monto === undefined || data.monto === null ? null : Number(data.monto);
  if (monto !== null && (!Number.isFinite(monto) || monto < 0)) throw new HttpsError('invalid-argument', 'Monto inválido.');
  const nota = typeof data.nota === 'string' ? data.nota.trim().slice(0, 500) : '';

  const db = getFirestore();
  const ref = db.doc(`negocios/${negocioId}`);
  const ahora = new Date();

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError('not-found', 'El negocio no existe.');
    const planActual = (snap.get('plan') ?? 'free') as Plan;
    const venceActual = (snap.get('planVence') as Timestamp | undefined)?.toDate() ?? null;

    let cambios: Record<string, unknown>;
    let planNuevo: Plan;
    let venceNuevo: Date | null;

    if (accion === 'activar') {
      planNuevo = data.plan as Plan;
      if (planNuevo !== 'basico' && planNuevo !== 'pro') throw new HttpsError('invalid-argument', 'Plan inválido.');
      const meses = Number(data.meses);
      if (!Number.isInteger(meses) || meses < 1 || meses > 36) throw new HttpsError('invalid-argument', 'Cantidad de meses inválida.');
      venceNuevo = nuevoVencimiento({ planActual, venceActual, planNuevo, meses, ahora });
      cambios = { plan: planNuevo, planVence: Timestamp.fromDate(venceNuevo), prueba: false };
    } else if (accion === 'prueba') {
      const dias = Number(data.dias);
      if (!Number.isInteger(dias) || dias < 1 || dias > 90) throw new HttpsError('invalid-argument', 'Cantidad de días inválida.');
      planNuevo = 'pro';
      venceNuevo = new Date(ahora.getTime() + dias * 24 * 3600 * 1000);
      cambios = { plan: 'pro', planVence: Timestamp.fromDate(venceNuevo), prueba: true };
    } else {
      planNuevo = 'free';
      venceNuevo = null;
      cambios = { plan: 'free', planVence: FieldValue.delete(), prueba: false };
    }

    tx.update(ref, { ...cambios, planActualizado: FieldValue.serverTimestamp() });
    tx.set(db.collection('auditoriaPlanes').doc(), {
      negocioId,
      negocioNombre: snap.get('nombre') ?? '',
      accion,
      planAnterior: planActual,
      venceAnterior: venceActual ? Timestamp.fromDate(venceActual) : null,
      planNuevo,
      venceNuevo: venceNuevo ? Timestamp.fromDate(venceNuevo) : null,
      monto,
      nota,
      porUid: admin.uid,
      porEmail: admin.email,
      fecha: FieldValue.serverTimestamp(),
    });
    return { plan: planNuevo, vence: venceNuevo?.toISOString() ?? null };
  });
});
