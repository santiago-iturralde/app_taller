/**
 * Reglas fiscales de comprobantes (funciones puras, sin red ni base de datos).
 *
 * Referencias: manual del desarrollador WSFEv1 de ARCA, RG 4291 (alícuotas),
 * RG 5616 (condición frente al IVA del receptor obligatoria).
 */

export type CondicionEmisor = 'responsable_inscripto' | 'monotributo' | 'exento';

export type CondicionReceptor =
  | 'responsable_inscripto'
  | 'monotributo'
  | 'exento'
  | 'consumidor_final'
  | 'no_categorizado';

/** Códigos de condición frente al IVA del receptor (campo CondicionIVAReceptorId). */
export const ID_CONDICION_RECEPTOR: Record<CondicionReceptor, number> = {
  responsable_inscripto: 1,
  exento: 4,
  consumidor_final: 5,
  monotributo: 6,
  no_categorizado: 7,
};

export enum TipoComprobante {
  FacturaA = 1,
  NotaCreditoA = 3,
  FacturaB = 6,
  NotaCreditoB = 8,
  FacturaC = 11,
  NotaCreditoC = 13,
}

export const LETRA: Record<TipoComprobante, 'A' | 'B' | 'C'> = {
  [TipoComprobante.FacturaA]: 'A',
  [TipoComprobante.NotaCreditoA]: 'A',
  [TipoComprobante.FacturaB]: 'B',
  [TipoComprobante.NotaCreditoB]: 'B',
  [TipoComprobante.FacturaC]: 'C',
  [TipoComprobante.NotaCreditoC]: 'C',
};

export const ES_NOTA_CREDITO = (t: TipoComprobante) =>
  t === TipoComprobante.NotaCreditoA || t === TipoComprobante.NotaCreditoB || t === TipoComprobante.NotaCreditoC;

/** Tipos de documento del receptor. */
export const DOC_TIPO = { cuit: 80, cuil: 86, dni: 96, consumidorFinal: 99 } as const;

/** Concepto: 1 productos, 2 servicios, 3 productos y servicios. */
export type Concepto = 1 | 2 | 3;

/** ID de alícuota de IVA según ARCA. */
export const ID_ALICUOTA: Record<string, number> = { '0': 3, '2.5': 9, '5': 8, '10.5': 4, '21': 5, '27': 6 };

export class ErrorFiscal extends Error {}

/** Elige el tipo de comprobante según las condiciones de emisor y receptor. */
export function determinarTipo(emisor: CondicionEmisor, receptor: CondicionReceptor, notaCredito = false): TipoComprobante {
  if (emisor === 'monotributo' || emisor === 'exento') {
    return notaCredito ? TipoComprobante.NotaCreditoC : TipoComprobante.FacturaC;
  }
  const esA = receptor === 'responsable_inscripto' || receptor === 'monotributo';
  if (esA) return notaCredito ? TipoComprobante.NotaCreditoA : TipoComprobante.FacturaA;
  return notaCredito ? TipoComprobante.NotaCreditoB : TipoComprobante.FacturaB;
}

/** Nota de crédito que corresponde a una factura. */
export function notaCreditoDe(tipo: TipoComprobante): TipoComprobante {
  switch (tipo) {
    case TipoComprobante.FacturaA:
      return TipoComprobante.NotaCreditoA;
    case TipoComprobante.FacturaB:
      return TipoComprobante.NotaCreditoB;
    case TipoComprobante.FacturaC:
      return TipoComprobante.NotaCreditoC;
    default:
      throw new ErrorFiscal('Sólo se puede emitir una nota de crédito sobre una factura.');
  }
}

export const redondear = (n: number) => Math.round((n + Number.EPSILON) * 100) / 100;

export interface Linea {
  descripcion: string;
  cantidad: number;
  precioUnitario: number;
}

export interface Importes {
  total: number;
  neto: number;
  iva: number;
  /** Alícuota usada (en %), o null si el comprobante no discrimina IVA (C). */
  alicuota: number | null;
  alicuotaId: number | null;
}

/**
 * Calcula los importes a informar. Los precios del sistema son precios
 * finales (IVA incluido), que es como cobra un comercio al público.
 */
