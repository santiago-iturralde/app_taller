import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart'; // Para firstWhereOrNull

Future<void> exportarTodoExcel(String uid) async {
  try {
    // Obtener datos de Firestore
    final clientesSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('clientes')
        .orderBy('fechaRegistro')
        .get();

    final reparacionesSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('reparaciones')
        .orderBy('fechaIngreso')
        .get();

    final presupuestosSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('presupuestos')
        .orderBy('fecha')
        .get();

    final excel = Excel.createExcel();

    // ======== HOJA CLIENTES ========
    final clientesSheet = excel['Clientes'];
    clientesSheet.appendRow([
      'Nombre', 'Teléfono', 'Fecha de Registro', 'Historial de Reparaciones'
    ]);

    for (var clienteDoc in clientesSnap.docs) {
      final clienteData = clienteDoc.data();

      // Historial de reparaciones de este cliente
      final historial = reparacionesSnap.docs
          .where((r) => r['clienteId'] == clienteDoc.id)
          .map((r) {
        final fecha = (r['fechaIngreso'] as Timestamp?)?.toDate();
        final fechaStr = fecha != null ? DateFormat('dd/MM/yyyy').format(fecha) : '-';
        return "${r['maquina'] ?? ''} - ${r['problema'] ?? ''} - Estado: ${r['estado'] ?? ''}, Pago: ${r['estadoPago'] ?? 'pendiente'}, \$${r['precio'] ?? 0}, Ingreso: $fechaStr";
      }).join('\n');

      final fechaRegistro = (clienteData['fechaRegistro'] as Timestamp?)?.toDate();
      final fechaStr = fechaRegistro != null ? DateFormat('dd/MM/yyyy').format(fechaRegistro) : '-';

      clientesSheet.appendRow([
        clienteData['nombre'] ?? '',
        clienteData['telefono'] ?? '',
        fechaStr,
        historial
      ]);
    }

    // ======== HOJA REPARACIONES ========
    final reparacionesSheet = excel['Reparaciones'];
    reparacionesSheet.appendRow([
      'Cliente', 'Máquina', 'Problema', 'Estado Reparación', 'Estado de Pago', 'Precio', 'Fecha Ingreso'
    ]);

    for (var rDoc in reparacionesSnap.docs) {
      final rData = rDoc.data();

      final clienteDoc = clientesSnap.docs
          .firstWhereOrNull((c) => c.id == rData['clienteId']);
      final clienteNombre = clienteDoc?.data()['nombre'] ?? '';

      final fecha = (rData['fechaIngreso'] as Timestamp?)?.toDate();
      final fechaStr = fecha != null ? DateFormat('dd/MM/yyyy').format(fecha) : '-';

      reparacionesSheet.appendRow([
        clienteNombre,
        rData['maquina'] ?? '',
        rData['problema'] ?? '',
        rData['estado'] ?? '',
        rData['estadoPago'] ?? 'pendiente',
        rData['precio'] ?? 0,
        fechaStr,
      ]);
    }

    // ======== HOJA PRESUPUESTOS ========
    final presupuestosSheet = excel['Presupuestos'];
    presupuestosSheet.appendRow([
      'Cliente', 'Fecha', 'Items', 'Total'
    ]);

    for (var pDoc in presupuestosSnap.docs) {
      final pData = pDoc.data();

      final clienteDoc = clientesSnap.docs
          .firstWhereOrNull((c) => c.id == pData['clienteId']);
      final clienteNombre = clienteDoc?.data()['nombre'] ?? '';

      final fecha = (pData['fecha'] as Timestamp?)?.toDate();
      final fechaStr = fecha != null ? DateFormat('dd/MM/yyyy').format(fecha) : '-';

      final itemsStr = (pData['items'] as List<dynamic>? ?? [])
          .map((i) => "${i['desc']} - Cant: ${i['cantidad'] ?? 0}, \$${i['precio'] ?? 0}")
          .join('\n');

      presupuestosSheet.appendRow([
        clienteNombre,
        fechaStr,
        itemsStr,
        pData['total'] ?? 0,
      ]);
    }

    // ======== GENERAR Y DESCARGAR EXCEL ========
    final excelBytes = excel.encode();
    if (excelBytes == null) throw Exception('No se pudo generar el archivo Excel');

    final blob = html.Blob([excelBytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', 'TallerDatos.xlsx')
      ..click();
    html.Url.revokeObjectUrl(url);

    print('Exportación completada');
  } catch (e) {
    print('Error exportando Excel: $e');
  }
}
