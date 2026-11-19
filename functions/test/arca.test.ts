import assert from 'node:assert/strict';
import { describe, test } from 'node:test';
import forge from 'node-forge';

import { generarClaveYCsr, leerCertificado, normalizarPem } from '../src/arca/certificados';
import { ErrorFiscal, TipoComprobante } from '../src/arca/comprobantes';
import { construirTRA, firmarTRA, parsearLoginCms, sobreLoginCms, ticketVigente } from '../src/arca/wsaa';
import {
  Credenciales,
  parsearConsultar,
  parsearSolicitarCae,
  parsearUltimoAutorizado,
  sobreSolicitarCae,
} from '../src/arca/wsfe';
import { ErrorArca } from '../src/arca/xml';

const CUIT = '33693450239';

/** Simula a ARCA como autoridad certificante: firma el CSR y devuelve el certificado. */
function emitirCertificadoDePrueba(csrPem: string): string {
  const csr = forge.pki.certificationRequestFromPem(csrPem);
  const ca = forge.pki.rsa.generateKeyPair(1024);
  const cert = forge.pki.createCertificate();
  cert.publicKey = csr.publicKey as forge.pki.PublicKey;
  cert.serialNumber = '01';
  cert.validity.notBefore = new Date();
  cert.validity.notAfter = new Date(Date.now() + 2 * 365 * 24 * 3600 * 1000);
  cert.setSubject(csr.subject.attributes);
  cert.setIssuer([{ name: 'commonName', value: 'Computadores Test' }]);
  cert.sign(ca.privateKey, forge.md.sha256.create());
  return forge.pki.certificateToPem(cert);
}

describe('certificados', () => {
  const { clavePem, csrPem } = generarClaveYCsr({ cuit: CUIT, razonSocial: 'Lubricentro Demo SRL', alias: 'workcontrol homo!' });

  test('el CSR tiene el formato que pide ARCA', () => {
    const csr = forge.pki.certificationRequestFromPem(csrPem);
    assert.equal(csr.verify(), true);
    assert.equal(csr.subject.getField('C').value, 'AR');
    assert.equal(csr.subject.getField('O').value, 'Lubricentro Demo SRL');
    assert.equal(csr.subject.getField('CN').value, 'workcontrolhomo');
    assert.equal(csr.subject.getField({ type: '2.5.4.5' }).value, `CUIT ${CUIT}`);
  });

  test('rechaza CUIT inválido', () => {
    assert.throws(() => generarClaveYCsr({ cuit: '20111111111', razonSocial: 'X', alias: 'a' }), ErrorFiscal);
  });

  test('lee el certificado y verifica que corresponda a la clave', () => {
    const cert = emitirCertificadoDePrueba(csrPem);
    const datos = leerCertificado(cert, clavePem);
    assert.equal(datos.cuit, CUIT);
    assert.ok(datos.vence.getTime() > Date.now());
  });

  test('rechaza un certificado de otra clave', () => {
    const otro = generarClaveYCsr({ cuit: CUIT, razonSocial: 'Otro', alias: 'x' });
    const cert = emitirCertificadoDePrueba(otro.csrPem);
    assert.throws(() => leerCertificado(cert, clavePem), /no corresponde/);
  });

  test('acepta el certificado pegado con saltos de línea de Windows', () => {
    const cert = emitirCertificadoDePrueba(csrPem).replace(/\n/g, '\r\n');
    assert.equal(leerCertificado(`  ${cert}  `, clavePem).cuit, CUIT);
    assert.match(normalizarPem(cert), /^-----BEGIN CERTIFICATE-----\n/);
  });

  test('firma el TRA en CMS con el contenido incluido', () => {
    const cert = emitirCertificadoDePrueba(csrPem);
    const tra = construirTRA('wsfe', new Date('2026-11-18T12:00:00Z'));
    assert.match(tra, /<service>wsfe<\/service>/);
    assert.match(tra, /<generationTime>2026-11-18T11:50:00.000Z<\/generationTime>/);
    const cms = firmarTRA(tra, cert, clavePem);
    const p7 = forge.pkcs7.messageFromAsn1(forge.asn1.fromDer(forge.util.decode64(cms))) as any;
    assert.equal(p7.rawCapture.content.value[0].value, tra);
    assert.equal(p7.certificates.length, 1);
    assert.match(sobreLoginCms(cms), /<wsaa:in0>[A-Za-z0-9+/=]+<\/wsaa:in0>/);
  });
});

