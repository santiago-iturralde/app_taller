import https from 'node:https';

import { ErrorArca } from './xml';

/**
 * Los servidores de ARCA usan parámetros TLS que Node rechaza por defecto
 * ("dh key too small"). Se baja el nivel de seguridad de cifrado sólo para
 * estas conexiones, manteniendo TLS 1.2 como mínimo y la validación del
 * certificado del servidor.
 */
const agente = new https.Agent({
  keepAlive: true,
  minVersion: 'TLSv1.2',
  ciphers: 'DEFAULT@SECLEVEL=1',
});

/** Hace un POST SOAP y devuelve el cuerpo de la respuesta como texto. */
export function postSoap(url: string, soapAction: string, cuerpo: string, timeoutMs = 25000): Promise<string> {
  return new Promise((resolve, reject) => {
    const req = https.request(
      url,
      {
        method: 'POST',
        agent: agente,
        timeout: timeoutMs,
        headers: {
          'Content-Type': 'text/xml; charset=utf-8',
          SOAPAction: `"${soapAction}"`,
          'Content-Length': Buffer.byteLength(cuerpo, 'utf8'),
        },
      },
      (res) => {
        const partes: Buffer[] = [];
        res.on('data', (c: Buffer) => partes.push(c));
        res.on('end', () => {
          const texto = Buffer.concat(partes).toString('utf8');
          // Los SOAP Fault llegan con estado 500 pero con cuerpo XML válido.
          if (res.statusCode && res.statusCode >= 200 && res.statusCode < 300) return resolve(texto);
          if (res.statusCode === 500 && texto.includes('Fault')) return resolve(texto);
          reject(new ErrorArca(`ARCA respondió con estado ${res.statusCode}.`, String(res.statusCode), true));
        });
      },
    );
    req.on('timeout', () => req.destroy(new ErrorArca('ARCA no respondió a tiempo.', 'timeout', true)));
    req.on('error', (e) =>
      reject(e instanceof ErrorArca ? e : new ErrorArca(`No se pudo conectar con ARCA: ${e.message}`, 'red', true)),
    );
    req.end(cuerpo, 'utf8');
  });
}
