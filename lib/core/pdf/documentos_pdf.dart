import 'dart:typed_data';

import 'package:flutter/widgets.dart' show BuildContext;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../app/sesion.dart';
import '../../data/models/caja.dart';
import '../../data/models/comunes.dart';
import '../../data/models/fiscal.dart';
import '../../data/models/negocio.dart';
import '../../data/models/orden.dart';
import '../../data/models/presupuesto.dart';
import '../utils/formato.dart';
import '../widgets/feedback.dart';

/// Genera los comprobantes en PDF con un diseño único para todo el sistema.
class DocumentosPdf {
  DocumentosPdf._(this.negocio, this.logo, this._tema);

  final Negocio negocio;
  final Uint8List? logo;
  final pw.ThemeData _tema;

  static const _acento = PdfColor.fromInt(0xFF2346D8);
  static const _gris = PdfColor.fromInt(0xFF64748B);
  static const _borde = PdfColor.fromInt(0xFFE2E8F0);
  static const _fondo = PdfColor.fromInt(0xFFF8FAFC);

  static Future<DocumentosPdf> crear(Sesion sesion) async {
    final logo = await sesion.negocioRepo.logo();
    pw.ThemeData tema;
    try {
      tema = pw.ThemeData.withFont(
        base: await PdfGoogleFonts.interRegular(),
        bold: await PdfGoogleFonts.interBold(),
      );
    } catch (_) {
      tema = pw.ThemeData.base(); // Sin conexión: tipografía estándar.
    }
    return DocumentosPdf._(sesion.negocio, logo, tema);
  }

  /// Genera el PDF y abre la vista previa para imprimir, guardar o compartir.
  static Future<void> abrir(
    BuildContext context, {
    required String nombreArchivo,
    required Future<Uint8List> Function(DocumentosPdf pdf) generar,
  }) async {
    final sesion = Sesion.of(context);
    await ejecutar(context, () async {
      final docs = await crear(sesion);
      final bytes = await generar(docs);
      await Printing.layoutPdf(name: nombreArchivo, onLayout: (_) async => bytes);
    });
  }

  // ------------------------------------------------------------- Documentos

  Future<Uint8List> orden(Orden o) {
    final rubro = negocio.rubro;
    return _documento(
      titulo: 'ORDEN DE TRABAJO',
      numero: o.numero,
      fecha: o.fechaIngreso,
      contenido: [
        _bloqueCliente(o.clienteNombre, o.clienteTelefono),
        pw.SizedBox(height: 14),
        _caja(rubro.equipo.toUpperCase(), [
          _dato('Descripción', o.equipo.descripcion),
          if (o.equipo.identificador.isNotEmpty) _dato(rubro.identificador, o.equipo.identificador),
          if (o.equipo.kilometraje != null) _dato('Kilometraje', '${Formato.cantidad(o.equipo.kilometraje!)} km'),
          if (o.fechaEstimada != null) _dato('Entrega estimada', Formato.fecha(o.fechaEstimada!)),
        ]),
        pw.SizedBox(height: 14),
        _caja('TRABAJO SOLICITADO', [pw.Text(o.problema.isEmpty ? '-' : o.problema)]),
        if (o.items.isNotEmpty) ...[
          pw.SizedBox(height: 18),
          _tablaItems(o.items),
          _totales([
            ('Total', o.total, true),
            if (o.pagado > 0) ('Pagado', o.pagado, false),
            if (o.pagado > 0) ('Saldo', o.saldo, true),
          ]),
        ],
        pw.SizedBox(height: 50),
        _firmas(),
      ],
    );
  }

  Future<Uint8List> presupuesto(Presupuesto p) => _documento(
        titulo: 'PRESUPUESTO',
        numero: p.numero,
        fecha: p.fecha,
        contenido: [
          _bloqueCliente(p.clienteNombre, p.clienteTelefono),
          if (p.equipo.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            _caja(negocio.rubro.equipo.toUpperCase(), [pw.Text(p.equipo)]),
          ],
          pw.SizedBox(height: 18),
          _tablaItems(p.items),
          _totales([('Total', p.total, true)]),
          pw.SizedBox(height: 18),
          pw.Text(
            'Validez: ${p.validezDias} días (hasta el ${Formato.fecha(p.vence)}).',
            style: const pw.TextStyle(color: _gris, fontSize: 9),
          ),
          if (p.notas.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            _caja('OBSERVACIONES', [pw.Text(p.notas)]),
          ],
        ],
      );