describe('WSAA', () => {
  test('lee token y sign de la respuesta', () => {
    const interno =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><loginTicketResponse version="1.0"><header>' +
      '<expirationTime>2026-11-19T00:00:00.000-03:00</expirationTime></header>' +
      '<credentials><token>TOKEN123</token><sign>SIGN456</sign></credentials></loginTicketResponse>';
    const escapado = interno.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    const xml =
      '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"><soapenv:Body>' +
      `<loginCmsResponse xmlns="http://wsaa.view.sua.dvadac.desein.afip.gov"><loginCmsReturn>${escapado}</loginCmsReturn></loginCmsResponse>` +
      '</soapenv:Body></soapenv:Envelope>';
    const t = parsearLoginCms(xml);
    assert.equal(t.token, 'TOKEN123');
    assert.equal(t.sign, 'SIGN456');
    assert.equal(t.vence, '2026-11-19T03:00:00.000Z');
  });

  test('convierte un SOAP Fault en error', () => {
    const xml =
      '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"><soapenv:Body><soapenv:Fault>' +
      '<faultcode>ns1:cms.cert.untrusted</faultcode><faultstring>Certificado no emitido por AC de confianza</faultstring>' +
      '</soapenv:Fault></soapenv:Body></soapenv:Envelope>';
    assert.throws(() => parsearLoginCms(xml), (e: unknown) => e instanceof ErrorArca && /AC de confianza/.test(e.message));
  });

  test('ticket vigente con margen de 10 minutos', () => {
    const ahora = new Date('2026-11-18T12:00:00Z');
    assert.equal(ticketVigente({ token: 't', sign: 's', vence: '2026-11-18T12:30:00Z' }, ahora), true);
    assert.equal(ticketVigente({ token: 't', sign: 's', vence: '2026-11-18T12:05:00Z' }, ahora), false);
    assert.equal(ticketVigente(null, ahora), false);
  });
});

const cred: Credenciales = { token: 'T', sign: 'S', vence: '', cuit: '33-69345023-9' };
const sobre = (cuerpo: string) =>
  `<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"><soap:Body>${cuerpo}</soap:Body></soap:Envelope>`;

