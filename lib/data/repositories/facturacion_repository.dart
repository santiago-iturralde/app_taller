import 'package:cloud_firestore/cloud_firestore.dart';

import '../db.dart';
import '../funciones.dart';
import '../models/fiscal.dart';

/// Facturación electrónica ARCA.
///
/// La app sólo lee y edita los datos fiscales. Todo lo que involucra claves,
/// certificados o pedidos a ARCA lo hace el servidor (Cloud Functions).
class FacturacionRepository {
  FacturacionRepository(this._db);
  final Db _db;

  DocumentReference<Json> get _fiscal => _db.negocio.collection('meta').doc('fiscal');
  DocumentReference<Json> get _estado => _db.negocio.collection('meta').doc('arca');
  CollectionReference<Json> get _facturas => _db.negocio.collection('facturas');

  Stream<ConfigFiscal> config() => _fiscal.snapshots().map((d) => ConfigFiscal.fromMap(d.data()));

  Future<void> guardarConfig(ConfigFiscal c) => _fiscal.set(c.toMap());

  Stream<Map<AmbienteArca, EstadoArca>> estado() => _estado.snapshots().map((d) {
        final data = d.data() ?? const {};
        return {
          for (final a in AmbienteArca.values)
            a: EstadoArca.fromMap(data[a.valor] is Map ? Map<String, dynamic>.from(data[a.valor] as Map) : null),
        };
      });

  Stream<List<Factura>> delMes(DateTime mes) {
    final r = rangoDelMes(mes);
    return _facturas
        .where('creado', isGreaterThanOrEqualTo: r.desde)
        .where('creado', isLessThan: r.hasta)
        .orderBy('creado', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Factura.fromMap(d.id, d.data())).toList());
  }

  Stream<Factura?> observar(String id) =>
      _facturas.doc(id).snapshots().map((d) => d.exists ? Factura.fromMap(d.id, d.data()!) : null);

  Map<String, dynamic> get _base => {'negocioId': _db.negocioId};

  /// Genera la clave privada (queda en el servidor) y devuelve la solicitud
  /// de certificado (CSR) para cargar en ARCA.
  Future<String> generarSolicitud() async {
    final r = await Funciones.llamar('arcaGenerarSolicitud', _base);
    return r['csr'] as String? ?? '';
  }

  Future<void> guardarCertificado(String certificadoPem) =>
      Funciones.llamar('arcaGuardarCertificado', {..._base, 'certificado': certificadoPem});

  Future<String> probarConexion() async {
    final r = await Funciones.llamar('arcaProbarConexion', _base);
    return 'Conexión correcta. Último comprobante ${r['letra']} autorizado: ${r['ultimo']}.';
  }

  /// Emite la factura de un trabajo ('orden') o de un cobro ('pago').
  /// Devuelve el ID de la factura.
  Future<String> emitir({
    required String origenTipo,
    required String origenId,
    required ReceptorFactura receptor,
    required ConceptoFactura concepto,
  }) async {
    final r = await Funciones.llamar('arcaEmitirFactura', {
      ..._base,
      'origen': {'tipo': origenTipo, 'id': origenId},
      'receptor': receptor.toMap(),
      'concepto': concepto.valor,
    });
    return r['facturaId'] as String;
  }

  Future<void> reintentar(String facturaId) => Funciones.llamar('arcaReintentar', {..._base, 'facturaId': facturaId});

  /// Anula la factura con su nota de crédito.
  Future<void> anular(String facturaId) => Funciones.llamar('arcaAnularFactura', {..._base, 'facturaId': facturaId});
}
