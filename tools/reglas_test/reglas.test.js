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
  Timestamp,
  deleteDoc,
  deleteField,
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
/** Usuario con email (verificado o no) en el token. */
const dbConEmail = (uid, email, verificado = true) =>
  env.authenticatedContext(uid, { email, email_verified: verificado }).firestore();
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

describe('Catálogo y stock', () => {
  const producto = { nombre: 'Aceite 10W40', precio: 9000, stock: 10, tipo: 'producto' };

  beforeEach(() => crearNegocio(ANA));

  test('el miembro crea productos y mueve stock', async () => {
    const db = dbDe(ANA);
    await assertSucceeds(setDoc(doc(db, `negocios/${ANA}/productos/p1`), producto));
    await assertSucceeds(updateDoc(doc(db, `negocios/${ANA}/productos/p1`), { stock: 6 }));
    await assertSucceeds(setDoc(doc(db, `negocios/${ANA}/movimientosStock/m1`), { productoId: 'p1', cantidad: -4, usuarioUid: ANA }));
    // El movimiento tiene que estar firmado por quien lo hace.
    await assertFails(setDoc(doc(db, `negocios/${ANA}/movimientosStock/m2`), { productoId: 'p1', cantidad: -4, usuarioUid: BETO }));
  });

  test('producto sin nombre o con precio negativo se rechaza', async () => {
    const db = dbDe(ANA);
    await assertFails(setDoc(doc(db, `negocios/${ANA}/productos/p2`), { ...producto, nombre: '' }));
    await assertFails(setDoc(doc(db, `negocios/${ANA}/productos/p3`), { ...producto, precio: -1 }));
  });

  test('el historial de stock no se puede editar ni borrar', async () => {
    await comoAdmin((db) => setDoc(doc(db, `negocios/${ANA}/movimientosStock/m1`), { productoId: 'p1', cantidad: 5 }));
    const ref = doc(dbDe(ANA), `negocios/${ANA}/movimientosStock/m1`);
    await assertFails(updateDoc(ref, { cantidad: 500 }));
    await assertFails(deleteDoc(ref));
  });

  test('otro negocio no ve el catálogo', async () => {
    await comoAdmin((db) => setDoc(doc(db, `negocios/${ANA}/productos/p1`), producto));
    await assertFails(getDoc(doc(dbDe(BETO), `negocios/${ANA}/productos/p1`)));
  });
});

