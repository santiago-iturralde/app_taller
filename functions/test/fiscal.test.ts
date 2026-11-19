import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import { describe, test } from 'node:test';

import {
  DOC_TIPO,
  ErrorFiscal,
  TipoComprobante,
  calcularImportes,
  cuitValido,
  desdeFechaArca,
  determinarTipo,
  fechaArca,
  notaCreditoDe,
  prepararReceptor,
  urlQr,
} from '../src/arca/comprobantes';
import { cifrar, descifrar } from '../src/util/cifrado';

const CUIT_VALIDO = '33693450239';

describe('cifrado', () => {
  const maestra = randomBytes(32).toString('base64');

  test('ida y vuelta', () => {
    const c = cifrar('-----BEGIN RSA PRIVATE KEY-----secreto', maestra, 'negocio1');
    assert.match(c, /^v1:/);
    assert.equal(descifrar(c, maestra, 'negocio1'), '-----BEGIN RSA PRIVATE KEY-----secreto');
  });

  test('no se descifra en otro negocio (AAD)', () => {
    const c = cifrar('dato', maestra, 'negocio1');
    assert.throws(() => descifrar(c, maestra, 'negocio2'));
  });

  test('detecta alteraciones', () => {
    const c = cifrar('dato', maestra, 'n');
    const buf = Buffer.from(c.slice(3), 'base64');
    buf[buf.length - 1] ^= 1;
    assert.throws(() => descifrar(`v1:${buf.toString('base64')}`, maestra, 'n'));
  });

  test('exige una clave maestra de 32 bytes', () => {
    assert.throws(() => cifrar('x', Buffer.from('corta').toString('base64'), 'n'), /32 bytes/);
  });
});

describe('tipo de comprobante', () => {
  test('monotributo y exento emiten C', () => {
    assert.equal(determinarTipo('monotributo', 'responsable_inscripto'), TipoComprobante.FacturaC);
    assert.equal(determinarTipo('exento', 'consumidor_final'), TipoComprobante.FacturaC);
    assert.equal(determinarTipo('monotributo', 'consumidor_final', true), TipoComprobante.NotaCreditoC);
  });

  test('responsable inscripto: A a inscriptos y monotributistas, B al resto', () => {
    assert.equal(determinarTipo('responsable_inscripto', 'responsable_inscripto'), TipoComprobante.FacturaA);
    assert.equal(determinarTipo('responsable_inscripto', 'monotributo'), TipoComprobante.FacturaA);
    assert.equal(determinarTipo('responsable_inscripto', 'consumidor_final'), TipoComprobante.FacturaB);
    assert.equal(determinarTipo('responsable_inscripto', 'exento'), TipoComprobante.FacturaB);
  });

  test('nota de crédito de cada factura', () => {
    assert.equal(notaCreditoDe(TipoComprobante.FacturaA), TipoComprobante.NotaCreditoA);
    assert.equal(notaCreditoDe(TipoComprobante.FacturaB), TipoComprobante.NotaCreditoB);
    assert.throws(() => notaCreditoDe(TipoComprobante.NotaCreditoC), ErrorFiscal);
  });
});

describe('importes', () => {
  const lineas = [
    { descripcion: 'Aceite', cantidad: 4, precioUnitario: 12345.67 },
    { descripcion: 'Mano de obra', cantidad: 1, precioUnitario: 15000 },
  ];

  test('factura C informa el total como neto, sin IVA', () => {
    const i = calcularImportes(lineas, TipoComprobante.FacturaC, 21);
    assert.deepEqual(i, { total: 64382.68, neto: 64382.68, iva: 0, alicuota: null, alicuotaId: null });
  });

  test('factura B discrimina el IVA y neto + IVA = total exacto', () => {
    const i = calcularImportes(lineas, TipoComprobante.FacturaB, 21);
    assert.equal(i.total, 64382.68);
    assert.equal(i.neto, 53208.83);
    assert.equal(Math.round((i.neto + i.iva) * 100) / 100, i.total);
    assert.equal(i.alicuotaId, 5);
  });

  test('alícuota de 10,5%', () => {
    const i = calcularImportes([{ descripcion: 'x', cantidad: 1, precioUnitario: 1105 }], TipoComprobante.FacturaA, 10.5);
    assert.equal(i.neto, 1000);
    assert.equal(i.iva, 105);
    assert.equal(i.alicuotaId, 4);
  });

  test('rechaza total cero y alícuotas inexistentes', () => {
    assert.throws(() => calcularImportes([], TipoComprobante.FacturaB, 21), ErrorFiscal);
    assert.throws(() => calcularImportes(lineas, TipoComprobante.FacturaB, 19), ErrorFiscal);
  });
});

