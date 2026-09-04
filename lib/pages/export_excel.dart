import 'package:universal_html/html.dart' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

Future<void> exportarTodoExcel(String uid) async {
  try {
    // 1. Obtener datos de Firestore (Igual que antes)
    final clientesSnap = await FirebaseFirestore.instance
        .collection('users').doc(uid).collection('clientes')
        .orderBy('fechaRegistro').get();

    final reparacionesSnap = await FirebaseFirestore.instance
        .collection('users').doc(uid).collection('reparaciones')
        .orderBy('fechaIngreso').get();

    final presupuestosSnap = await FirebaseFirestore.instance
        .collection('users').doc(uid).collection('presupuestos')
        .orderBy('fecha').get();

    final excel = Excel.createExcel();

    // 2. ======== LÓGICA DE HOJAS SEGURA ========
    // En lugar de borrar o renombrar, agarramos la que ya viene (sea 'Sheet1' o como se llame)
    // y la usamos para los Clientes.
    String nombreHojaDefault = excel.tables.keys.first;
    var clientesSheet = excel[nombreHojaDefault];

    // Le ponemos los encabezados a la primera hoja
    clientesSheet.appendRow([
      'Nombre', 'Teléfono', 'Fecha de Registro', 'Historial de Reparaciones'
    ]);

    // Llenamos Clientes (Igual que antes)
    for (var clienteDoc in clientesSnap.docs) {
      final clienteData = clienteDoc.data();
      final historial = reparacionesSnap.docs
          .where((r) => r.data()['clienteId'] == clienteDoc.id)
          .map((r) {
        final data = r.data();
        final fecha = (data['fechaIngreso'] as Timestamp?)?.toDate();
        final fechaStr = fecha != null ? DateFormat('dd/MM/yyyy').format(fecha) : '-';
        return "${data['maquina'] ?? ''} - ${data['problema'] ?? ''} - \$${data['precio'] ?? 0} ($fechaStr)";
      }).join('\n');

      final fechaReg = (clienteData['fechaRegistro'] as Timestamp?)?.toDate();
      clientesSheet.appendRow([
        clienteData['nombre'] ?? '',
        clienteData['telefono'] ?? '',
        fechaReg != null ? DateFormat('dd/MM/yyyy').format(fechaReg) : '-',
        historial
      ]);
    }

    // 3. ======== HOJA REPARACIONES (NUEVA) ========
    var reparacionesSheet = excel['Reparaciones']; // Esto crea una hoja nueva sin tocar la default
    reparacionesSheet.appendRow([
      'Cliente', 'Máquina', 'Problema', 'Estado', 'Pago', 'Precio', 'Fecha Ingreso'
    ]);

    for (var rDoc in reparacionesSnap.docs) {
      final rData = rDoc.data();
      final clienteDoc = clientesSnap.docs.firstWhereOrNull((c) => c.id == rData['clienteId']);
      final fecha = (rData['fechaIngreso'] as Timestamp?)?.toDate();

      reparacionesSheet.appendRow([
        clienteDoc?.data()['nombre'] ?? 'Desconocido',
        rData['maquina'] ?? '',
        rData['problema'] ?? '',
        rData['estado'] ?? '',
        rData['estadoPago'] ?? 'pendiente',
        rData['precio'] ?? 0,
        fecha != null ? DateFormat('dd/MM/yyyy').format(fecha) : '-',
      ]);
    }

    // 4. ======== HOJA PRESUPUESTOS (NUEVA) ========
    var presupuestosSheet = excel['Presupuestos'];
    presupuestosSheet.appendRow(['Cliente', 'Fecha', 'Items', 'Total']);

    for (var pDoc in presupuestosSnap.docs) {
      final pData = pDoc.data();
      final clienteDoc = clientesSnap.docs.firstWhereOrNull((c) => c.id == pData['clienteId']);
      final fecha = (pData['fecha'] as Timestamp?)?.toDate();
      final itemsStr = (pData['items'] as List? ?? [])
          .map((i) => "${i['desc']} (\$${i['precio']})")
          .join(', ');

      presupuestosSheet.appendRow([
        clienteDoc?.data()['nombre'] ?? 'Desconocido',
        fecha != null ? DateFormat('dd/MM/yyyy').format(fecha) : '-',
        itemsStr,
        pData['total'] ?? 0,
      ]);
    }

    // 5. ======== DESCARGA (WEB) ========
    final excelBytes = excel.encode();
    if (excelBytes == null) return;

    final blob = html.Blob([excelBytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final nombreArchivo = 'Taller_${DateFormat('dd-MM-yyyy').format(DateTime.now())}.xlsx';

    html.AnchorElement(href: url)
      ..setAttribute('download', nombreArchivo)
      ..click();
    html.Url.revokeObjectUrl(url);

  } catch (e) {
    print("Error en Excel: $e");
    throw Exception('Error al generar el documento: $e');
  }
}