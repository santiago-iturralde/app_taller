/**
 * Backend de WorkControl (Cloud Functions, 2da generación).
 *
 * - Facturación electrónica ARCA: las claves privadas y los tickets de
 *   acceso nunca salen del servidor y se guardan cifrados.
 * - Administración de planes: sólo el administrador de la plataforma
 *   (custom claim "superadmin"), con registro de auditoría.
 */
import { initializeApp } from 'firebase-admin/app';

initializeApp();

export {
  arcaAnularFactura,
  arcaEmitirFactura,
  arcaGenerarSolicitud,
  arcaGuardarCertificado,
  arcaProbarConexion,
  arcaReintentar,
} from './handlers/arca';
export { adminCambiarPlan } from './handlers/admin';
