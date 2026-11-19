import { DocumentReference, FieldValue, Timestamp, getFirestore } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions/v2';

import { conBloqueo } from '../util/bloqueo';
import { cifrar, descifrar } from '../util/cifrado';
import { generarClaveYCsr, leerCertificado } from './certificados';
import {
  Concepto,
  CondicionEmisor,
  ErrorFiscal,
  LETRA,
  Linea,
  Receptor,
  TipoComprobante,
  calcularImportes,
  cuitValido,
  desdeFechaArca,
  determinarTipo,
  fechaArca,
  notaCreditoDe,
  prepararReceptor,
  urlQr,
} from './comprobantes';
import { Ambiente, TicketAcceso, solicitarTicket, ticketVigente } from './wsaa';
import { Credenciales, PedidoCae, consultarComprobante, estadoServidores, solicitarCae, ultimoAutorizado } from './wsfe';
import { ErrorArca } from './xml';

/** Configuración fiscal que carga el negocio (negocios/{id}/meta/fiscal). */
export interface ConfigFiscal {
  razonSocial: string;
  cuit: string;
  condicionIva: CondicionEmisor;
  domicilio: string;
  ingresosBrutos: string;
  inicioActividades: string;
  puntoVenta: number;
  alicuotaIva: number;
  ambiente: Ambiente;
  concepto: Concepto;
}

const db = () => getFirestore();
const rutaPrivado = (negocioId: string, amb: Ambiente) => `negocios/${negocioId}/privado/arca_${amb}`;
const rutaEstado = (negocioId: string) => `negocios/${negocioId}/meta/arca`;

function errorAHttps(e: unknown): HttpsError {
  if (e instanceof HttpsError) return e;
  if (e instanceof ErrorFiscal) return new HttpsError('failed-precondition', e.message);
  if (e instanceof ErrorArca) return new HttpsError(e.incierto ? 'unavailable' : 'failed-precondition', `ARCA: ${e.message}`);
  logger.error('Error inesperado en ARCA', e);
  return new HttpsError('internal', 'Ocurrió un error inesperado. Probá de nuevo en unos minutos.');
}

export async function leerConfigFiscal(negocioId: string): Promise<ConfigFiscal> {
  const d = (await db().doc(`negocios/${negocioId}/meta/fiscal`).get()).data();
  if (!d) throw new ErrorFiscal('Primero completá los datos fiscales del negocio.');
  const c: ConfigFiscal = {
    razonSocial: String(d.razonSocial ?? '').trim(),
    cuit: String(d.cuit ?? '').replace(/\D/g, ''),
    condicionIva: d.condicionIva as CondicionEmisor,
    domicilio: String(d.domicilio ?? '').trim(),
    ingresosBrutos: String(d.ingresosBrutos ?? '').trim(),
    inicioActividades: String(d.inicioActividades ?? '').trim(),
    puntoVenta: Number(d.puntoVenta),
    alicuotaIva: Number(d.alicuotaIva ?? 21),
    ambiente: d.ambiente === 'produccion' ? 'produccion' : 'homologacion',
    concepto: ([1, 2, 3].includes(Number(d.concepto)) ? Number(d.concepto) : 3) as Concepto,
  };
  if (!c.razonSocial) throw new ErrorFiscal('Falta la razón social.');
  if (!cuitValido(c.cuit)) throw new ErrorFiscal('El CUIT del negocio no es válido.');
  if (!['responsable_inscripto', 'monotributo', 'exento'].includes(c.condicionIva)) {
    throw new ErrorFiscal('Falta la condición frente al IVA del negocio.');
  }
  if (!Number.isInteger(c.puntoVenta) || c.puntoVenta < 1 || c.puntoVenta > 99998) {
    throw new ErrorFiscal('El punto de venta no es válido.');
  }
  return c;
}

async function actualizarEstado(negocioId: string, amb: Ambiente, datos: Record<string, unknown>) {
  await db().doc(rutaEstado(negocioId)).set({ [amb]: { ...datos, actualizado: FieldValue.serverTimestamp() } }, { merge: true });
}

// ------------------------------------------------------------ Certificados

