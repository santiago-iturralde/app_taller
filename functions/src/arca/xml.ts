import { XMLParser } from 'fast-xml-parser';

/** Escapa texto para incluirlo dentro de un nodo XML. */
export function escaparXml(s: string): string {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&apos;');
}

export function sobreSoap(cuerpo: string, namespaces: Record<string, string> = {}): string {
  const ns = Object.entries(namespaces)
    .map(([p, u]) => ` xmlns:${p}="${u}"`)
    .join('');
  return (
    '<?xml version="1.0" encoding="UTF-8"?>' +
    `<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"${ns}>` +
    `<soapenv:Header/><soapenv:Body>${cuerpo}</soapenv:Body></soapenv:Envelope>`
  );
}

// Los valores se leen siempre como texto: un CAE o un CUIT no deben
// convertirse en número (perderían ceros o precisión).
const parser = new XMLParser({
  ignoreAttributes: true,
  removeNSPrefix: true,
  parseTagValue: false,
  trimValues: true,
});

export function parsearXml(xml: string): any {
  return parser.parse(xml);
}

/** Convierte un nodo que puede venir como objeto o lista en una lista. */
export function comoLista<T>(v: T | T[] | undefined | null): T[] {
  if (v === undefined || v === null || v === '') return [];
  return Array.isArray(v) ? v : [v];
}

export class ErrorArca extends Error {
  constructor(
    mensaje: string,
    readonly codigo?: string,
    /** true si no se sabe si ARCA procesó el pedido (error de red, timeout). */
    readonly incierto = false,
  ) {
    super(mensaje);
  }
}

/** Lanza ErrorArca si la respuesta es un SOAP Fault. */
export function verificarFault(doc: any): void {
  const fault = doc?.Envelope?.Body?.Fault;
  if (fault) {
    const texto = String(fault.faultstring ?? fault.Reason?.Text ?? 'Error de ARCA');
    throw new ErrorArca(texto, String(fault.faultcode ?? ''));
  }
}
