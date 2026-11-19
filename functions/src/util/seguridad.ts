import { getFirestore } from 'firebase-admin/firestore';
import { CallableRequest, HttpsError } from 'firebase-functions/v2/https';

export type Rol = 'owner' | 'admin' | 'empleado';
export type Plan = 'free' | 'basico' | 'pro';

/** Usuario autenticado de la llamada, o error. */
export function usuario(req: CallableRequest<unknown>): { uid: string; email: string } {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Tenés que iniciar sesión.');
  return { uid: req.auth.uid, email: String(req.auth.token.email ?? '') };
}

/** Verifica que el usuario sea miembro del negocio (y con alguno de los roles). */
export async function exigirMiembro(negocioId: string, uid: string, roles: Rol[] = ['owner', 'admin', 'empleado']): Promise<Rol> {
  if (!negocioId || typeof negocioId !== 'string' || negocioId.includes('/')) {
    throw new HttpsError('invalid-argument', 'Negocio inválido.');
  }
  const m = await getFirestore().doc(`negocios/${negocioId}/miembros/${uid}`).get();
  const rol = m.get('rol') as Rol | undefined;
  if (!m.exists || !rol) throw new HttpsError('permission-denied', 'No tenés acceso a este negocio.');
  if (!roles.includes(rol)) throw new HttpsError('permission-denied', 'Tu rol no permite realizar esta acción.');
  return rol;
}

/** Plan efectivo: si el plan pago venció, el negocio queda en "free". */
export function planVigente(negocio: FirebaseFirestore.DocumentData | undefined, ahora = new Date()): Plan {
  const plan = (negocio?.plan ?? 'free') as Plan;
  const vence = negocio?.planVence?.toDate?.() as Date | undefined;
  if (plan === 'free') return 'free';
  if (vence && vence.getTime() < ahora.getTime()) return 'free';
  return plan;
}

/** La facturación electrónica requiere un plan pago vigente. */
export async function exigirPlanConFacturacion(negocioId: string): Promise<FirebaseFirestore.DocumentData> {
  const n = await getFirestore().doc(`negocios/${negocioId}`).get();
  if (!n.exists) throw new HttpsError('not-found', 'El negocio no existe.');
  const plan = planVigente(n.data());
  if (plan === 'free') {
    throw new HttpsError('failed-precondition', 'La facturación electrónica requiere un plan Básico o PRO vigente.');
  }
  return n.data()!;
}

/** Valida un texto obligatorio de un payload. */
export function texto(v: unknown, campo: string, max = 200): string {
  if (typeof v !== 'string' || !v.trim()) throw new HttpsError('invalid-argument', `Falta ${campo}.`);
  if (v.length > max) throw new HttpsError('invalid-argument', `${campo} es demasiado largo.`);
  return v.trim();
}