/** Paso 1: genera la clave privada (queda cifrada en el servidor) y la solicitud CSR. */
export async function generarSolicitud(negocioId: string, maestra: string): Promise<{ csr: string; ambiente: Ambiente }> {
  try {
    const cfg = await leerConfigFiscal(negocioId);
    const alias = `workcontrol${cfg.ambiente === 'homologacion' ? 'homo' : ''}`;
    const { clavePem, csrPem } = generarClaveYCsr({ cuit: cfg.cuit, razonSocial: cfg.razonSocial, alias });
    await db().doc(rutaPrivado(negocioId, cfg.ambiente)).set({
      claveCifrada: cifrar(clavePem, maestra, negocioId),
      csr: csrPem,
      cuit: cfg.cuit,
      alias,
      creado: FieldValue.serverTimestamp(),
    });
    await actualizarEstado(negocioId, cfg.ambiente, { estado: 'esperando_certificado', cuit: cfg.cuit, mensaje: null });
    return { csr: csrPem, ambiente: cfg.ambiente };
  } catch (e) {
    throw errorAHttps(e);
  }
}

/** Paso 2: guarda el certificado que entregó ARCA y prueba la conexión. */
export async function guardarCertificado(negocioId: string, certPem: string, maestra: string) {
  try {
    const cfg = await leerConfigFiscal(negocioId);
    const ref = db().doc(rutaPrivado(negocioId, cfg.ambiente));
    const priv = (await ref.get()).data();
    if (!priv?.claveCifrada) throw new ErrorFiscal('Primero generá la solicitud de certificado.');
    const clave = descifrar(priv.claveCifrada, maestra, negocioId);
    const datos = leerCertificado(certPem, clave);
    if (datos.cuit && datos.cuit !== cfg.cuit) {
      throw new ErrorFiscal(`El certificado es del CUIT ${datos.cuit}, pero el negocio tiene cargado ${cfg.cuit}.`);
    }
    if (datos.vence.getTime() < Date.now()) throw new ErrorFiscal('El certificado está vencido.');
    await ref.update({
      certificado: certPem.replace(/\r/g, '').trim(),
      certificadoVence: Timestamp.fromDate(datos.vence),
      ticketCifrado: FieldValue.delete(),
    });
    await actualizarEstado(negocioId, cfg.ambiente, {
      estado: 'listo',
      cuit: cfg.cuit,
      certificadoVence: Timestamp.fromDate(datos.vence),
      mensaje: null,
    });
    return { vence: datos.vence.toISOString() };
  } catch (e) {
    throw errorAHttps(e);
  }
}

/** Obtiene (o reutiliza) el ticket de acceso al servicio de facturación. */
async function credenciales(negocioId: string, cfg: ConfigFiscal, maestra: string): Promise<Credenciales> {
  const ref = db().doc(rutaPrivado(negocioId, cfg.ambiente));
  const leerVigente = async (): Promise<TicketAcceso | null> => {
    const p = (await ref.get()).data();
    if (!p?.ticketCifrado) return null;
    const t = JSON.parse(descifrar(p.ticketCifrado, maestra, negocioId)) as TicketAcceso;
    return ticketVigente(t) ? t : null;
  };

  let ticket = await leerVigente();
  if (!ticket) {
    // ARCA no entrega un ticket nuevo si hay uno vigente: se serializa el pedido.
    ticket = await conBloqueo(`negocios/${negocioId}/privado/bloqueo_wsaa_${cfg.ambiente}`, 60_000, async () => {
      const yaVigente = await leerVigente();
      if (yaVigente) return yaVigente;
      const p = (await ref.get()).data();
      if (!p?.certificado || !p?.claveCifrada) {
        throw new ErrorFiscal('La facturación electrónica no está configurada (falta el certificado de ARCA).');
      }
      const nuevo = await solicitarTicket({
        ambiente: cfg.ambiente,
        servicio: 'wsfe',
        certPem: p.certificado,
        clavePem: descifrar(p.claveCifrada, maestra, negocioId),
      });
      await ref.update({ ticketCifrado: cifrar(JSON.stringify(nuevo), maestra, negocioId) });
      return nuevo;
    });
  }
  return { ...ticket, cuit: cfg.cuit };
}

