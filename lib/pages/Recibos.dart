import 'dart:typed_data';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class RecibosTab extends StatefulWidget {
  final String uid;
  const RecibosTab({super.key, required this.uid});

  @override
  State<RecibosTab> createState() => _RecibosTabState();
}

class _RecibosTabState extends State<RecibosTab> {
  late CollectionReference<Map<String, dynamic>> recibosCol;
  late CollectionReference<Map<String, dynamic>> clientesCol;

  @override
  void initState() {
    super.initState();
    recibosCol = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .collection('recibos');
    clientesCol = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .collection('clientes');
  }

  void _openReciboForm(BuildContext context) {
    final _formKey = GlobalKey<FormState>();
    final _montoController = TextEditingController();
    final _conceptoController = TextEditingController();

    // Genera un número único basado en la fecha y hora (Ej: 20231027-1530)
    final String nroAutomatico = "${DateTime.now().year}${DateTime.now().month.toString().padLeft(2,'0')}${DateTime.now().day.toString().padLeft(2,'0')}-${DateTime.now().hour}${DateTime.now().minute}${DateTime.now().second}";

    String? selectedClientId;
    String? selectedClientName;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text("Nuevo Recibo", style: TextStyle(fontWeight: FontWeight.bold)),
            content: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: clientesCol.orderBy('nombre').snapshots(),
                      builder: (context, snap) {
                        if (!snap.hasData) return const CircularProgressIndicator();
                        final clientes = snap.data!.docs;
                        return DropdownButtonFormField<String>(
                          value: selectedClientId,
                          decoration: const InputDecoration(labelText: "Recibí de (Cliente)"),
                          items: clientes.map((doc) {
                            final data = doc.data();
                            return DropdownMenuItem(
                              value: doc.id,
                              child: Text(data['nombre'] ?? ''),
                            );
                          }).toList(),
                          onChanged: (val) {
                            final clientDoc = clientes.firstWhere((doc) => doc.id == val);
                            setState(() {
                              selectedClientId = val;
                              selectedClientName = clientDoc.data()['nombre'];
                            });
                          },
                          validator: (val) => val == null ? 'Seleccione un cliente' : null,
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _montoController,
                      decoration: const InputDecoration(
                        labelText: "La suma de \$ (Monto)",
                        prefixText: "\$ ",
                      ),
                      keyboardType: TextInputType.number,
                      validator: (val) => (val == null || val.isEmpty) ? 'Obligatorio' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _conceptoController,
                      decoration: const InputDecoration(
                        labelText: "En concepto de",
                        hintText: "Ej: Reparación de Notebook...",
                      ),
                      maxLines: 2,
                      validator: (val) => (val == null || val.isEmpty) ? 'Obligatorio' : null,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text("Guardar Recibo"),
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;
                  final monto = double.tryParse(_montoController.text) ?? 0;
                  await recibosCol.add({
                    'clienteId': selectedClientId,
                    'clienteNombre': selectedClientName,
                    'monto': monto,
                    'concepto': _conceptoController.text,
                    'fecha': Timestamp.now(),
                    'nroRecibo': nroAutomatico,
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  /// Generación del PDF Corregida
  Future<void> _generarPDFRecibo(BuildContext context, Map<String, dynamic> data) async {
    // Diálogo de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final pdf = pw.Document();

      // 1. Datos del Taller
      final tallerDoc = await FirebaseFirestore.instance.collection('users').doc(widget.uid).get();
      final tallerData = tallerDoc.data() ?? {};
      // Si no hay nombre, usamos un genérico
      final nombreTaller = tallerData['nombreTaller'] ?? 'Mi Taller';
      final direccion = tallerData['direccion'] ?? '';
      final telefono = tallerData['telefono'] ?? '';

      // 2. Datos del Recibo
      final fecha = (data['fecha'] as Timestamp).toDate();
      final fechaStr = DateFormat('dd/MM/yyyy').format(fecha);
      final cliente = data['clienteNombre'] ?? 'Consumidor Final';
      final monto = (data['monto'] as num).toStringAsFixed(2);
      final concepto = data['concepto'] ?? '';
      final nro = data['nroRecibo'] ?? '---';

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a5.landscape,
          build: (context) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 2),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // --- CABECERA ---
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      // IZQUIERDA: Datos del Taller (Expanded para evitar que se corten o muestren puntos)
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              nombreTaller.toUpperCase(),
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18),
                              maxLines: 2, // Permite 2 líneas si es muy largo
                            ),
                            if (direccion.isNotEmpty)
                              pw.Text(direccion, style: const pw.TextStyle(fontSize: 10)),
                            if (telefono.isNotEmpty)
                              pw.Text("Tel: $telefono", style: const pw.TextStyle(fontSize: 10)),
                          ],
                        ),
                      ),

                      pw.SizedBox(width: 20),

                      // DERECHA: Nro de Recibo y Fecha (Sin la caja X)
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text("RECIBO", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                          pw.Text("N° $nro", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.red900)),
                          pw.SizedBox(height: 5),
                          pw.Text("Fecha: $fechaStr", style: const pw.TextStyle(fontSize: 12)),
                          pw.SizedBox(height: 2),
                          pw.Text("Documento no válido como factura", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                        ],
                      ),
                    ],
                  ),

                  pw.Divider(thickness: 1, height: 20),

                  // --- CUERPO ---
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("Recibí de: ", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Expanded(
                        child: pw.Container(
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(bottom: pw.BorderSide(style: pw.BorderStyle.dotted)),
                          ),
                          child: pw.Text("  $cliente", style: pw.TextStyle(fontSize: 14)),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 15),
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("La suma de pesos: ", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Expanded(
                        child: pw.Container(
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(bottom: pw.BorderSide(style: pw.BorderStyle.dotted)),
                          ),
                          child: pw.Text("  \$ $monto", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 15),
                  pw.Text("En concepto de:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.symmetric(vertical: 5),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(style: pw.BorderStyle.dotted)),
                    ),
                    child: pw.Text(concepto, style: const pw.TextStyle(fontSize: 12)),
                  ),

                  pw.Spacer(),

                  // --- PIE ---
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Column(
                        children: [
                          pw.Container(width: 150, height: 1, color: PdfColors.black),
                          pw.SizedBox(height: 5),
                          pw.Text("Firma / Aclaración", style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                    ],
                  )
                ],
              ),
            );
          },
        ),
      );

      Navigator.pop(context); // Cierra loading
      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    } catch (e) {
      Navigator.pop(context); // Cierra loading
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _deleteRecibo(String docId) {
    recibosCol.doc(docId).delete();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Recibos Generados"),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openReciboForm(context),
        child: const Icon(Icons.note_add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: recibosCol.orderBy('fecha', descending: true).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 10),
                  Text("No hay recibos generados", style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final fecha = (data['fecha'] as Timestamp?)?.toDate();
              final fechaStr = fecha != null ? DateFormat('dd/MM/yyyy').format(fecha) : '-';
              final monto = (data['monto'] as num?) ?? 0;
              final nro = data['nroRecibo'] ?? '';

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.primary.withOpacity(0.1),
                    child: Icon(Icons.receipt, color: colorScheme.primary),
                  ),
                  title: Text("Recibo N° $nro"),
                  subtitle: Text("$fechaStr • ${data['clienteNombre'] ?? 'Cliente'}\n${data['concepto'] ?? ''}"),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("\$${monto.toStringAsFixed(0)}",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colorScheme.primary)),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: const Icon(Icons.print, color: Colors.grey),
                        onPressed: () => _generarPDFRecibo(context, data),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: colorScheme.error),
                        onPressed: () => _deleteRecibo(docs[index].id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}