describe('WSFEv1', () => {
  test('arma el pedido de CAE en el orden del esquema', () => {
    const xml = sobreSolicitarCae(cred, {
      puntoVenta: 3,
      tipo: TipoComprobante.FacturaB,
      numero: 101,
      concepto: 3,
      docTipo: 99,
      docNro: 0,
      condicionIvaReceptorId: 5,
      fecha: '20261118',
      total: 1210,
      neto: 1000,
      iva: 210,
      alicuotaId: 5,
    });
    const orden = [
      'Concepto', 'DocTipo', 'DocNro', 'CbteDesde', 'CbteHasta', 'CbteFch', 'ImpTotal', 'ImpTotConc', 'ImpNeto',
      'ImpOpEx', 'ImpTrib', 'ImpIVA', 'FchServDesde', 'FchServHasta', 'FchVtoPago', 'MonId', 'MonCotiz',
      'CondicionIVAReceptorId', 'Iva',
    ];
    const posiciones = orden.map((t) => xml.indexOf(`<ar:${t}>`));
    assert.ok(posiciones.every((p) => p > 0), 'faltan elementos');
    assert.deepEqual([...posiciones].sort((a, b) => a - b), posiciones, 'elementos fuera de orden');
    assert.match(xml, /<ar:Cuit>33693450239<\/ar:Cuit>/);
    assert.match(xml, /<ar:ImpTotal>1210.00<\/ar:ImpTotal>/);
    assert.match(xml, /<ar:BaseImp>1000.00<\/ar:BaseImp><ar:Importe>210.00<\/ar:Importe>/);
  });

  test('factura C de productos: sin IVA ni fechas de servicio', () => {
    const xml = sobreSolicitarCae(cred, {
      puntoVenta: 1, tipo: TipoComprobante.FacturaC, numero: 1, concepto: 1, docTipo: 99, docNro: 0,
      condicionIvaReceptorId: 5, fecha: '20261118', total: 500, neto: 500, iva: 0, alicuotaId: null,
    });
    assert.doesNotMatch(xml, /<ar:Iva>/);
    assert.doesNotMatch(xml, /FchServDesde/);
  });

  test('nota de crédito incluye el comprobante asociado', () => {
    const xml = sobreSolicitarCae(cred, {
      puntoVenta: 1, tipo: TipoComprobante.NotaCreditoC, numero: 2, concepto: 1, docTipo: 99, docNro: 0,
      condicionIvaReceptorId: 5, fecha: '20261118', total: 500, neto: 500, iva: 0, alicuotaId: null,
      asociado: { tipo: TipoComprobante.FacturaC, puntoVenta: 1, numero: 1, cuit: '33693450239', fecha: '20261117' },
    });
    assert.match(xml, /<ar:CbtesAsoc><ar:CbteAsoc><ar:Tipo>11<\/ar:Tipo><ar:PtoVta>1<\/ar:PtoVta><ar:Nro>1<\/ar:Nro>/);
    assert.ok(xml.indexOf('CondicionIVAReceptorId') < xml.indexOf('CbtesAsoc'));
  });

  test('lee una aprobación con CAE (sin perder dígitos)', () => {
    const r = parsearSolicitarCae(
      sobre(
        '<FECAESolicitarResponse xmlns="http://ar.gov.afip.dif.FEV1/"><FECAESolicitarResult>' +
          '<FeCabResp><Resultado>A</Resultado></FeCabResp><FeDetResp><FECAEDetResponse>' +
          '<Resultado>A</Resultado><CAE>76123456789012</CAE><CAEFchVto>20261128</CAEFchVto>' +
          '<Observaciones><Obs><Code>10217</Code><Msg>Aviso de prueba</Msg></Obs></Observaciones>' +
          '</FECAEDetResponse></FeDetResp></FECAESolicitarResult></FECAESolicitarResponse>',
      ),
    );
    assert.deepEqual(r, {
      aprobado: true,
      cae: '76123456789012',
      caeVence: '20261128',
      observaciones: [{ codigo: '10217', mensaje: 'Aviso de prueba' }],
    });
  });

  test('lee un rechazo con sus motivos', () => {
    const r = parsearSolicitarCae(
      sobre(
        '<FECAESolicitarResponse xmlns="http://ar.gov.afip.dif.FEV1/"><FECAESolicitarResult>' +
          '<FeCabResp><Resultado>R</Resultado></FeCabResp><FeDetResp><FECAEDetResponse><Resultado>R</Resultado>' +
          '<Observaciones><Obs><Code>10016</Code><Msg>El numero no es correlativo</Msg></Obs>' +
          '<Obs><Code>10015</Code><Msg>Otro</Msg></Obs></Observaciones></FECAEDetResponse></FeDetResp>' +
          '<Errors><Err><Code>600</Code><Msg>ValidacionDeToken</Msg></Err></Errors>' +
          '</FECAESolicitarResult></FECAESolicitarResponse>',
      ),
    );
    assert.equal(r.aprobado, false);
    if (!r.aprobado) {
      assert.deepEqual(r.errores, [{ codigo: '600', mensaje: 'ValidacionDeToken' }]);
      assert.equal(r.observaciones.length, 2);
    }
  });

  test('último número autorizado', () => {
    const xml = sobre(
      '<FECompUltimoAutorizadoResponse xmlns="http://ar.gov.afip.dif.FEV1/"><FECompUltimoAutorizadoResult>' +
        '<PtoVta>3</PtoVta><CbteTipo>6</CbteTipo><CbteNro>148</CbteNro></FECompUltimoAutorizadoResult></FECompUltimoAutorizadoResponse>',
    );
    assert.equal(parsearUltimoAutorizado(xml), 148);
  });

  test('error de autenticación al pedir el último número', () => {
    const xml = sobre(
      '<FECompUltimoAutorizadoResponse xmlns="http://ar.gov.afip.dif.FEV1/"><FECompUltimoAutorizadoResult>' +
        '<Errors><Err><Code>600</Code><Msg>ValidacionDeToken: No validaron las fechas del token</Msg></Err></Errors>' +
        '</FECompUltimoAutorizadoResult></FECompUltimoAutorizadoResponse>',
    );
    assert.throws(() => parsearUltimoAutorizado(xml), (e: unknown) => e instanceof ErrorArca && e.codigo === '600');
  });

  test('consulta: comprobante inexistente devuelve null', () => {
    const xml = sobre(
      '<FECompConsultarResponse xmlns="http://ar.gov.afip.dif.FEV1/"><FECompConsultarResult>' +
        '<Errors><Err><Code>602</Code><Msg>No existen datos en nuestros registros</Msg></Err></Errors>' +
        '</FECompConsultarResult></FECompConsultarResponse>',
    );
    assert.equal(parsearConsultar(xml), null);
  });

  test('consulta: comprobante existente', () => {
    const xml = sobre(
      '<FECompConsultarResponse xmlns="http://ar.gov.afip.dif.FEV1/"><FECompConsultarResult><ResultGet>' +
        '<CbteFch>20261118</CbteFch><ImpTotal>1210</ImpTotal><DocNro>0</DocNro>' +
        '<CodAutorizacion>76123456789012</CodAutorizacion><FchVto>20261128</FchVto>' +
        '</ResultGet></FECompConsultarResult></FECompConsultarResponse>',
    );
    assert.deepEqual(parsearConsultar(xml), { cae: '76123456789012', caeVence: '20261128', total: 1210, docNro: 0, fecha: '20261118' });
  });
});
