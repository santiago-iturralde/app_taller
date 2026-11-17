import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../db.dart';
import '../models/negocio.dart';

class NegocioRepository {
  NegocioRepository(this._db);
  final Db _db;

  Stream<Negocio?> observar() => _db.negocio
      .snapshots()
      .map((d) => d.exists ? Negocio.fromMap(d.id, d.data()!) : null);

  Future<void> guardar(Negocio negocio) => _db.negocio.update({
        ...negocio.datosEditables(),
        'actualizado': FieldValue.serverTimestamp(),
      });

  /// El logo se guarda aparte (no en el documento del negocio) para no
  /// descargarlo cada vez que se lee el negocio.
  Future<Uint8List?> logo() async {
    final d = await _db.branding.get();
    final b64 = d.data()?['logoBase64'] as String?;
    if (b64 == null || b64.isEmpty) return null;
    try {
      return base64Decode(b64);
    } on FormatException {
      return null;
    }
  }

  Future<void> guardarLogo(Uint8List? bytes) async {
    final batch = _db.fs.batch();
    batch.set(_db.branding, {'logoBase64': bytes == null ? null : base64Encode(bytes)});
    batch.update(_db.negocio, {'tieneLogo': bytes != null});
    await batch.commit();
  }
}