describe('Invitaciones al equipo', () => {
  const CARLA = 'carla';
  const EMAIL_CARLA = 'carla@taller.com';
  const enUnaSemana = () => new Date(Date.now() + 7 * 24 * 3600 * 1000);
  const idInv = (email = EMAIL_CARLA) => `${ANA}_${email}`;
  const invitacion = (extra = {}) => ({
    negocioId: ANA,
    negocioNombre: 'Taller de prueba',
    email: EMAIL_CARLA,
    rol: 'empleado',
    creadoPor: ANA,
    vence: enUnaSemana(),
    ...extra,
  });
  const hacerPro = () => comoAdmin((db) => updateDoc(doc(db, `negocios/${ANA}`), { plan: 'pro' }));

  /** Carla acepta: se da de alta, consume la invitación y fija su negocio. */
  async function aceptar(db, rol = 'empleado') {
    const batch = writeBatch(db);
    batch.set(doc(db, `negocios/${ANA}/miembros/${CARLA}`), { rol, email: EMAIL_CARLA, desde: serverTimestamp() });
    batch.delete(doc(db, `invitaciones/${idInv()}`));
    batch.set(doc(db, `users/${CARLA}`), { negocioId: ANA }, { merge: true });
    return batch.commit();
  }

  beforeEach(() => crearNegocio(ANA));

  test('con plan gratis no se puede invitar (es función PRO)', async () => {
    await assertFails(setDoc(doc(dbDe(ANA), `invitaciones/${idInv()}`), invitacion()));
  });

  test('el dueño PRO invita; el ID tiene que coincidir con negocio y email', async () => {
    await hacerPro();
    const db = dbDe(ANA);
    await assertSucceeds(setDoc(doc(db, `invitaciones/${idInv()}`), invitacion()));
    await assertFails(setDoc(doc(db, `invitaciones/otro_id`), invitacion({ email: 'x@y.com' })));
    await assertFails(setDoc(doc(db, `invitaciones/${idInv('MAYUS@Y.COM')}`), invitacion({ email: 'MAYUS@Y.COM' })));
  });

  test('no se puede invitar como dueño ni con vencimiento largo', async () => {
    await hacerPro();
    const db = dbDe(ANA);
    await assertFails(setDoc(doc(db, `invitaciones/${idInv()}`), invitacion({ rol: 'owner' })));
    await assertFails(setDoc(doc(db, `invitaciones/${idInv()}`), invitacion({ vence: new Date(2099, 0, 1) })));
  });

  test('un admin invita empleados pero no administradores', async () => {
    await hacerPro();
    await comoAdmin((db) => setDoc(doc(db, `negocios/${ANA}/miembros/${BETO}`), { rol: 'admin' }));
    const db = dbDe(BETO);
    await assertSucceeds(setDoc(doc(db, `invitaciones/${idInv()}`), invitacion({ creadoPor: BETO })));
    await assertFails(
      setDoc(doc(db, `invitaciones/${idInv('otro@x.com')}`), invitacion({ email: 'otro@x.com', rol: 'admin', creadoPor: BETO })),
    );
  });

  test('un empleado no puede invitar', async () => {
    await hacerPro();
    await comoAdmin((db) => setDoc(doc(db, `negocios/${ANA}/miembros/${BETO}`), { rol: 'empleado' }));
    await assertFails(setDoc(doc(dbDe(BETO), `invitaciones/${idInv()}`), invitacion({ creadoPor: BETO })));
  });

  test('sin email verificado no se ve ni se acepta la invitación', async () => {
    await comoAdmin((db) => setDoc(doc(db, `invitaciones/${idInv()}`), invitacion()));
    const db = dbConEmail(CARLA, EMAIL_CARLA, false);
    await assertFails(getDoc(doc(db, `invitaciones/${idInv()}`)));
    await assertFails(aceptar(db));
  });

  test('con email verificado la acepta y queda como empleado', async () => {
    await comoAdmin((db) => setDoc(doc(db, `invitaciones/${idInv()}`), invitacion()));
    const db = dbConEmail(CARLA, EMAIL_CARLA);
    await assertSucceeds(getDoc(doc(db, `invitaciones/${idInv()}`)));
    await assertSucceeds(aceptar(db));
    await assertSucceeds(getDoc(doc(db, `negocios/${ANA}`)));
  });

  test('no se puede aceptar con un rol distinto al invitado', async () => {
    await comoAdmin((db) => setDoc(doc(db, `invitaciones/${idInv()}`), invitacion()));
    await assertFails(aceptar(dbConEmail(CARLA, EMAIL_CARLA), 'admin'));
  });

  test('otra persona no puede usar la invitación de Carla', async () => {
    await comoAdmin((db) => setDoc(doc(db, `invitaciones/${idInv()}`), invitacion()));
    const intruso = dbConEmail(BETO, 'beto@x.com');
    await assertFails(getDoc(doc(intruso, `invitaciones/${idInv()}`)));
    await assertFails(setDoc(doc(intruso, `negocios/${ANA}/miembros/${BETO}`), { rol: 'empleado', email: 'beto@x.com' }));
  });

  test('una invitación vencida no sirve', async () => {
    await comoAdmin((db) => setDoc(doc(db, `invitaciones/${idInv()}`), invitacion({ vence: new Date(2020, 0, 1) })));
    await assertFails(aceptar(dbConEmail(CARLA, EMAIL_CARLA)));
  });

  test('no se pueden agregar campos extra al darse de alta', async () => {
    await comoAdmin((db) => setDoc(doc(db, `invitaciones/${idInv()}`), invitacion()));
    const db = dbConEmail(CARLA, EMAIL_CARLA);
    await assertFails(setDoc(doc(db, `negocios/${ANA}/miembros/${CARLA}`), { rol: 'empleado', email: EMAIL_CARLA, superusuario: true }));
  });
});

