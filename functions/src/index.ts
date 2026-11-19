/**
 * Backend de WorkControl (Cloud Functions, 2da generación).
 *
 * - Facturación electrónica ARCA: las claves privadas y los tickets de
 *   acceso nunca salen del servidor y se guardan cifrados.
 *
 * (Los cambios de plan los hace el administrador desde la app; las reglas
 * de Firestore exigen el custom claim "superadmin" y la auditoría.)
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
