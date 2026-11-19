import { generateKeyPairSync } from 'node:crypto';
import forge from 'node-forge';

import { ErrorFiscal, cuitValido } from './comprobantes';

/**
 * Genera la clave privada (RSA 2048) y la solicitud de certificado (CSR)
 * con el formato que exige ARCA: C=AR, O=razón social, CN=alias,
 * serialNumber="CUIT nnnnnnnnnnn".
 *
 * La clave privada se genera en el servidor y nunca se envía a la app.
 */
export function generarClaveYCsr(p: { cuit: string; razonSocial: string; alias: string }): { clavePem: string; csrPem: string } {
  const cuit = p.cuit.replace(/\D/g, '');
  if (!cuitValido(cuit)) throw new ErrorFiscal('El CUIT no es válido.');
  const alias = p.alias.replace(/[^a-zA-Z0-9]/g, '').slice(0, 40) || 'workcontrol';

  const { privateKey } = generateKeyPairSync('rsa', {
    modulusLength: 2048,
    publicKeyEncoding: { type: 'spki', format: 'pem' },
    privateKeyEncoding: { type: 'pkcs1', format: 'pem' },
  });
  const clave = forge.pki.privateKeyFromPem(privateKey);
  const publica = forge.pki.setRsaPublicKey(clave.n, clave.e);

  const csr = forge.pki.createCertificationRequest();
  csr.publicKey = publica;
  csr.setSubject([
    { name: 'countryName', value: 'AR' },
    { name: 'organizationName', value: p.razonSocial.slice(0, 64) },
    { name: 'commonName', value: alias },
    { type: '2.5.4.5', value: `CUIT ${cuit}` }, // serialNumber
  ]);
  csr.sign(clave, forge.md.sha256.create());
  return { clavePem: privateKey, csrPem: forge.pki.certificationRequestToPem(csr) };
}

export interface DatosCertificado {
  cuit: string;
  vence: Date;
  desde: Date;
  emisor: string;
}

/** Lee el certificado entregado por ARCA y verifica que corresponda a la clave. */
export function leerCertificado(certPem: string, clavePem: string): DatosCertificado {
  let cert: forge.pki.Certificate;
  try {
    cert = forge.pki.certificateFromPem(normalizarPem(certPem));
  } catch {
    throw new ErrorFiscal('El texto pegado no es un certificado válido. Copiá el contenido completo del archivo .crt.');
  }
  const clave = forge.pki.privateKeyFromPem(clavePem);
  const publica = cert.publicKey as forge.pki.rsa.PublicKey;
  if (publica.n.compareTo(clave.n) !== 0) {
    throw new ErrorFiscal(
      'Este certificado no corresponde a la solicitud generada por el sistema. ' +
        'Verificá haber subido a ARCA la última solicitud descargada.',
    );
  }
  const serial = cert.subject.getField({ type: '2.5.4.5' })?.value as string | undefined;
  const cuit = (serial ?? '').replace(/\D/g, '');
  return {
    cuit,
    vence: cert.validity.notAfter,
    desde: cert.validity.notBefore,
    emisor: String(cert.issuer.getField('CN')?.value ?? ''),
  };
}

/** Acepta el certificado aunque se pegue con espacios o saltos de línea de Windows. */
export function normalizarPem(pem: string): string {
  const limpio = pem.replace(/\r/g, '').trim();
  const m = /-----BEGIN CERTIFICATE-----([\s\S]+?)-----END CERTIFICATE-----/.exec(limpio);
  if (!m) return limpio;
  const cuerpo = m[1].replace(/\s+/g, '').match(/.{1,64}/g)?.join('\n') ?? '';
  return `-----BEGIN CERTIFICATE-----\n${cuerpo}\n-----END CERTIFICATE-----\n`;
}