/** Prueba la conexión completa: servidores, autenticación y punto de venta. */
export async function probarConexion(negocioId: string, maestra: string) {
  let cfg: ConfigFiscal | undefined;
  try {
    cfg = await leerConfigFiscal(negocioId);
    const servidores = await estadoServidores(cfg.ambiente);
    const cred = await credenciales(negocioId, cfg, maestra);
    const tipo = determinarTipo(cfg.condicionIva, 'consumidor_final');
    const ultimo = await ultimoAutorizado(cfg.ambiente, cred, cfg.puntoVenta, tipo);
    await actualizarEstado(negocioId, cfg.ambiente, {
      estado: 'listo',
      ultimaPrueba: FieldValue.serverTimestamp(),
      mensaje: `Conexión correcta. Último comprobante ${LETRA[tipo]} del punto de venta ${cfg.puntoVenta}: ${ultimo}.`,
    });
    return { ok: true, servidores, ultimo, letra: LETRA[tipo] };
  } catch (e) {
    const err = errorAHttps(e);
    if (cfg) await actualizarEstado(negocioId, cfg.ambiente, { ultimaPrueba: FieldValue.serverTimestamp(), mensaje: err.message });
    throw err;
  }
}

// ---------------------------------------------------------------- Emisión

export interface PedidoFactura {
  origen: { tipo: 'orden' | 'pago'; id: string };
  receptor: Receptor;
  concepto?: Concepto;
}

interface DatosOrigen {
  ref: DocumentReference;
  lineas: Linea[];
  numero: number | null;
  clienteId: string | null;
}

function lineasValidas(items: unknown): Linea[] {
  if (!Array.isArray(items)) return [];
  return items
    .map((i: any) => ({
      descripcion: String(i?.descripcion ?? i?.desc ?? '').slice(0, 200),
      cantidad: Number(i?.cantidad ?? 1),
      precioUnitario: Number(i?.precioUnitario ?? i?.precio ?? 0),
    }))
    .filter((l) => l.descripcion && l.cantidad > 0 && l.precioUnitario > 0);
}

/** Lee el trabajo o cobro a facturar. Los importes salen del servidor, no de la app. */
function leerOrigen(negocioId: string, origen: PedidoFactura['origen'], data: FirebaseFirestore.DocumentData | undefined, ref: DocumentReference): DatosOrigen {
  if (!data) throw new ErrorFiscal('El registro a facturar no existe.');
  if (data.facturaId) throw new ErrorFiscal('Este registro ya tiene una factura emitida.');
  if (origen.tipo === 'orden') {
    if (data.estado === 'cancelado') throw new ErrorFiscal('No se puede facturar un trabajo cancelado.');
    const lineas = lineasValidas(data.items);
    if (!lineas.length) throw new ErrorFiscal('El trabajo no tiene ítems con importe.');
    return { ref, lineas, numero: Number(data.numero) || null, clienteId: data.clienteId ?? null };
  }
  if (data.anulado) throw new ErrorFiscal('No se puede facturar un cobro anulado.');
  if (data.excluirDeCaja) throw new ErrorFiscal('Este comprobante es del sistema anterior y no se puede facturar.');
  if (data.ordenId) throw new ErrorFiscal('Este cobro pertenece a un trabajo: facturá el trabajo completo.');
  const items = lineasValidas(data.items);
  const lineas = items.length
    ? items
    : [{ descripcion: String(data.concepto || 'Venta').slice(0, 200), cantidad: 1, precioUnitario: Number(data.monto) }];
  return { ref, lineas, numero: Number(data.numero) || null, clienteId: data.clienteId ?? null };
}