describe('Permisos de empleados', () => {
  beforeEach(async () => {
    await crearNegocio(ANA);
    await comoAdmin(async (db) => {
      await setDoc(doc(db, `negocios/${ANA}/miembros/${BETO}`), { rol: 'empleado' });
      await setDoc(doc(db, `negocios/${ANA}/clientes/c1`), { nombre: 'Cliente' });
      await setDoc(doc(db, `negocios/${ANA}/gastos/g1`), { descripcion: 'Alquiler', monto: 1000 });
      await setDoc(doc(db, `negocios/${ANA}/pagos/p1`), { numero: 1, monto: 500, anulado: false });
      await setDoc(doc(db, `negocios/${ANA}/productos/pr1`), { nombre: 'Aceite', precio: 9000, stock: 10 });
    });
  });

  test('trabaja el día a día', async () => {
    const db = dbDe(BETO);
    await assertSucceeds(setDoc(doc(db, `negocios/${ANA}/clientes/c2`), { nombre: 'Nuevo' }));
    await assertSucceeds(setDoc(doc(db, `negocios/${ANA}/pagos/p2`), { numero: 2, monto: 100, anulado: false }));
    await assertSucceeds(updateDoc(doc(db, `negocios/${ANA}/productos/pr1`), { stock: 6, stockBajo: false }));
  });

  test('no ve gastos', async () => {
    await assertFails(getDoc(doc(dbDe(BETO), `negocios/${ANA}/gastos/g1`)));
  });

  test('no borra clientes ni anula cobros', async () => {
    const db = dbDe(BETO);
    await assertFails(deleteDoc(doc(db, `negocios/${ANA}/clientes/c1`)));
    await assertFails(updateDoc(doc(db, `negocios/${ANA}/pagos/p1`), { anulado: true }));
  });

  test('no puede crear un cobro ya anulado', async () => {
    await assertFails(setDoc(doc(dbDe(BETO), `negocios/${ANA}/pagos/p3`), { numero: 3, monto: 100, anulado: true }));
  });

  test('no cambia precios del catálogo ni crea productos', async () => {
    const db = dbDe(BETO);
    await assertFails(updateDoc(doc(db, `negocios/${ANA}/productos/pr1`), { precio: 1 }));
    await assertFails(setDoc(doc(db, `negocios/${ANA}/productos/pr2`), { nombre: 'X', precio: 1, stock: 0 }));
  });

  test('no puede cambiarse el rol a sí mismo', async () => {
    await assertFails(updateDoc(doc(dbDe(BETO), `negocios/${ANA}/miembros/${BETO}`), { rol: 'admin' }));
    await assertFails(updateDoc(doc(dbDe(BETO), `negocios/${ANA}/miembros/${BETO}`), { rol: 'owner' }));
  });

  test('puede irse del negocio', async () => {
    await assertSucceeds(deleteDoc(doc(dbDe(BETO), `negocios/${ANA}/miembros/${BETO}`)));
  });
});

describe('Gestión del equipo', () => {
  const DIEGO = 'diego';

  beforeEach(async () => {
    await crearNegocio(ANA);
    await comoAdmin(async (db) => {
      await setDoc(doc(db, `negocios/${ANA}/miembros/${BETO}`), { rol: 'admin' });
      await setDoc(doc(db, `negocios/${ANA}/miembros/${DIEGO}`), { rol: 'empleado' });
    });
  });

  test('el dueño cambia roles entre admin y empleado, nunca a dueño', async () => {
    const db = dbDe(ANA);
    await assertSucceeds(updateDoc(doc(db, `negocios/${ANA}/miembros/${DIEGO}`), { rol: 'admin' }));
    await assertFails(updateDoc(doc(db, `negocios/${ANA}/miembros/${DIEGO}`), { rol: 'owner' }));
  });

  test('un admin no cambia roles', async () => {
    await assertFails(updateDoc(doc(dbDe(BETO), `negocios/${ANA}/miembros/${DIEGO}`), { rol: 'admin' }));
  });

  test('un admin quita empleados pero no a otros admins ni al dueño', async () => {
    const db = dbDe(BETO);
    await comoAdmin((d) => setDoc(doc(d, `negocios/${ANA}/miembros/otroadmin`), { rol: 'admin' }));
    await assertFails(deleteDoc(doc(db, `negocios/${ANA}/miembros/otroadmin`)));
    await assertFails(deleteDoc(doc(db, `negocios/${ANA}/miembros/${ANA}`)));
    await assertSucceeds(deleteDoc(doc(db, `negocios/${ANA}/miembros/${DIEGO}`)));
  });

  test('el dueño no puede quitarse a sí mismo', async () => {
    await assertFails(deleteDoc(doc(dbDe(ANA), `negocios/${ANA}/miembros/${ANA}`)));
  });

  test('un miembro quitado pierde el acceso', async () => {
    await comoAdmin((db) => deleteDoc(doc(db, `negocios/${ANA}/miembros/${DIEGO}`)));
    await assertFails(getDoc(doc(dbDe(DIEGO), `negocios/${ANA}`)));
  });
});

