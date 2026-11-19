import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';

import { CondicionReceptor, Concepto } from '../arca/comprobantes';
import {
  emitirFactura,
  emitirNotaCredito,
  generarSolicitud,
  guardarCertificado,
  probarConexion,
  reintentarFactura,
} from '../arca/servicio';
import { exigirMiembro, exigirPlanConFacturacion, texto, usuario } from '../util/seguridad';
import { REGION } from '../config';

/**
 * Clave maestra para cifrar claves privadas y tickets de ARCA.
 * Se configura una sola vez: firebase functions:secrets:set ARCA_CLAVE_MAESTRA
 */
const claveMaestra = defineSecret('ARCA_CLAVE_MAESTRA');

const opciones = { region: REGION, secrets: [claveMaestra], timeoutSeconds: 120, memory: '512MiB' as const };

const CONDICIONES: CondicionReceptor[] = ['responsable_inscripto', 'monotributo', 'exento', 'consumidor_final', 'no_categorizado'];

interface ConNegocio {
  negocioId?: unknown;
}

function negocioId(data: ConNegocio): string {
  return texto(data?.negocioId, 'el negocio', 128);
}

/** Paso 1 de la configuración: genera la solicitud de certificado (CSR). */
export const arcaGenerarSolicitud = onCall(opciones, async (req) => {
  const { uid } = usuario(req);
  const id = negocioId(req.data as ConNegocio);
  await exigirMiembro(id, uid, ['owner', 'admin']);
  await exigirPlanConFacturacion(id);
  return generarSolicitud(id, claveMaestra.value());
});

/** Paso 2: guarda el certificado que entregó ARCA. */
export const arcaGuardarCertificado = onCall(opciones, async (req) => {
  const { uid } = usuario(req);
  const data = req.data as ConNegocio & { certificado?: unknown };
  const id = negocioId(data);
  await exigirMiembro(id, uid, ['owner', 'admin']);
  await exigirPlanConFacturacion(id);
  const certificado = texto(data.certificado, 'el certificado', 20_000);
  return guardarCertificado(id, certificado, claveMaestra.value());
});

/** Paso 3: prueba la conexión con ARCA. */
export const arcaProbarConexion = onCall(opciones, async (req) => {
  const { uid } = usuario(req);
  const id = negocioId(req.data as ConNegocio);
  await exigirMiembro(id, uid, ['owner', 'admin']);
  await exigirPlanConFacturacion(id);
  return probarConexion(id, claveMaestra.value());
});

/** Emite una factura de un trabajo o de un cobro. Cualquier miembro puede facturar. */
export const arcaEmitirFactura = onCall(opciones, async (req) => {
  const { uid } = usuario(req);
  const data = req.data as ConNegocio & { origen?: any; receptor?: any; concepto?: unknown };
  const id = negocioId(data);
  await exigirMiembro(id, uid);
  await exigirPlanConFacturacion(id);

  const tipoOrigen = data.origen?.tipo;
  if (tipoOrigen !== 'orden' && tipoOrigen !== 'pago') throw new HttpsError('invalid-argument', 'Origen inválido.');
  const origenId = texto(data.origen?.id, 'el registro a facturar', 128);
  if (origenId.includes('/')) throw new HttpsError('invalid-argument', 'Origen inválido.');

  const r = data.receptor ?? {};
  const docTipo = r.docTipo;
  if (!['cuit', 'dni', 'consumidor_final'].includes(docTipo)) throw new HttpsError('invalid-argument', 'Tipo de documento inválido.');
  if (!CONDICIONES.includes(r.condicionIva)) throw new HttpsError('invalid-argument', 'Condición frente al IVA inválida.');
  const concepto = data.concepto === undefined ? undefined : Number(data.concepto);
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
    claveMaestra.value(),
  );
});

/** Verifica o reintenta un comprobante cuyo resultado quedó incierto. */
export const arcaReintentar = onCall(opciones, async (req) => {
  const { uid } = usuario(req);
  const data = req.data as ConNegocio & { facturaId?: unknown };
  const id = negocioId(data);
  await exigirMiembro(id, uid);
  await exigirPlanConFacturacion(id);
  return reintentarFactura(id, texto(data.facturaId, 'la factura', 128), claveMaestra.value());
});

/** Anula una factura con su nota de crédito (sólo administradores). */
export const arcaAnularFactura = onCall(opciones, async (req) => {
  const { uid } = usuario(req);
  const data = req.data as ConNegocio & { facturaId?: unknown };
  const id = negocioId(data);
  await exigirMiembro(id, uid, ['owner', 'admin']);
  await exigirPlanConFacturacion(id);
  return emitirNotaCredito(id, uid, texto(data.facturaId, 'la factura', 128), claveMaestra.value());
});
