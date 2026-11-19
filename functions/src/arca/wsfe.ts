import { postSoap } from './http';
import { Concepto, TipoComprobante } from './comprobantes';
import { Ambiente, TicketAcceso } from './wsaa';
import { ErrorArca, comoLista, parsearXml, sobreSoap, verificarFault } from './xml';

/** Facturación electrónica (WSFEv1) de ARCA. */

export const URL_WSFE: Record<Ambiente, string> = {
  homologacion: 'https://wswhomo.afip.gov.ar/wsfev1/service.asmx',
  produccion: 'https://servicios1.afip.gov.ar/wsfev1/service.asmx',
};

const NS = 'http://ar.gov.afip.dif.FEV1/';

export interface Credenciales extends TicketAcceso {
  cuit: string;
}

function auth(c: Credenciales): string {
  return `<ar:Auth><ar:Token>${c.token}</ar:Token><ar:Sign>${c.sign}</ar:Sign><ar:Cuit>${c.cuit.replace(/\D/g, '')}</ar:Cuit></ar:Auth>`;
}

const sobre = (cuerpo: string) => sobreSoap(cuerpo, { ar: NS });

/** Formatea importes con punto decimal y 2 decimales, como espera ARCA. */
export const importe = (n: number) => n.toFixed(2);

export interface ErrorWsfe {
  codigo: string;
  mensaje: string;
}

function errores(resultado: any): ErrorWsfe[] {
  return comoLista(resultado?.Errors?.Err).map((e: any) => ({ codigo: String(e.Code ?? ''), mensaje: String(e.Msg ?? '') }));
}

function lanzarSiHayErrores(resultado: any): void {
  const errs = errores(resultado);
  if (errs.length) throw new ErrorArca(errs.map((e) => `${e.codigo}: ${e.mensaje}`).join(' | '), errs[0].codigo);
}

// ------------------------------------------------------- Último autorizado

export function sobreUltimoAutorizado(c: Credenciales, puntoVenta: number, tipo: TipoComprobante): string {
  return sobre(`<ar:FECompUltimoAutorizado>${auth(c)}<ar:PtoVta>${puntoVenta}</ar:PtoVta><ar:CbteTipo>${tipo}</ar:CbteTipo></ar:FECompUltimoAutorizado>`);
}

export function parsearUltimoAutorizado(xml: string): number {
  const doc = parsearXml(xml);
  verificarFault(doc);
  const r = doc?.Envelope?.Body?.FECompUltimoAutorizadoResponse?.FECompUltimoAutorizadoResult;
  lanzarSiHayErrores(r);
  const nro = Number(r?.CbteNro);
  if (!Number.isInteger(nro)) throw new ErrorArca('ARCA no devolvió el último número autorizado.');
  return nro;
}

export async function ultimoAutorizado(amb: Ambiente, c: Credenciales, puntoVenta: number, tipo: TipoComprobante): Promise<number> {
  const xml = await postSoap(URL_WSFE[amb], `${NS}FECompUltimoAutorizado`, sobreUltimoAutorizado(c, puntoVenta, tipo));
  return parsearUltimoAutorizado(xml);
}

// ------------------------------------------------------------ Pedido de CAE

export interface PedidoCae {
  puntoVenta: number;
  tipo: TipoComprobante;
  numero: number;
  concepto: Concepto;
  docTipo: number;
  docNro: number;
  condicionIvaReceptorId: number;
  fecha: string; // AAAAMMDD
  total: number;
  neto: number;
  iva: number;
  alicuotaId: number | null;
  /** Comprobante asociado (obligatorio en notas de crédito). */
  asociado?: { tipo: TipoComprobante; puntoVenta: number; numero: number; cuit: string; fecha: string };
}

export function sobreSolicitarCae(c: Credenciales, p: PedidoCae): string {
  const servicios =
    p.concepto === 1
      ? ''
      : `<ar:FchServDesde>${p.fecha}</ar:FchServDesde><ar:FchServHasta>${p.fecha}</ar:FchServHasta><ar:FchVtoPago>${p.fecha}</ar:FchVtoPago>`;
  const asociados = p.asociado
    ? `<ar:CbtesAsoc><ar:CbteAsoc><ar:Tipo>${p.asociado.tipo}</ar:Tipo><ar:PtoVta>${p.asociado.puntoVenta}</ar:PtoVta>` +
      `<ar:Nro>${p.asociado.numero}</ar:Nro><ar:Cuit>${p.asociado.cuit.replace(/\D/g, '')}</ar:Cuit>` +
      `<ar:CbteFch>${p.asociado.fecha}</ar:CbteFch></ar:CbteAsoc></ar:CbtesAsoc>`
    : '';
  const iva =
    p.alicuotaId === null
      ? ''
      : `<ar:Iva><ar:AlicIva><ar:Id>${p.alicuotaId}</ar:Id><ar:BaseImp>${importe(p.neto)}</ar:BaseImp><ar:Importe>${importe(p.iva)}</ar:Importe></ar:AlicIva></ar:Iva>`;

  return sobre(
    `<ar:FECAESolicitar>${auth(c)}<ar:FeCAEReq>` +
      `<ar:FeCabReq><ar:CantReg>1</ar:CantReg><ar:PtoVta>${p.puntoVenta}</ar:PtoVta><ar:CbteTipo>${p.tipo}</ar:CbteTipo></ar:FeCabReq>` +
      '<ar:FeDetReq><ar:FECAEDetRequest>' +
      `<ar:Concepto>${p.concepto}</ar:Concepto>` +
      `<ar:DocTipo>${p.docTipo}</ar:DocTipo><ar:DocNro>${p.docNro}</ar:DocNro>` +
      `<ar:CbteDesde>${p.numero}</ar:CbteDesde><ar:CbteHasta>${p.numero}</ar:CbteHasta>` +
      `<ar:CbteFch>${p.fecha}</ar:CbteFch>` +
      `<ar:ImpTotal>${importe(p.total)}</ar:ImpTotal><ar:ImpTotConc>0.00</ar:ImpTotConc>` +
      `<ar:ImpNeto>${importe(p.neto)}</ar:ImpNeto><ar:ImpOpEx>0.00</ar:ImpOpEx>` +
      `<ar:ImpTrib>0.00</ar:ImpTrib><ar:ImpIVA>${importe(p.iva)}</ar:ImpIVA>` +
      servicios +
      '<ar:MonId>PES</ar:MonId><ar:MonCotiz>1</ar:MonCotiz>' +
      `<ar:CondicionIVAReceptorId>${p.condicionIvaReceptorId}</ar:CondicionIVAReceptorId>` +
      asociados +
      iva +
      '</ar:FECAEDetRequest></ar:FeDetReq></ar:FeCAEReq></ar:FECAESolicitar>',
  );
}