describe('Planes, prueba gratis y vencimiento', () => {
  const enDias = (d) => new Date(Date.now() + d * 24 * 3600 * 1000);

  async function crearCon(uid, extra) {
    const db = dbDe(uid);
    const batch = writeBatch(db);
    batch.set(doc(db, `negocios/${uid}`), { nombre: 'Lubri', rubro: 'lubricentro', ownerUid: uid, ...extra });
    batch.set(doc(db, `negocios/${uid}/miembros/${uid}`), { rol: 'owner', email: `${uid}@x.com` });
    return batch.commit();
  }

  test('un negocio nuevo puede nacer con 15 días de prueba PRO', async () => {
    await assertSucceeds(crearCon(ANA, { plan: 'pro', prueba: true, planVence: enDias(15) }));
  });

  test('no puede darse una prueba más larga, ni un plan pago sin pagar', async () => {
    await assertFails(crearCon(ANA, { plan: 'pro', prueba: true, planVence: enDias(60) }));
    await assertFails(crearCon(BETO, { plan: 'pro', prueba: false, planVence: enDias(10) }));
    await assertFails(crearCon('carlos', { plan: 'basico', prueba: true, planVence: enDias(10) }));
  });

  test('el dueño no puede extender la prueba ni quitarle la marca', async () => {
    await crearCon(ANA, { plan: 'pro', prueba: true, planVence: enDias(15) });
    const ref = doc(dbDe(ANA), `negocios/${ANA}`);
    await assertFails(updateDoc(ref, { planVence: enDias(30) }));
    await assertFails(updateDoc(ref, { prueba: false }));
  });
});