export function calcularImportes(lineas: Linea[], tipo: TipoComprobante, alicuotaPct: number): Importes {
  const total = redondear(lineas.reduce((s, l) => s + redondear(l.cantidad * l.precioUnitario), 0));
  if (total <= 0) throw new ErrorFiscal('El comprobante tiene que tener un importe mayor a cero.');

  if (LETRA[tipo] === 'C') {
    return { total, neto: total, iva: 0, alicuota: null, alicuotaId: null };
  }
  const alicuotaId = ID_ALICUOTA[String(alicuotaPct)];
  if (alicuotaId === undefined) throw new ErrorFiscal(`Alícuota de IVA no válida: ${alicuotaPct}%.`);
  const neto = redondear(total / (1 + alicuotaPct / 100));
  // El IVA se obtiene por diferencia para que neto + IVA = total exacto.
  const iva = redondear(total - neto);
  return { total, neto, iva, alicuota: alicuotaPct, alicuotaId };
}

/** Valida un CUIT/CUIL con su dígito verificador. */
export function cuitValido(cuit: string): boolean {
  const d = cuit.replace(/\D/g, '');
  if (d.length !== 11) return false;
  const pesos = [5, 4, 3, 2, 7, 6, 5, 4, 3, 2];
  const suma = pesos.reduce((s, p, i) => s + p * Number(d[i]), 0);
  let verificador = 11 - (suma % 11);
  if (verificador === 11) verificador = 0;
  if (verificador === 10) return false;
  return verificador === Number(d[10]);
}

export interface Receptor {
  nombre: string;
  docTipo: 'cuit' | 'dni' | 'consumidor_final';
  docNro: string;
  condicionIva: CondicionReceptor;
}

/** Normaliza y valida los datos del receptor para el tipo de comprobante. */
export function prepararReceptor(r: Receptor, tipo: TipoComprobante): { docTipo: number; docNro: number; condicionId: number } {
  const nro = r.docNro.replace(/\D/g, '');
  if (LETRA[tipo] === 'A') {
    if (r.docTipo !== 'cuit' || !cuitValido(nro)) {
      throw new ErrorFiscal('Para una factura A el cliente tiene que tener un CUIT válido.');
    }
  }
  if (r.docTipo === 'cuit') {
    if (!cuitValido(nro)) throw new ErrorFiscal('El CUIT del cliente no es válido.');
    return { docTipo: DOC_TIPO.cuit, docNro: Number(nro), condicionId: ID_CONDICION_RECEPTOR[r.condicionIva] };
  }
  if (r.docTipo === 'dni') {
    if (nro.length < 7 || nro.length > 8) throw new ErrorFiscal('El DNI del cliente no es válido.');
    return { docTipo: DOC_TIPO.dni, docNro: Number(nro), condicionId: ID_CONDICION_RECEPTOR[r.condicionIva] };
  }
  return { docTipo: DOC_TIPO.consumidorFinal, docNro: 0, condicionId: ID_CONDICION_RECEPTOR.consumidor_final };
}

/** Fecha en formato AAAAMMDD en hora argentina (UTC-3, sin horario de verano). */
export function fechaArca(d: Date): string {
  const ar = new Date(d.getTime() - 3 * 3600 * 1000);
  return ar.toISOString().slice(0, 10).replace(/-/g, '');
}

/** AAAAMMDD → Date (mediodía argentino, para evitar saltos de día). */
export function desdeFechaArca(s: string): Date {
  const m = /^(\d{4})(\d{2})(\d{2})$/.exec(s);
  if (!m) throw new Error(`Fecha de ARCA inválida: ${s}`);
  return new Date(Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3]), 15));
}

/**
 * URL del código QR obligatorio (RG 4892). El JSON se codifica en base64.
 */
export function urlQr(p: {
  fecha: Date;
  cuit: string;
  puntoVenta: number;
  tipo: TipoComprobante;
  numero: number;
  importe: number;
  docTipo: number;
  docNro: number;
  cae: string;
}): string {
  const fechaIso = fechaArca(p.fecha).replace(/^(\d{4})(\d{2})(\d{2})$/, '$1-$2-$3');
  const datos = {
    ver: 1,
    fecha: fechaIso,
    cuit: Number(p.cuit.replace(/\D/g, '')),
    ptoVta: p.puntoVenta,
    tipoCmp: p.tipo,
    nroCmp: p.numero,
    importe: p.importe,
    moneda: 'PES',
    ctz: 1,
    tipoDocRec: p.docTipo,
    nroDocRec: p.docNro,
    tipoCodAut: 'E',
    codAut: Number(p.cae),
  };
  return `https://www.afip.gob.ar/fe/qr/?p=${Buffer.from(JSON.stringify(datos)).toString('base64')}`;
}
