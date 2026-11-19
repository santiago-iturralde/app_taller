import { createCipheriv, createDecipheriv, randomBytes } from 'node:crypto';

/**
 * Cifrado simétrico AES-256-GCM para datos sensibles guardados en Firestore
 * (claves privadas y tickets de acceso de ARCA).
 *
 * - La clave maestra vive en Secret Manager, nunca en el código ni en la base.
 * - Se usa el ID del negocio como "dato adicional autenticado" (AAD): un
 *   texto cifrado copiado a otro negocio no se puede descifrar.
 * - Formato: "v1:" + base64(iv[12] + tag[16] + texto cifrado).
 */
const VERSION = 'v1';

function clave(maestraBase64: string): Buffer {
  const k = Buffer.from(maestraBase64.trim(), 'base64');
  if (k.length !== 32) {
    throw new Error('La clave maestra debe tener 32 bytes en base64 (openssl rand -base64 32).');
  }
  return k;
}

export function cifrar(texto: string, maestraBase64: string, contexto: string): string {
  const iv = randomBytes(12);
  const cipher = createCipheriv('aes-256-gcm', clave(maestraBase64), iv);
  cipher.setAAD(Buffer.from(contexto, 'utf8'));
  const cifrado = Buffer.concat([cipher.update(texto, 'utf8'), cipher.final()]);
  return `${VERSION}:${Buffer.concat([iv, cipher.getAuthTag(), cifrado]).toString('base64')}`;
}

export function descifrar(paquete: string, maestraBase64: string, contexto: string): string {
  const [version, datos] = paquete.split(':', 2);
  if (version !== VERSION || !datos) throw new Error('Formato de dato cifrado desconocido.');
  const buf = Buffer.from(datos, 'base64');
  const iv = buf.subarray(0, 12);
  const tag = buf.subarray(12, 28);
  const cifrado = buf.subarray(28);
  const decipher = createDecipheriv('aes-256-gcm', clave(maestraBase64), iv);
  decipher.setAAD(Buffer.from(contexto, 'utf8'));
  decipher.setAuthTag(tag);
  return Buffer.concat([decipher.update(cifrado), decipher.final()]).toString('utf8');
}