/** Emite una factura para un trabajo o un cobro. */
export async function emitirFactura(negocioId: string, uid: string, pedido: PedidoFactura, maestra: string) {
  const facturas = db().collection(`negocios/${negocioId}/facturas`);
  const facturaRef = facturas.doc();
  let cfg: ConfigFiscal;
  let pedidoCae: Omit<PedidoCae, 'numero' | 'fecha'>;

  try {
    cfg = await leerConfigFiscal(negocioId);
    const estado = (await db().doc(rutaEstado(negocioId)).get()).get(cfg.ambiente);
    if (estado?.estado !== 'listo') throw new ErrorFiscal('La facturación electrónica todavía no está configurada.');

    const tipo = determinarTipo(cfg.condicionIva, pedido.receptor.condicionIva);
    const receptor = prepararReceptor(pedido.receptor, tipo);
    const concepto = pedido.concepto ?? cfg.concepto;
    const coleccion = pedido.origen.tipo === 'orden' ? 'ordenes' : 'pagos';
    const origenRef = db().doc(`negocios/${negocioId}/${coleccion}/${pedido.origen.id}`);

    // Reserva el origen dentro de una transacción: evita facturar dos veces.
    await db().runTransaction(async (tx) => {
      const snap = await tx.get(origenRef);
      const origen = leerOrigen(negocioId, pedido.origen, snap.data(), origenRef);
      const importes = calcularImportes(origen.lineas, tipo, cfg.alicuotaIva);
      pedidoCae = {
        puntoVenta: cfg.puntoVenta,
        tipo,
        concepto,
        docTipo: receptor.docTipo,
        docNro: receptor.docNro,
        condicionIvaReceptorId: receptor.condicionId,
        total: importes.total,
        neto: importes.neto,
        iva: importes.iva,
        alicuotaId: importes.alicuotaId,
      };
      tx.update(origenRef, { facturaId: facturaRef.id });
      tx.set(facturaRef, {
        estado: 'procesando',
        ambiente: cfg.ambiente,
        tipo,
        letra: LETRA[tipo],
        esNotaCredito: false,
        puntoVenta: cfg.puntoVenta,
        numero: null,
        concepto,
        emisor: {
          razonSocial: cfg.razonSocial,
          cuit: cfg.cuit,
          condicionIva: cfg.condicionIva,
          domicilio: cfg.domicilio,
          ingresosBrutos: cfg.ingresosBrutos,
          inicioActividades: cfg.inicioActividades,
        },
        receptor: {
          nombre: pedido.receptor.nombre.slice(0, 150),
          docTipo: receptor.docTipo,
          docNro: receptor.docNro,
          condicionIva: pedido.receptor.condicionIva,
          clienteId: origen.clienteId,
        },
        items: origen.lineas.map((l) => ({ ...l, subtotal: Math.round(l.cantidad * l.precioUnitario * 100) / 100 })),
        importes,
        origen: { tipo: pedido.origen.tipo, id: pedido.origen.id, numero: origen.numero },
        pedido: pedidoCae,
        creadoPor: uid,
        creado: FieldValue.serverTimestamp(),
      });
    });
  } catch (e) {
    throw errorAHttps(e);
  }
  return pedirCae(negocioId, facturaRef, cfg!, pedidoCae!, maestra, { liberarOrigenSiFalla: true });
}

/**
 * Pide el CAE para un comprobante ya registrado como "procesando".
 * Distingue entre rechazo (seguro: se libera) e incertidumbre (no se sabe
 * si ARCA lo autorizó: queda "incierta" para verificar al reintentar).
 */
async function pedirCae(
  negocioId: string,
  facturaRef: DocumentReference,
  cfg: ConfigFiscal,
  base: Omit<PedidoCae, 'numero' | 'fecha'>,
  maestra: string,
  opciones: { liberarOrigenSiFalla: boolean; alRechazar?: () => Promise<void> },
) {
  let enviado = false;
  try {
    const cred = await credenciales(negocioId, cfg, maestra);
    const resultado = await conBloqueo(
      `negocios/${negocioId}/privado/bloqueo_${cfg.ambiente}_${base.puntoVenta}_${base.tipo}`,
      90_000,
      async () => {
        const numero = (await ultimoAutorizado(cfg.ambiente, cred, base.puntoVenta, base.tipo)) + 1;
        const fecha = fechaArca(new Date());
        await facturaRef.update({ numero, fechaArca: fecha });
        enviado = true;
        return { numero, fecha, respuesta: await solicitarCae(cfg.ambiente, cred, { ...base, numero, fecha }) };
      },
    );

    if (resultado.respuesta.aprobado) {
      const r = resultado.respuesta;
      await facturaRef.update({
        estado: 'autorizada',
        cae: r.cae,
        caeVence: Timestamp.fromDate(desdeFechaArca(r.caeVence)),
        fecha: Timestamp.fromDate(desdeFechaArca(resultado.fecha)),
        observaciones: r.observaciones,
        qr: urlQr({
          fecha: desdeFechaArca(resultado.fecha),
          cuit: cfg.cuit,
          puntoVenta: base.puntoVenta,
          tipo: base.tipo,
          numero: resultado.numero,
          importe: base.total,
          docTipo: base.docTipo,
          docNro: base.docNro,
          cae: r.cae,
        }),
        mensaje: null,
      });
      return { facturaId: facturaRef.id, estado: 'autorizada', numero: resultado.numero, cae: r.cae };
    }

    const r = resultado.respuesta;
    const detalle = [...r.errores, ...r.observaciones].map((e) => `${e.codigo}: ${e.mensaje}`).join(' | ');
    await marcarRechazada(facturaRef, detalle, opciones.liberarOrigenSiFalla);
    await opciones.alRechazar?.();
    throw new HttpsError('failed-precondition', `ARCA rechazó el comprobante. ${detalle}`);
  } catch (e) {
    if (e instanceof HttpsError) throw e;
    if (e instanceof ErrorArca && e.incierto && enviado) {
      await facturaRef.update({
        estado: 'incierta',
        mensaje: 'No se pudo confirmar si ARCA autorizó el comprobante. Reintentá para verificarlo.',
      });
      throw new HttpsError('unavailable', 'No pudimos confirmar la respuesta de ARCA. Reintentá desde la factura para verificarla.');
    }
    const err = errorAHttps(e);
    await marcarRechazada(facturaRef, err.message, opciones.liberarOrigenSiFalla);
    await opciones.alRechazar?.();
    throw err;
  }
}

