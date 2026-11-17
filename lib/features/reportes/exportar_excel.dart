import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:universal_html/html.dart' as html;

import '../../app/sesion.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/feedback.dart';
import '../../data/models/caja.dart';
import '../../data/models/cliente.dart';
import '../../data/models/negocio.dart';
import '../../data/models/orden.dart';
import '../../data/models/presupuesto.dart';
import '../planes/pro.dart';

/// Descarga un Excel con todos los datos del negocio (una hoja por tipo).
Future<void> exportarExcel(BuildContext context) async {
  if (!await exigirPro(context, FuncionPro.exportarExcel) || !context.mounted) return;
  if (!kIsWeb) {
    mostrarMensaje(context, 'La exportación a Excel está disponible desde la versión web.', error: true);
    return;
  }
  final s = Sesion.of(context);
  mostrarMensaje(context, 'Preparando el archivo…');
  await ejecutar(context, () async {
    final db = s.db;
    final resultados = await Future.wait([
      db.clientes.get(),
      db.ordenes.orderBy('numero').get(),
      db.presupuestos.orderBy('numero').get(),
      db.pagos.orderBy('numero').get(),
      db.gastos.orderBy('fecha').get(),
    ]);
    final rubro = s.negocio.rubro;
    final excel = Excel.createExcel();
    final hojaInicial = excel.getDefaultSheet()!;

    void hoja(String nombre, List<String> encabezados, Iterable<List<Object?>> filas) {
      final h = excel[nombre];
      h.appendRow(encabezados.map(TextCellValue.new).toList());
      for (final f in filas) {
        h.appendRow(f.map<CellValue?>((v) => switch (v) {
              null => null,
              num n => DoubleCellValue(n.toDouble()),
              DateTime d => TextCellValue(Formato.fecha(d)),
              _ => TextCellValue(v.toString()),
            }).toList());
      }
    }

    hoja('Clientes', ['Nombre', 'Teléfono', 'DNI/CUIT', 'Email', 'Dirección', 'Alta'], [
      for (final d in resultados[0].docs)
        () {
          final c = Cliente.fromMap(d.id, d.data());
          return [c.nombre, c.telefono, c.documento, c.email, c.direccion, c.fechaAlta];
        }(),
    ]);
    hoja('Trabajos', ['N°', 'Ingreso', 'Cliente', rubro.equipo, rubro.identificador, 'Trabajo', 'Estado', 'Total', 'Cobrado', 'Saldo', 'Entrega'], [
      for (final d in resultados[1].docs)
        () {
          final o = Orden.fromMap(d.id, d.data());
          return [o.numero, o.fechaIngreso, o.clienteNombre, o.equipo.descripcion, o.equipo.identificador, o.problema, o.estado.etiqueta, o.total, o.pagado, o.saldo, o.fechaEntrega];
        }(),
    ]);
    hoja('Presupuestos', ['N°', 'Fecha', 'Cliente', 'Detalle', 'Total', 'Estado'], [
      for (final d in resultados[2].docs)
        () {
          final p = Presupuesto.fromMap(d.id, d.data());
          return [p.numero, p.fecha, p.clienteNombre, p.items.map((i) => i.descripcion).join(', '), p.total, p.estado.etiqueta];
        }(),
    ]);
    hoja('Cobros', ['Recibo N°', 'Fecha', 'Cliente', 'Concepto', 'Forma de pago', 'Monto', 'Estado'], [
      for (final d in resultados[3].docs)
        () {
          final p = Pago.fromMap(d.id, d.data());
          return [p.numero, p.fecha, p.clienteNombre, p.concepto, p.medio.etiqueta, p.monto, p.anulado ? 'Anulado' : (p.excluirDeCaja ? 'Histórico' : 'Válido')];
        }(),
    ]);
    hoja('Gastos', ['Fecha', 'Descripción', 'Categoría', 'Forma de pago', 'Monto'], [
      for (final d in resultados[4].docs)
        () {
          final g = Gasto.fromMap(d.id, d.data());
          return [g.fecha, g.descripcion, g.categoria, g.medio.etiqueta, g.monto];
        }(),
    ]);
    excel.delete(hojaInicial);

    final bytes = excel.encode();
    if (bytes == null) throw Exception('No se pudo generar el archivo');
    final url = html.Url.createObjectUrlFromBlob(html.Blob([Uint8List.fromList(bytes)]));
    html.AnchorElement(href: url)
      ..download = '${s.negocio.nombre.replaceAll(RegExp(r'[^\w]+'), '_')}_${Formato.fecha(DateTime.now()).replaceAll('/', '-')}.xlsx'
      ..click();
    html.Url.revokeObjectUrl(url);
  }, exito: 'Excel descargado');
}
