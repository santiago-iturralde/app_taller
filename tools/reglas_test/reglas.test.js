// Tests de las reglas de seguridad (firestore.rules) contra el emulador.
// Correr con: npm test   (desde tools/reglas_test)

import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

let env;
const ANA = 'ana';
const BETO = 'beto';

const dbDe = (uid) => env.authenticatedContext(uid).firestore();
const anonimo = () => env.unauthenticatedContext().firestore();

/** Crea el negocio de [uid] como lo hace la app (lote negocio + miembro). */
async function crearNegocio(uid, extra = {}) {
  const db = dbDe(uid);
  const batch = writeBatch(db);
  batch.set(doc(db, `negocios/${uid}`), {
    nombre: 'Taller de prueba',
    rubro: 'herramientas',
    ownerUid: uid,
    plan: 'free',
    creado: serverTimestamp(),
    ...extra,
  });
  batch.set(doc(db, `negocios/${uid}/miembros/${uid}`), { rol: 'owner', email: `${uid}@x.com` });
  return batch.commit();
}

/** Escribe datos salteando las reglas (como haría un administrador). */
const comoAdmin = (fn) => env.withSecurityRulesDisabled((ctx) => fn(ctx.firestore()));

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-workcontrol',
    firestore: { rules: readFileSync('../../firestore.rules', 'utf8') },
  });
});

after(() => env.cleanup());
beforeEach(() => env.clearFirestore());

describe('Alta de negocio', () => {
  test('el usuario crea su negocio gratis y queda como dueño', async () => {
    await assertSucceeds(crearNegocio(ANA));
  });

  test('no puede crearse un negocio PRO', async () => {
    await assertFails(crearNegocio(ANA, { plan: 'pro' }));
  });

  test('no puede crearse un negocio con vencimiento de plan', async () => {
    await assertFails(crearNegocio(ANA, { planVence: new Date(2099, 0, 1) }));
  });

  test('no puede crear el negocio con el ID de otro usuario', async () => {
    const db = dbDe(BETO);
    await assertFails(setDoc(doc(db, `negocios/${ANA}`), { nombre: 'X', ownerUid: BETO, plan: 'free' }));
  });

  test('puede leer "su" negocio aunque todavía no exista', async () => {
    await assertSucceeds(getDoc(doc(dbDe(ANA), `negocios/${ANA}`)));
  });

  test('sin sesión no se puede leer nada', async () => {
    await crearNegocio(ANA);
    await assertFails(getDoc(doc(anonimo(), `negocios/${ANA}`)));
  });
});

describe('Aislamiento entre negocios', () => {
  beforeEach(async () => {
    await crearNegocio(ANA);
    await comoAdmin((db) => setDoc(doc(db, `negocios/${ANA}/clientes/c1`), { nombre: 'Cliente de Ana' }));
  });

  test('otro usuario no puede leer el negocio ni sus clientes', async () => {
    const db = dbDe(BETO);
    await assertFails(getDoc(doc(db, `negocios/${ANA}`)));
    await assertFails(getDoc(doc(db, `negocios/${ANA}/clientes/c1`)));
  });

  test('otro usuario no puede escribir en el negocio', async () => {
    await assertFails(setDoc(doc(dbDe(BETO), `negocios/${ANA}/clientes/c2`), { nombre: 'Intruso' }));
  });

  test('otro usuario no puede auto-agregarse como miembro', async () => {
    const db = dbDe(BETO);
    await assertFails(setDoc(doc(db, `negocios/${ANA}/miembros/${BETO}`), { rol: 'owner' }));
    await assertFails(setDoc(doc(db, `negocios/${ANA}/miembros/${BETO}`), { rol: 'empleado' }));
  });

  test('el miembro sí puede leer y escribir', async () => {
    const db = dbDe(ANA);
    await assertSucceeds(getDoc(doc(db, `negocios/${ANA}/clientes/c1`)));
    await assertSucceeds(setDoc(doc(db, `negocios/${ANA}/clientes/c2`), { nombre: 'Nuevo' }));
  });
});

describe('Plan y datos protegidos', () => {
  beforeEach(() => crearNegocio(ANA));

  test('el dueño no puede activarse el plan PRO', async () => {
    await assertFails(updateDoc(doc(dbDe(ANA), `negocios/${ANA}`), { plan: 'pro' }));
  });

  test('el dueño no puede extender el vencimiento ni cambiar de dueño', async () => {
    const ref = doc(dbDe(ANA), `negocios/${ANA}`);
    await assertFails(updateDoc(ref, { planVence: new Date(2099, 0, 1) }));
    await assertFails(updateDoc(ref, { ownerUid: BETO }));
  });

  test('el dueño sí puede editar los datos del negocio', async () => {
    await assertSucceeds(updateDoc(doc(dbDe(ANA), `negocios/${ANA}`), { nombre: 'Nuevo nombre', telefono: '123' }));
  });

  test('un empleado no puede editar los datos del negocio', async () => {
    await comoAdmin((db) => setDoc(doc(db, `negocios/${ANA}/miembros/${BETO}`), { rol: 'empleado' }));
    await assertFails(updateDoc(doc(dbDe(BETO), `negocios/${ANA}`), { nombre: 'X' }));
    // …pero sí trabaja con los datos del día a día.
    await assertSucceeds(setDoc(doc(dbDe(BETO), `negocios/${ANA}/clientes/c9`), { nombre: 'Cliente' }));
  });

  test('el negocio no se puede borrar', async () => {
    await assertFails(deleteDoc(doc(dbDe(ANA), `negocios/${ANA}`)));
  });
});