/** Marca el comprobante como rechazado y libera el trabajo/cobro para volver a facturarlo. */
async function marcarRechazada(facturaRef: DocumentReference, mensaje: string, liberarOrigen: boolean) {
  await db().runTransaction(async (tx) => {
    const f = await tx.get(facturaRef);
    const origen = f.get('origen') as { tipo: string; id: string } | undefined;
    let origenRef: DocumentReference | null = null;
    let origenSnap: FirebaseFirestore.DocumentSnapshot | null = null;
    if (liberarOrigen && origen) {
      origenRef = facturaRef.parent.parent!.collection(origen.tipo === 'orden' ? 'ordenes' : 'pagos').doc(origen.id);
      origenSnap = await tx.get(origenRef);
    }
    tx.update(facturaRef, { estado: 'rechazada', mensaje });
    if (origenRef && origenSnap?.get('facturaId') === facturaRef.id) tx.update(origenRef, { facturaId: FieldValue.delete() });
  });
}

/**
 * Reintenta un comprobante "incierto": primero consulta a ARCA si el número
 * quedó autorizado; si no existe, lo vuelve a pedir.
 */
export async function reintentarFactura(negocioId: string, facturaId: string, maestra: string) {
  const ref = db().doc(`negocios/${negocioId}/facturas/${facturaId}`);
  const f = (await ref.get()).data();
  if (!f) throw new HttpsError('not-found', 'La factura no existe.');
  if (f.estado !== 'incierta') throw new HttpsError('failed-precondition', 'Sólo se reintentan comprobantes con resultado incierto.');
  const cfg = await leerConfigFiscal(negocioId).catch((e) => {
    throw errorAHttps(e);
  });
  if (cfg.ambiente !== f.ambiente) throw new HttpsError('failed-precondition', 'El ambiente de ARCA cambió desde que se emitió.');
  const base = f.pedido as Omit<PedidoCae, 'numero' | 'fecha'>;

  if (f.numero) {
    try {
      const cred = await credenciales(negocioId, cfg, maestra);
      const existente = await consultarComprobante(cfg.ambiente, cred, base.puntoVenta, base.tipo, f.numero);
      if (existente && Math.abs(existente.total - base.total) < 0.01 && existente.docNro === base.docNro) {
        const fecha = desdeFechaArca(existente.fecha);
        await ref.update({
          estado: 'autorizada',
          cae: existente.cae,
          caeVence: Timestamp.fromDate(desdeFechaArca(existente.caeVence)),
          fecha: Timestamp.fromDate(fecha),
          qr: urlQr({ fecha, cuit: cfg.cuit, puntoVenta: base.puntoVenta, tipo: base.tipo, numero: f.numero, importe: base.total, docTipo: base.docTipo, docNro: base.docNro, cae: existente.cae }),
          mensaje: null,
        });
        if (f.esNotaCredito) await completarAnulacion(negocioId, f.facturaAsociadaId);
        return { facturaId, estado: 'autorizada', numero: f.numero, cae: existente.cae };
      }
    } catch (e) {
      throw errorAHttps(e);
    }
  }
  await ref.update({ estado: 'procesando', numero: null });
  const original = f.esNotaCredito ? db().doc(`negocios/${negocioId}/facturas/${f.facturaAsociadaId}`) : null;
  const resultado = await pedirCae(negocioId, ref, cfg, base, maestra, {
    liberarOrigenSiFalla: !f.esNotaCredito,
    alRechazar: original ? () => original.update({ notaCreditoId: FieldValue.delete() }).then(() => undefined) : undefined,
  });
  if (f.esNotaCredito) await completarAnulacion(negocioId, f.facturaAsociadaId);
  return resultado;
}