  Future<Uint8List> recibo(Pago p) => _documento(
        titulo: 'RECIBO',
        numero: p.numero,
        fecha: p.fecha,
        formato: PdfPageFormat.a5.landscape,
        contenido: [
          if (p.anulado)
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 10),
              padding: const pw.EdgeInsets.all(6),
              color: PdfColors.red50,
              child: pw.Text('ANULADO', style: pw.TextStyle(color: PdfColors.red800, fontWeight: pw.FontWeight.bold)),
            ),
          _lineaRecibo('Recibí de', p.clienteNombre.isEmpty ? 'Consumidor final' : p.clienteNombre),
          _lineaRecibo('La suma de', Formato.moneda(p.monto), destacado: true),
          _lineaRecibo('En concepto de', p.concepto.isEmpty ? '-' : p.concepto),
          _lineaRecibo('Forma de pago', p.medio.etiqueta),
          if (p.esVenta) ...[pw.SizedBox(height: 6), _tablaItems(p.items)],
          pw.SizedBox(height: 36),
          pw.Align(alignment: pw.Alignment.centerRight, child: _lineaFirma('Firma y aclaración')),
        ],
      );


  /// Factura o nota de crédito electrónica con el formato exigido por ARCA:
  /// letra y código, datos del emisor y receptor, CAE y código QR.
  Future<Uint8List> factura(Factura f) async {
    final e = f.emisor;
    final prueba = f.ambiente == AmbienteArca.homologacion;
    final doc = pw.Document(theme: _tema, title: '${f.nombreTipo} ${f.numeroCompleto}', author: '${e['razonSocial'] ?? negocio.nombre}');
    final condicionEmisor = CondicionIva.desde(e['condicionIva'] as String?, porDefecto: CondicionIva.monotributo).etiqueta;

    pw.Widget dato(String etiqueta, String valor) => pw.RichText(
          text: pw.TextSpan(children: [
            pw.TextSpan(text: '$etiqueta: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
            pw.TextSpan(text: valor, style: const pw.TextStyle(fontSize: 8.5)),
          ]),
        );

    final encabezado = pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey700)),
      child: pw.Stack(alignment: pw.Alignment.topCenter, children: [
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(10),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                if (logo != null) pw.Container(height: 42, margin: const pw.EdgeInsets.only(bottom: 6), child: pw.Image(pw.MemoryImage(logo!))),
                pw.Text('${e['razonSocial'] ?? ''}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                if ('${e['domicilio'] ?? ''}'.isNotEmpty) dato('Domicilio', '${e['domicilio']}'),
                dato('Condición frente al IVA', condicionEmisor),
              ]),
            ),
          ),
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(40, 10, 10, 10),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(f.esNotaCredito ? 'NOTA DE CRÉDITO' : 'FACTURA', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                dato('Punto de venta - N°', f.numeroCompleto),
                dato('Fecha de emisión', f.fecha == null ? '-' : Formato.fecha(f.fecha!)),
                dato('CUIT', '${e['cuit'] ?? ''}'),
                if ('${e['ingresosBrutos'] ?? ''}'.isNotEmpty) dato('Ingresos Brutos', '${e['ingresosBrutos']}'),
                if ('${e['inicioActividades'] ?? ''}'.isNotEmpty) dato('Inicio de actividades', '${e['inicioActividades']}'),
              ]),
            ),
          ),
        ]),
        // Recuadro central con la letra y el código del comprobante.
        pw.Container(
          width: 46,
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          decoration: pw.BoxDecoration(color: PdfColors.white, border: pw.Border.all(color: PdfColors.grey700)),
          child: pw.Column(children: [
            pw.Text(f.letra, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.Text('COD. ${f.codigo}', style: const pw.TextStyle(fontSize: 6.5)),
          ]),
        ),
      ]),
    );

    final receptor = pw.Container(
      margin: const pw.EdgeInsets.only(top: 6),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey700)),
      child: pw.Row(children: [
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            dato('Apellido y nombre / Razón social', f.receptorNombre),
            dato('Condición frente al IVA', f.receptorCondicion.etiqueta),
          ]),
        ),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          dato('Documento', f.documentoReceptor),
          dato('Condición de venta', 'Contado'),
        ]),
      ]),
    );

    final filasTotales = <(String, double, bool)>[
      if (f.discriminaIva) ('Importe neto gravado', f.neto, false),
      if (f.discriminaIva) ('IVA ${Formato.cantidad(f.alicuota ?? 0)}%', f.iva, false),
      ('Importe total', f.total, true),
    ];

    final pie = pw.Container(
      margin: const pw.EdgeInsets.only(top: 12),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey700)),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
        if (f.qr != null) pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: f.qr!, width: 78, height: 78),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Comprobante autorizado', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('Esta Administración Federal no se responsabiliza por los datos ingresados en el detalle de la operación.',
                style: const pw.TextStyle(fontSize: 7, color: _gris)),
          ]),
        ),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          dato('CAE N°', f.cae ?? '-'),
          dato('Fecha de vto. de CAE', f.caeVence == null ? '-' : Formato.fecha(f.caeVence!)),
        ]),
      ]),
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      header: (_) => pw.Column(children: [
        if (prueba)
          pw.Container(
            width: double.infinity,
            margin: const pw.EdgeInsets.only(bottom: 6),
            padding: const pw.EdgeInsets.all(4),
            color: PdfColors.amber100,
            child: pw.Text('COMPROBANTE DE PRUEBA (HOMOLOGACIÓN) - SIN VALIDEZ FISCAL',
                textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
          ),
        encabezado,
        receptor,
        if (f.asociada != null)
          pw.Padding(padding: const pw.EdgeInsets.only(top: 4), child: dato('Comprobante asociado', f.asociada!)),
        pw.SizedBox(height: 10),
      ]),
      footer: (_) => pie,
      build: (_) => [
        _tablaItems(f.items),
        _totales(filasTotales),
      ],
    ));
    return doc.save();
  }

  // --------------------------------------------------------------- Bloques

  Future<Uint8List> _documento({
    required String titulo,
    required int numero,
    required DateTime fecha,
    required List<pw.Widget> contenido,
    PdfPageFormat formato = PdfPageFormat.a4,
  }) async {
    final doc = pw.Document(theme: _tema, title: '$titulo ${Formato.numeroComprobante(numero)}', author: negocio.nombre);
    doc.addPage(pw.MultiPage(
      pageFormat: formato,
      margin: const pw.EdgeInsets.all(32),
      header: (_) => _encabezado(titulo, numero, fecha),
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Documento no válido como factura', style: const pw.TextStyle(color: _gris, fontSize: 8)),
          pw.Text('Página ${ctx.pageNumber} de ${ctx.pagesCount}', style: const pw.TextStyle(color: _gris, fontSize: 8)),
        ],
      ),
      build: (_) => contenido,
    ));
    return doc.save();
  }

  pw.Widget _encabezado(String titulo, int numero, DateTime fecha) {
    final contacto = [
      negocio.direccion,
      if (negocio.telefono.isNotEmpty) 'Tel: ${negocio.telefono}',
      negocio.email,
      if (negocio.cuit.isNotEmpty) 'CUIT: ${negocio.cuit}',
    ].where((e) => e.isNotEmpty).toList();

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      padding: const pw.EdgeInsets.only(bottom: 14),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _acento, width: 2))),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (logo != null) ...[
            pw.Container(width: 56, height: 56, child: pw.Image(pw.MemoryImage(logo!), fit: pw.BoxFit.contain)),
            pw.SizedBox(width: 12),
          ],
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(negocio.nombre, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 3),
                for (final c in contacto) pw.Text(c, style: const pw.TextStyle(fontSize: 9, color: _gris)),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(titulo, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _acento)),
              pw.Text('N° ${Formato.numeroComprobante(numero)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 3),
              pw.Text('Fecha: ${Formato.fecha(fecha)}', style: const pw.TextStyle(fontSize: 9, color: _gris)),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _bloqueCliente(String nombre, String telefono) => _caja('CLIENTE', [
        pw.Text(nombre, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        if (telefono.isNotEmpty) pw.Text('Tel: $telefono', style: const pw.TextStyle(color: _gris, fontSize: 9)),
      ]);

  pw.Widget _caja(String titulo, List<pw.Widget> hijos) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: _fondo,
          border: pw.Border.all(color: _borde),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(titulo, style: pw.TextStyle(fontSize: 8, color: _gris, fontWeight: pw.FontWeight.bold, letterSpacing: 0.8)),
            pw.SizedBox(height: 4),
            ...hijos,
          ],
        ),
      );

  pw.Widget _dato(String etiqueta, String valor) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
        child: pw.Row(children: [
          pw.SizedBox(width: 110, child: pw.Text(etiqueta, style: const pw.TextStyle(color: _gris, fontSize: 9.5))),
          pw.Expanded(child: pw.Text(valor.isEmpty ? '-' : valor)),
        ]),
      );

  pw.Widget _tablaItems(List<ItemLinea> items) => pw.TableHelper.fromTextArray(
        headers: ['Descripción', 'Cant.', 'Precio unit.', 'Subtotal'],
        data: [
          for (final i in items)
            [i.descripcion, Formato.cantidad(i.cantidad), Formato.moneda(i.precioUnitario), Formato.moneda(i.subtotal)],
        ],
        border: null,
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9.5),
        headerDecoration: const pw.BoxDecoration(color: _acento),
        cellStyle: const pw.TextStyle(fontSize: 9.5),
        rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _borde, width: 0.6))),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        columnWidths: {
          0: const pw.FlexColumnWidth(5),
          1: const pw.FlexColumnWidth(1),
          2: const pw.FlexColumnWidth(2),
          3: const pw.FlexColumnWidth(2),
        },
        cellAlignments: {
          0: pw.Alignment.centerLeft,
          1: pw.Alignment.center,
          2: pw.Alignment.centerRight,
          3: pw.Alignment.centerRight,
        },
      );

  pw.Widget _totales(List<(String, double, bool)> filas) => pw.Container(
        alignment: pw.Alignment.centerRight,
        padding: const pw.EdgeInsets.only(top: 8),
        child: pw.SizedBox(
          width: 220,
          child: pw.Column(children: [
            for (final f in filas)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(f.$1, style: pw.TextStyle(fontWeight: f.$3 ? pw.FontWeight.bold : null)),
                    pw.Text(
                      Formato.moneda(f.$2),
                      style: pw.TextStyle(fontWeight: f.$3 ? pw.FontWeight.bold : null, fontSize: f.$3 ? 12 : 10),
                    ),
                  ],
                ),
              ),
          ]),
        ),
      );

  pw.Widget _lineaRecibo(String etiqueta, String valor, {bool destacado = false}) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 10),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.SizedBox(width: 110, child: pw.Text('$etiqueta:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 2),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: _borde, style: pw.BorderStyle.dotted)),
                ),
                child: pw.Text(valor, style: pw.TextStyle(fontSize: destacado ? 14 : 11, fontWeight: destacado ? pw.FontWeight.bold : null)),
              ),
            ),
          ],
        ),
      );

  pw.Widget _lineaFirma(String texto) => pw.Column(children: [
        pw.Container(width: 170, height: 0.8, color: PdfColors.grey700),
        pw.SizedBox(height: 4),
        pw.Text(texto, style: const pw.TextStyle(fontSize: 8.5, color: _gris)),
      ]);

  pw.Widget _firmas() => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [_lineaFirma('Firma del cliente'), _lineaFirma('Recibido por')],
      );
}

/// Nombre de archivo seguro: "Presupuesto_00012_Juan_Perez.pdf".
String nombreArchivoPdf(String tipo, int numero, String cliente) {
  final limpio = cliente.trim().replaceAll(RegExp(r'[^\wáéíóúñÁÉÍÓÚÑ]+'), '_');
  return '${tipo}_${Formato.numeroComprobante(numero)}${limpio.isEmpty ? '' : '_$limpio'}.pdf';
}