describe('Facturación electrónica', () => {
  const fiscal = {
    razonSocial: 'Lubricentro Demo SRL',
    cuit: '33693450239',
    condicionIva: 'responsable_inscripto',
    domicilio: 'Av. Siempre Viva 123',
    ingresosBrutos: '',
    inicioActividades: '',
    puntoVenta: 3,
    alicuotaIva: 21,
    ambiente: 'homologacion',
    concepto: 3,
  };

  beforeEach(async () => {
    await crearNegocio(ANA);
    await comoAdmin(async (db) => {
      await setDoc(doc(db, `negocios/${ANA}/miembros/${BETO}`), { rol: 'empleado' });
      await setDoc(doc(db, `negocios/${ANA}/privado/arca_homologacion`), { claveCifrada: 'v1:xxx' });
      await setDoc(doc(db, `negocios/${ANA}/facturas/f1`), { estado: 'autorizada', numero: 1 });
      await setDoc(doc(db, `negocios/${ANA}/meta/arca`), { homologacion: { estado: 'listo' } });
      await setDoc(doc(db, `negocios/${ANA}/ordenes/o1`), { numero: 1, total: 100, pagado: 0, facturaId: 'f1' });
      await setDoc(doc(db, `negocios/${ANA}/ordenes/o2`), { numero: 2, total: 100, pagado: 0 });
    });
  });

  test('el dueño carga datos fiscales válidos', async () => {
    await assertSucceeds(setDoc(doc(dbDe(ANA), `negocios/${ANA}/meta/fiscal`), fiscal));
  });

  test('datos fiscales inválidos se rechazan', async () => {
    const ref = doc(dbDe(ANA), `negocios/${ANA}/meta/fiscal`);
    await assertFails(setDoc(ref, { ...fiscal, cuit: '33-69345023-9' }));
    await assertFails(setDoc(ref, { ...fiscal, puntoVenta: 0 }));
    await assertFails(setDoc(ref, { ...fiscal, alicuotaIva: 19 }));
    await assertFails(setDoc(ref, { ...fiscal, ambiente: 'otro' }));
  });

  test('un empleado ve los datos fiscales pero no los cambia', async () => {
    await comoAdmin((db) => setDoc(doc(db, `negocios/${ANA}/meta/fiscal`), fiscal));
    await assertSucceeds(getDoc(doc(dbDe(BETO), `negocios/${ANA}/meta/fiscal`)));
    await assertFails(setDoc(doc(dbDe(BETO), `negocios/${ANA}/meta/fiscal`), fiscal));
  });

  test('las claves y certificados son inaccesibles, incluso para el dueño', async () => {
    const ref = doc(dbDe(ANA), `negocios/${ANA}/privado/arca_homologacion`);
    await assertFails(getDoc(ref));
    await assertFails(setDoc(ref, { claveCifrada: 'robada' }));
  });

  test('el estado de ARCA y las facturas sólo los escribe el servidor', async () => {
    const db = dbDe(ANA);
    await assertSucceeds(getDoc(doc(db, `negocios/${ANA}/meta/arca`)));
    await assertFails(setDoc(doc(db, `negocios/${ANA}/meta/arca`), { homologacion: { estado: 'listo' } }));
    await assertSucceeds(getDoc(doc(db, `negocios/${ANA}/facturas/f1`)));
    await assertFails(setDoc(doc(db, `negocios/${ANA}/facturas/f2`), { estado: 'autorizada', cae: '123' }));
    await assertFails(updateDoc(doc(db, `negocios/${ANA}/facturas/f1`), { estado: 'rechazada' }));
  });

  test('la app no puede marcar ni desmarcar un trabajo como facturado', async () => {
    const db = dbDe(ANA);
    await assertFails(updateDoc(doc(db, `negocios/${ANA}/ordenes/o2`), { facturaId: 'trucha' }));
    await assertFails(setDoc(doc(db, `negocios/${ANA}/ordenes/o1`), { numero: 1, total: 100, pagado: 0 }));
    // Editar el trabajo conservando la factura está permitido.
    await assertSucceeds(setDoc(doc(db, `negocios/${ANA}/ordenes/o1`), { numero: 1, total: 120, pagado: 0, facturaId: 'f1' }));
  });

  test('un cobro no puede crearse ya facturado', async () => {
    await assertFails(setDoc(doc(dbDe(ANA), `negocios/${ANA}/pagos/p9`), { numero: 9, monto: 10, anulado: false, facturaId: 'x' }));
  });

  test('otro negocio no ve las facturas', async () => {
    await assertFails(getDoc(doc(dbDe('intruso'), `negocios/${ANA}/facturas/f1`)));
  });
});

