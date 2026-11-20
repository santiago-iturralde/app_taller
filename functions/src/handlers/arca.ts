import { HttpsError } from 'firebase-functions/v2/https';

import { CondicionReceptor, Concepto } from '../arca/comprobantes';
import {
  emitirFactura,
  emitirNotaCredito,
  generarSolicitud,
  guardarCertificado,
  probarConexion,
  reintentarFactura,
} from '../arca/servicio';
import { Sesion, exigirMiembro, exigirPlanConFacturacion, exigirSesion, texto } from '../util/seguridad';

/**
 * Una acción que la app puede pedir. No depende de cómo se expone: la usan
 * tanto las Cloud Functions (index.ts) como el servidor HTTP (servidor.ts).
 * Recibe la sesión ya verificada (o null) y la clave maestra de cifrado.
 */
export type Accion = (datos: unknown, sesion: Sesion | null, claveMaestra: string) => Promise<unknown>;

const CONDICIONES: CondicionReceptor[] = ['responsable_inscripto', 'monotributo', 'exento', 'consumidor_final', 'no_categorizado'];

type Datos = Record<string, any>;

function comoDatos(datos: unknown): Datos {
  return datos && typeof datos === 'object' && !Array.isArray(datos) ? (datos as Datos) : {};
}

function negocioId(d: Datos): string {
  return texto(d.negocioId, 'el negocio', 128);
}

/** Paso 1 de la configuración: genera la solicitud de certificado (CSR). */
const arcaGenerarSolicitud: Accion = async (datos, sesion, clave) => {
  const { uid } = exigirSesion(sesion);
  const id = negocioId(comoDatos(datos));
  await exigirMiembro(id, uid, ['owner', 'admin']);
  await exigirPlanConFacturacion(id);
  return generarSolicitud(id, clave);
};

/** Paso 2: guarda el certificado que entregó ARCA. */
const arcaGuardarCertificado: Accion = async (datos, sesion, clave) => {
  const { uid } = exigirSesion(sesion);
  const d = comoDatos(datos);
  const id = negocioId(d);
  await exigirMiembro(id, uid, ['owner', 'admin']);
  await exigirPlanConFacturacion(id);
  return guardarCertificado(id, texto(d.certificado, 'el certificado', 20_000), clave);
};

/** Paso 3: prueba la conexión con ARCA. */
const arcaProbarConexion: Accion = async (datos, sesion, clave) => {
  const { uid } = exigirSesion(sesion);
  const id = negocioId(comoDatos(datos));
  await exigirMiembro(id, uid, ['owner', 'admin']);
  await exigirPlanConFacturacion(id);
  return probarConexion(id, clave);
};

/** Emite una factura de un trabajo o de un cobro. Cualquier miembro puede facturar. */
const arcaEmitirFactura: Accion = async (datos, sesion, clave) => {
  const { uid } = exigirSesion(sesion);
  const d = comoDatos(datos);
  const id = negocioId(d);
  await exigirMiembro(id, uid);
  await exigirPlanConFacturacion(id);

  const tipoOrigen = d.origen?.tipo;
  if (tipoOrigen !== 'orden' && tipoOrigen !== 'pago') throw new HttpsError('invalid-argument', 'Origen inválido.');
  const origenId = texto(d.origen?.id, 'el registro a facturar', 128);
  if (origenId.includes('/')) throw new HttpsError('invalid-argument', 'Origen inválido.');

  const r = d.receptor ?? {};
  const docTipo = r.docTipo;
  if (!['cuit', 'dni', 'consumidor_final'].includes(docTipo)) throw new HttpsError('invalid-argument', 'Tipo de documento inválido.');
  if (!CONDICIONES.includes(r.condicionIva)) throw new HttpsError('invalid-argument', 'Condición frente al IVA inválida.');
  const concepto = d.concepto === undefined ? undefined : Number(d.concepto);
  if (concepto !== undefined && ![1, 2, 3].includes(concepto)) throw new HttpsError('invalid-argument', 'Concepto inválido.');

  return emitirFactura(
    id,
    uid,
    {
      origen: { tipo: tipoOrigen, id: origenId },
      receptor: {
        nombre: texto(r.nombre, 'el nombre del cliente', 150),
        docTipo,
        docNro: String(r.docNro ?? ''),
        condicionIva: r.condicionIva,
      },
      concepto: concepto as Concepto | undefined,
    },
    clave,
  );
};

/** Verifica o reintenta un comprobante cuyo resultado quedó incierto. */
const arcaReintentar: Accion = async (datos, sesion, clave) => {
  const { uid } = exigirSesion(sesion);
  const d = comoDatos(datos);
  const id = negocioId(d);
  await exigirMiembro(id, uid);
  await exigirPlanConFacturacion(id);
  return reintentarFactura(id, texto(d.facturaId, 'la factura', 128), clave);
};

/** Anula una factura con su nota de crédito (sólo administradores). */
const arcaAnularFactura: Accion = async (datos, sesion, clave) => {
  const { uid } = exigirSesion(sesion);
  const d = comoDatos(datos);
  const id = negocioId(d);
  await exigirMiembro(id, uid, ['owner', 'admin']);
  await exigirPlanConFacturacion(id);
  return emitirNotaCredito(id, uid, texto(d.facturaId, 'la factura', 128), clave);
};

/** Todas las acciones de facturación, por nombre (el que usa la app). */
export const ACCIONES_ARCA = {
  arcaGenerarSolicitud,
  arcaGuardarCertificado,
  arcaProbarConexion,
  arcaEmitirFactura,
  arcaReintentar,
  arcaAnularFactura,
} satisfies Record<string, Accion>;