describe('Cobros y numeración', () => {
  const pago = { numero: 1, monto: 1000, anulado: false };

  beforeEach(() => crearNegocio(ANA));

  test('se puede registrar un cobro', async () => {
    await assertSucceeds(setDoc(doc(dbDe(ANA), `negocios/${ANA}/pagos/p1`), pago));
  });

  test('un cobro no se puede borrar ni modificar su monto', async () => {
    await comoAdmin((db) => setDoc(doc(db, `negocios/${ANA}/pagos/p1`), pago));
    const ref = doc(dbDe(ANA), `negocios/${ANA}/pagos/p1`);
    await assertFails(deleteDoc(ref));
    await assertFails(updateDoc(ref, { monto: 1 }));
  });

  test('un cobro sí se puede anular', async () => {
    await comoAdmin((db) => setDoc(doc(db, `negocios/${ANA}/pagos/p1`), pago));
    await assertSucceeds(updateDoc(doc(dbDe(ANA), `negocios/${ANA}/pagos/p1`), { anulado: true, anuladoEn: serverTimestamp() }));
  });

  test('reescribir un cobro sin cambios está permitido (reintento de migración)', async () => {
    await comoAdmin((db) => setDoc(doc(db, `negocios/${ANA}/pagos/p1`), pago));
    await assertSucceeds(setDoc(doc(dbDe(ANA), `negocios/${ANA}/pagos/p1`), pago));
    await assertFails(setDoc(doc(dbDe(ANA), `negocios/${ANA}/pagos/p1`), { ...pago, anulado: false, monto: 2 }));
  });

  test('no se acepta un cobro negativo', async () => {
    await assertFails(setDoc(doc(dbDe(ANA), `negocios/${ANA}/pagos/p2`), { ...pago, monto: -5 }));
  });

  test('los contadores sólo pueden avanzar', async () => {
    const ref = doc(dbDe(ANA), `negocios/${ANA}/meta/contadores`);
    await assertSucceeds(setDoc(ref, { ordenes: 10, presupuestos: 2, pagos: 5 }));
    await assertSucceeds(updateDoc(ref, { ordenes: 11 }));
    await assertFails(updateDoc(ref, { ordenes: 3 }));
  });

  test('un trabajo con cobros no se puede borrar', async () => {
    await comoAdmin((db) => setDoc(doc(db, `negocios/${ANA}/ordenes/o1`), { numero: 1, total: 100, pagado: 50 }));
    await comoAdmin((db) => setDoc(doc(db, `negocios/${ANA}/ordenes/o2`), { numero: 2, total: 100, pagado: 0 }));
    await assertFails(deleteDoc(doc(dbDe(ANA), `negocios/${ANA}/ordenes/o1`)));
    await assertSucceeds(deleteDoc(doc(dbDe(ANA), `negocios/${ANA}/ordenes/o2`)));
  });

  test('un trabajo no puede tener lo cobrado en negativo', async () => {
    await assertFails(setDoc(doc(dbDe(ANA), `negocios/${ANA}/ordenes/o3`), { numero: 3, total: 100, pagado: -1 }));
  });
});

describe('Perfil de usuario y sistema anterior', () => {
  test('el usuario no puede marcarse premium en el esquema viejo', async () => {
    const db = dbDe(ANA);
    await assertFails(setDoc(doc(db, `users/${ANA}`), { isPremium: true }));
    await assertSucceeds(setDoc(doc(db, `users/${ANA}`), { isPremium: false, email: 'ana@x.com' }));
    await assertFails(updateDoc(doc(db, `users/${ANA}`), { isPremium: true }));
  });

  test('cada usuario sólo ve sus datos del sistema anterior', async () => {
    await comoAdmin((db) => setDoc(doc(db, `users/${ANA}/clientes/c1`), { nombre: 'x' }));
    await assertSucceeds(getDoc(doc(dbDe(ANA), `users/${ANA}/clientes/c1`)));
    await assertFails(getDoc(doc(dbDe(BETO), `users/${ANA}/clientes/c1`)));
  });

  test('la configuración global es de sólo lectura', async () => {
    await comoAdmin((db) => setDoc(doc(db, 'configuracion/app_info'), { version: 4 }));
    await assertSucceeds(getDoc(doc(dbDe(ANA), 'configuracion/app_info')));
    await assertFails(setDoc(doc(dbDe(ANA), 'configuracion/app_info'), { version: 1 }));
  });
});
