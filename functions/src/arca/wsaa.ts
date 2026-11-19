import forge from 'node-forge';

import { postSoap } from './http';
import { ErrorArca, escaparXml, parsearXml, sobreSoap, verificarFault } from './xml';

export type Ambiente = 'homologacion' | 'produccion';

export const URL_WSAA: Record<Ambiente, string> = {
  homologacion: 'https://wsaahomo.afip.gov.ar/ws/services/LoginCms',
  produccion: 'https://wsaa.afip.gov.ar/ws/services/LoginCms',
};

/** Ticket de acceso: autoriza a usar un servicio de ARCA durante ~12 horas. */
export interface TicketAcceso {
  token: string;
  sign: string;
  vence: string; // ISO
}

/** Arma el "Ticket de Requerimiento de Acceso" (TRA). */
export function construirTRA(servicio: string, ahora: Date): string {
  const desde = new Date(ahora.getTime() - 10 * 60 * 1000).toISOString();
  const hasta = new Date(ahora.getTime() + 10 * 60 * 1000).toISOString();
  return (
    '<?xml version="1.0" encoding="UTF-8"?>' +
    '<loginTicketRequest version="1.0"><header>' +
    `<uniqueId>${Math.floor(ahora.getTime() / 1000)}</uniqueId>` +
    `<generationTime>${desde}</generationTime>` +
    `<expirationTime>${hasta}</expirationTime>` +
    `</header><service>${escaparXml(servicio)}</service></loginTicketRequest>`
  );
}

/** Firma el TRA en formato CMS/PKCS#7 (con contenido incluido) y lo devuelve en base64. */
export function firmarTRA(tra: string, certPem: string, clavePem: string): string {
  const cert = forge.pki.certificateFromPem(certPem);
  const clave = forge.pki.privateKeyFromPem(clavePem);
  const p7 = forge.pkcs7.createSignedData();
  p7.content = forge.util.createBuffer(tra, 'utf8');
  p7.addCertificate(cert);
  p7.addSigner({
    key: clave,
    certificate: cert,
    digestAlgorithm: forge.pki.oids.sha256,
    authenticatedAttributes: [
      { type: forge.pki.oids.contentType, value: forge.pki.oids.data },
      { type: forge.pki.oids.messageDigest },
      { type: forge.pki.oids.signingTime, value: new Date() as unknown as string },
    ],
  });
  p7.sign();
  return forge.util.encode64(forge.asn1.toDer(p7.toAsn1()).getBytes());
}

export function sobreLoginCms(cmsBase64: string): string {
  return sobreSoap(`<wsaa:loginCms><wsaa:in0>${cmsBase64}</wsaa:in0></wsaa:loginCms>`, {
    wsaa: 'http://wsaa.view.sua.dvadac.desein.afip.gov',
  });
}

/** Extrae token, sign y vencimiento de la respuesta de loginCms. */
export function parsearLoginCms(xml: string): TicketAcceso {
  const doc = parsearXml(xml);
  verificarFault(doc);
  const interno = doc?.Envelope?.Body?.loginCmsResponse?.loginCmsReturn;
  if (!interno) throw new ErrorArca('Respuesta inesperada del servicio de autenticación de ARCA.');
  const ticket = parsearXml(String(interno))?.loginTicketResponse;
  const token = ticket?.credentials?.token;
  const sign = ticket?.credentials?.sign;
  const vence = ticket?.header?.expirationTime;
  if (!token || !sign || !vence) throw new ErrorArca('ARCA no devolvió las credenciales de acceso.');
  return { token: String(token), sign: String(sign), vence: new Date(String(vence)).toISOString() };
}

/** true si el ticket sigue vigente con un margen de seguridad. */
export function ticketVigente(t: TicketAcceso | undefined | null, ahora = new Date()): t is TicketAcceso {
  return !!t && new Date(t.vence).getTime() - ahora.getTime() > 10 * 60 * 1000;
}

/** Pide un nuevo ticket de acceso a ARCA. */
export async function solicitarTicket(p: {
  ambiente: Ambiente;
  servicio: string;
  certPem: string;
  clavePem: string;
}): Promise<TicketAcceso> {
  const cms = firmarTRA(construirTRA(p.servicio, new Date()), p.certPem, p.clavePem);
  const respuesta = await postSoap(URL_WSAA[p.ambiente], '', sobreLoginCms(cms));
  try {
    return parsearLoginCms(respuesta);
  } catch (e) {
    if (e instanceof ErrorArca && /ya posee un TA valido/i.test(e.message)) {
      throw new ErrorArca(
        'ARCA indica que ya hay un acceso vigente para este certificado (puede estar en uso en otro sistema). ' +
          'Esperá unos minutos y volvé a intentar.',
        'ta_vigente',
      );
    }
    throw e;
  }
}