export type RespuestaCae =
  | { aprobado: true; cae: string; caeVence: string; observaciones: ErrorWsfe[] }
  | { aprobado: false; errores: ErrorWsfe[]; observaciones: ErrorWsfe[] };

export function parsearSolicitarCae(xml: string): RespuestaCae {
  const doc = parsearXml(xml);
  verificarFault(doc);
  const r = doc?.Envelope?.Body?.FECAESolicitarResponse?.FECAESolicitarResult;
  if (!r) throw new ErrorArca('Respuesta inesperada de ARCA al pedir el CAE.', undefined, true);
  const det = comoLista(r?.FeDetResp?.FECAEDetResponse)[0] as any;
  const observaciones = comoLista(det?.Observaciones?.Obs).map((o: any) => ({ codigo: String(o.Code ?? ''), mensaje: String(o.Msg ?? '') }));
  if (det?.Resultado === 'A' && det?.CAE) {
    return { aprobado: true, cae: String(det.CAE), caeVence: String(det.CAEFchVto), observaciones };
  }
  return { aprobado: false, errores: errores(r), observaciones };
}

export async function solicitarCae(amb: Ambiente, c: Credenciales, p: PedidoCae): Promise<RespuestaCae> {
  const xml = await postSoap(URL_WSFE[amb], `${NS}FECAESolicitar`, sobreSolicitarCae(c, p));
  return parsearSolicitarCae(xml);
}

// --------------------------------------------------- Consulta de comprobante

export function sobreConsultar(c: Credenciales, puntoVenta: number, tipo: TipoComprobante, numero: number): string {
  return sobre(
    `<ar:FECompConsultar>${auth(c)}<ar:FeCompConsReq><ar:CbteTipo>${tipo}</ar:CbteTipo>` +
      `<ar:CbteNro>${numero}</ar:CbteNro><ar:PtoVta>${puntoVenta}</ar:PtoVta></ar:FeCompConsReq></ar:FECompConsultar>`,
  );
}

export interface ComprobanteConsultado {
  cae: string;
  caeVence: string;
  total: number;
  docNro: number;
  fecha: string;
}

/** Devuelve el comprobante, o null si ARCA indica que no existe. */
export function parsearConsultar(xml: string): ComprobanteConsultado | null {
  const doc = parsearXml(xml);
  verificarFault(doc);
  const r = doc?.Envelope?.Body?.FECompConsultarResponse?.FECompConsultarResult;
  const errs = errores(r);
  // 602: "No existen datos en nuestros registros para los parámetros ingresados".
  if (errs.some((e) => e.codigo === '602')) return null;
  if (errs.length) throw new ErrorArca(errs.map((e) => `${e.codigo}: ${e.mensaje}`).join(' | '), errs[0].codigo);
  const g = r?.ResultGet;
  if (!g?.CodAutorizacion) return null;
  return {
    cae: String(g.CodAutorizacion),
    caeVence: String(g.FchVto),
    total: Number(g.ImpTotal),
    docNro: Number(g.DocNro),
    fecha: String(g.CbteFch),
  };
}

export async function consultarComprobante(
  amb: Ambiente,
  c: Credenciales,
  puntoVenta: number,
  tipo: TipoComprobante,
  numero: number,
): Promise<ComprobanteConsultado | null> {
  const xml = await postSoap(URL_WSFE[amb], `${NS}FECompConsultar`, sobreConsultar(c, puntoVenta, tipo, numero));
  return parsearConsultar(xml);
}

// ------------------------------------------------------- Estado del servicio

export async function estadoServidores(amb: Ambiente): Promise<{ app: string; db: string; auth: string }> {
  const xml = await postSoap(URL_WSFE[amb], `${NS}FEDummy`, sobre('<ar:FEDummy/>'));
  const doc = parsearXml(xml);
  verificarFault(doc);
  const r = doc?.Envelope?.Body?.FEDummyResponse?.FEDummyResult ?? {};
  return { app: String(r.AppServer ?? ''), db: String(r.DbServer ?? ''), auth: String(r.AuthServer ?? '') };
}