/**
 * Anula una factura emitiendo la nota de crédito por el total. El trabajo o
 * cobro queda liberado para volver a facturarse (por ejemplo, con otros datos).
 */
export async function emitirNotaCredito(negocioId: string, uid: string, facturaId: string, maestra: string) {
  const facturaRef = db().doc(`negocios/${negocioId}/facturas/${facturaId}`);
  const ncRef = facturaRef.parent.doc();
  let cfg: ConfigFiscal;
  let base: Omit<PedidoCae, 'numero' | 'fecha'>;
  try {
    cfg = await leerConfigFiscal(negocioId);
    await db().runTransaction(async (tx) => {
      const snap = await tx.get(facturaRef);
      const f = snap.data();
      if (!f) throw new ErrorFiscal('La factura no existe.');
      if (f.estado !== 'autorizada' || f.esNotaCredito) throw new ErrorFiscal('Sólo se puede anular una factura autorizada.');
      if (f.notaCreditoId) throw new ErrorFiscal('Esta factura ya tiene una nota de crédito.');
      if (f.ambiente !== cfg.ambiente) throw new ErrorFiscal('La factura es de otro ambiente de ARCA.');
      const tipo = notaCreditoDe(f.tipo as TipoComprobante);
      base = {
        ...(f.pedido as Omit<PedidoCae, 'numero' | 'fecha'>),
        tipo,
        asociado: { tipo: f.tipo, puntoVenta: f.puntoVenta, numero: f.numero, cuit: cfg.cuit, fecha: f.fechaArca },
      };
      tx.update(facturaRef, { notaCreditoId: ncRef.id });
      tx.set(ncRef, {
        ...f,
        estado: 'procesando',
        tipo,
        letra: LETRA[tipo],
        esNotaCredito: true,
        numero: null,
        cae: null,
        caeVence: null,
        qr: null,
        notaCreditoId: null,
        facturaAsociadaId: facturaId,
        asociada: { tipo: f.tipo, letra: f.letra, puntoVenta: f.puntoVenta, numero: f.numero },
        pedido: base,
        creadoPor: uid,
        creado: FieldValue.serverTimestamp(),
      });
    });
  } catch (e) {
    throw errorAHttps(e);
  }

  const resultado = await pedirCae(negocioId, ncRef, cfg!, base!, maestra, {
    liberarOrigenSiFalla: false,
    alRechazar: () => facturaRef.update({ notaCreditoId: FieldValue.delete() }).then(() => undefined),
  });

  await completarAnulacion(negocioId, facturaId);
  return resultado;
}

/** Marca la factura como anulada y libera el trabajo/cobro para refacturarlo. */
async function completarAnulacion(negocioId: string, facturaId: string) {
  const facturaRef = db().doc(`negocios/${negocioId}/facturas/${facturaId}`);
  await db().runTransaction(async (tx) => {
    const f = await tx.get(facturaRef);
    const origen = f.get('origen') as { tipo: string; id: string } | undefined;
    let origenRef: DocumentReference | null = null;
    let o: FirebaseFirestore.DocumentSnapshot | null = null;
    if (origen) {
      origenRef = facturaRef.parent.parent!.collection(origen.tipo === 'orden' ? 'ordenes' : 'pagos').doc(origen.id);
      o = await tx.get(origenRef);
    }
    tx.update(facturaRef, { anulada: true });
    if (origenRef && o?.exists && o.get('facturaId') === facturaId) tx.update(origenRef, { facturaId: FieldValue.delete() });
  });
}
