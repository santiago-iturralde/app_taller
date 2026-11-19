import { FieldValue, Timestamp, getFirestore } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';

/**
 * Bloqueo con vencimiento (lease) sobre un documento de Firestore.
 *
 * Se usa para que dos facturas del mismo punto de venta y tipo no pidan el
 * mismo número a ARCA al mismo tiempo. Si una función se cae sin liberar,
 * el bloqueo vence solo.
 */
export async function conBloqueo<T>(ruta: string, duracionMs: number, tarea: () => Promise<T>): Promise<T> {
  const db = getFirestore();
  const ref = db.doc(ruta);
  const id = `${Date.now()}-${Math.random().toString(36).slice(2)}`;

  for (let intento = 0; intento < 10; intento++) {
    const tomado = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const vence = (snap.get('vence') as Timestamp | undefined)?.toMillis() ?? 0;
      if (snap.exists && vence > Date.now()) return false;
      tx.set(ref, { id, vence: Timestamp.fromMillis(Date.now() + duracionMs), creado: FieldValue.serverTimestamp() });
      return true;
    });
    if (tomado) {
      try {
        return await tarea();
      } finally {
        // Sólo libera si sigue siendo nuestro.
        await db.runTransaction(async (tx) => {
          const snap = await tx.get(ref);
          if (snap.get('id') === id) tx.delete(ref);
        });
      }
    }
    await new Promise((r) => setTimeout(r, 400 + intento * 300));
  }
  throw new HttpsError('resource-exhausted', 'Hay otra factura emitiéndose en este momento. Probá de nuevo en unos segundos.');
}