describe('receptor', () => {
  test('CUIT con dígito verificador', () => {
    assert.equal(cuitValido(CUIT_VALIDO), true);
    assert.equal(cuitValido('33-69345023-9'), true);
    assert.equal(cuitValido('33693450238'), false);
    assert.equal(cuitValido('123'), false);
  });

  test('factura A exige CUIT válido', () => {
    assert.throws(
      () => prepararReceptor({ nombre: 'X', docTipo: 'dni', docNro: '30111222', condicionIva: 'responsable_inscripto' }, TipoComprobante.FacturaA),
      ErrorFiscal,
    );
    const r = prepararReceptor({ nombre: 'X', docTipo: 'cuit', docNro: '33-69345023-9', condicionIva: 'responsable_inscripto' }, TipoComprobante.FacturaA);
    assert.deepEqual(r, { docTipo: DOC_TIPO.cuit, docNro: 33693450239, condicionId: 1 });
  });

  test('consumidor final sin identificar', () => {
    const r = prepararReceptor({ nombre: 'CF', docTipo: 'consumidor_final', docNro: '', condicionIva: 'consumidor_final' }, TipoComprobante.FacturaB);
    assert.deepEqual(r, { docTipo: 99, docNro: 0, condicionId: 5 });
  });

  test('DNI con largo válido', () => {
    assert.throws(() => prepararReceptor({ nombre: 'X', docTipo: 'dni', docNro: '12', condicionIva: 'consumidor_final' }, TipoComprobante.FacturaB));
    assert.equal(
      prepararReceptor({ nombre: 'X', docTipo: 'dni', docNro: '30.111.222', condicionIva: 'consumidor_final' }, TipoComprobante.FacturaB).docNro,
      30111222,
    );
  });
});

describe('fechas y QR', () => {
  test('la fecha se calcula en hora argentina', () => {
    assert.equal(fechaArca(new Date('2026-11-18T02:00:00Z')), '20261117');
    assert.equal(fechaArca(new Date('2026-11-18T04:00:00Z')), '20261118');
    assert.equal(fechaArca(desdeFechaArca('20261231')), '20261231');
  });

  test('el QR contiene los datos exigidos por ARCA', () => {
    const url = urlQr({
      fecha: desdeFechaArca('20261118'),
      cuit: '33-69345023-9',
      puntoVenta: 2,
      tipo: TipoComprobante.FacturaB,
      numero: 15,
      importe: 1210.5,
      docTipo: 99,
      docNro: 0,
      cae: '76123456789012',
    });
    assert.ok(url.startsWith('https://www.afip.gob.ar/fe/qr/?p='));
    const datos = JSON.parse(Buffer.from(url.split('?p=')[1], 'base64').toString('utf8'));
    assert.deepEqual(datos, {
      ver: 1,
      fecha: '2026-11-18',
      cuit: 33693450239,
      ptoVta: 2,
      tipoCmp: 6,
      nroCmp: 15,
      importe: 1210.5,
      moneda: 'PES',
      ctz: 1,
      tipoDocRec: 99,
      nroDocRec: 0,
      tipoCodAut: 'E',
      codAut: 76123456789012,
    });
  });
});