describe('Administrador de la plataforma', () => {
  const JEFE = 'jefe';
  const dbJefe = () => env.authenticatedContext(JEFE, { superadmin: true, email: 'jefe@x.com' }).firestore();

  beforeEach(async () => {
    await crearNegocio(ANA);
    await comoAdmin(async (db) => {
      await setDoc(doc(db, `negocios/${ANA}/clientes/c1`), { nombre: 'Cliente privado' });
      await setDoc(doc(db, 'auditoriaPlanes/a1'), { negocioId: ANA, accion: 'activar' });
    });
  });

  test('ve todos los negocios, sus miembros y la auditoría', async () => {
    const db = dbJefe();
    await assertSucceeds(getDoc(doc(db, `negocios/${ANA}`)));
    await assertSucceeds(getDoc(doc(db, `negocios/${ANA}/miembros/${ANA}`)));
    await assertSucceeds(getDoc(doc(db, 'auditoriaPlanes/a1')));
  });

  test('no ve los datos internos de los negocios (privacidad)', async () => {
    await assertFails(getDoc(doc(dbJefe(), `negocios/${ANA}/clientes/c1`)));
  });

  /** Cambio de plan como lo hace la app: negocio + auditoría en un lote. */
  function cambiarPlan(db, { id = 'r1', negocio = {}, registro = {}, sinRegistro = false } = {}) {
    const vence = Timestamp.fromDate(new Date(Date.now() + 30 * 24 * 3600 * 1000));
    const batch = writeBatch(db);
    batch.update(doc(db, `negocios/${ANA}`), {
      plan: 'pro', planVence: vence, prueba: false, planActualizado: serverTimestamp(), planAuditoria: id, ...negocio,
    });
    if (!sinRegistro) {
      batch.set(doc(db, `auditoriaPlanes/${id}`), {
        negocioId: ANA, negocioNombre: 'Taller', accion: 'activar', planAnterior: 'free', venceAnterior: null,
        planNuevo: 'pro', venceNuevo: vence, monto: 30000, nota: '', porUid: JEFE, porEmail: 'jefe@x.com',
        fecha: serverTimestamp(), ...registro,
      });
    }
    return batch.commit();
  }

  test('cambia el plan dejando el registro de auditoría', async () => {
    await assertSucceeds(cambiarPlan(dbJefe()));
    await assertSucceeds(cambiarPlan(dbJefe(), {
      id: 'r2',
      negocio: { plan: 'free', planVence: deleteField() },
      registro: { accion: 'gratis', planNuevo: 'free', venceNuevo: null, monto: null },
    }));
  });

  test('sin auditoría, o con una auditoría falsa o reutilizada, no puede', async () => {
    const db = dbJefe();
    await assertFails(updateDoc(doc(db, `negocios/${ANA}`), { plan: 'pro' }));
    await assertFails(cambiarPlan(db, { sinRegistro: true }));
    await assertFails(cambiarPlan(db, { id: 'a1', sinRegistro: true })); // registro viejo
    await assertFails(cambiarPlan(db, { registro: { porEmail: 'otro@x.com' } }));
    await assertFails(cambiarPlan(db, { registro: { planNuevo: 'basico' } }));
    await assertFails(cambiarPlan(db, { registro: { monto: -5 } }));
    await assertFails(setDoc(doc(db, 'auditoriaPlanes/a2'), { negocioId: ANA }));
  });

  test('sólo toca el plan, con valores coherentes', async () => {
    const db = dbJefe();
    await assertFails(cambiarPlan(db, { negocio: { nombre: 'Otro' } }));
    await assertFails(cambiarPlan(db, { negocio: { ownerUid: JEFE } }));
    await assertFails(cambiarPlan(db, { negocio: { plan: 'enterprise' } }));
    await assertFails(cambiarPlan(db, { negocio: { planVence: Timestamp.fromDate(new Date(2020, 0, 1)) } }));
    await assertFails(cambiarPlan(db, { negocio: { plan: 'basico', prueba: true }, registro: { planNuevo: 'basico' } }));
  });

  test('la auditoría no se edita ni se borra', async () => {
    await assertFails(updateDoc(doc(dbJefe(), 'auditoriaPlanes/a1'), { monto: 1 }));
    await assertFails(deleteDoc(doc(dbJefe(), 'auditoriaPlanes/a1')));
  });

  test('un usuario común no puede usar el mismo camino', async () => {
    const db = dbDe(ANA);
    const batch = writeBatch(db);
    batch.update(doc(db, `negocios/${ANA}`), { plan: 'pro', planAuditoria: 'x', planActualizado: serverTimestamp() });
    batch.set(doc(db, 'auditoriaPlanes/x'), { negocioId: ANA, accion: 'activar', planNuevo: 'pro', porUid: ANA });
    await assertFails(batch.commit());
  });

  test('un usuario común no ve la auditoría', async () => {
    await assertFails(getDoc(doc(dbDe(ANA), 'auditoriaPlanes/a1')));
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
