import 'dart:typed_data';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../theme.dart'; // Importamos tu tema premium

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

  // --- Transformado a BottomSheet Moderno ---
  void _openReciboForm(BuildContext context) {
    final _formKey = GlobalKey<FormState>();
    final _montoController = TextEditingController();
    final _conceptoController = TextEditingController();

    // Genera un número único basado en la fecha y hora
    final String nroAutomatico = "${DateTime.now().year}${DateTime.now().month.toString().padLeft(2,'0')}${DateTime.now().day.toString().padLeft(2,'0')}-${DateTime.now().hour}${DateTime.now().minute}${DateTime.now().second}";

    String? selectedClientId;
    String? selectedClientName;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 24,
            ),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      "Nuevo Recibo",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: clientesCol.orderBy('nombre').snapshots(),
                      builder: (context, snap) {
                        if (!snap.hasData) return const LinearProgressIndicator(color: AppTheme.primaryBlue);
                        final clientes = snap.data!.docs;
                        return DropdownButtonFormField<String>(
                          value: selectedClientId,
                          decoration: const InputDecoration(
                            labelText: "Recibí de (Cliente)",
                            prefixIcon: Icon(Icons.person_outline),
                          ),
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
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _montoController,
                      decoration: const InputDecoration(
                        labelText: "La suma de \$ (Monto)",
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (val) => (val == null || val.isEmpty) ? 'Obligatorio' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _conceptoController,
                      decoration: const InputDecoration(
                        labelText: "En concepto de",
                        hintText: "Ej: Reparación de Notebook...",
                        prefixIcon: Icon(Icons.description_outlined),
                      ),
                      maxLines: 2,
                      validator: (val) => (val == null || val.isEmpty) ? 'Obligatorio' : null,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text("Generar y Guardar Recibo"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
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
                        if (mounted) Navigator.pop(context);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- TU LÓGICA DE PDF INTACTA ---
  Future<void> _generarPDFRecibo(BuildContext context, Map<String, dynamic> data) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue)),
    );

    try {
      final pdf = pw.Document();

      final tallerDoc = await FirebaseFirestore.instance.collection('users').doc(widget.uid).get();
      final tallerData = tallerDoc.data() ?? {};
      final nombreTaller = tallerData['nombreTaller'] ?? 'Mi Taller';
      final direccion = tallerData['direccion'] ?? '';
      final telefono = tallerData['telefono'] ?? '';

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
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 2)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(nombreTaller.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18), maxLines: 2),
                            if (direccion.isNotEmpty) pw.Text(direccion, style: const pw.TextStyle(fontSize: 10)),
                            if (telefono.isNotEmpty) pw.Text("Tel: $telefono", style: const pw.TextStyle(fontSize: 10)),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 20),
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
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("Recibí de: ", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Expanded(
                        child: pw.Container(
                          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(style: pw.BorderStyle.dotted))),
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
                          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(style: pw.BorderStyle.dotted))),
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
                    decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(style: pw.BorderStyle.dotted))),
                    child: pw.Text(concepto, style: const pw.TextStyle(fontSize: 12)),
                  ),
                  pw.Spacer(),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent));
    }
  }

  void _deleteRecibo(String docId) async {
    bool confirmar = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¿Eliminar Recibo?"),
        content: const Text("Esta acción no se puede deshacer."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Eliminar"),
          ),
        ],
      ),
    ) ?? false;

    if (confirmar) {
      await recibosCol.doc(docId).delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Recibos Generados"),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openReciboForm(context),
        icon: const Icon(Icons.note_add),
        label: const Text("Nuevo Recibo"),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: recibosCol.orderBy('fecha', descending: true).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue));
          final docs = snap.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 80, color: AppTheme.primaryBlue.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  const Text("No hay recibos generados", style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 80),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final docId = docs[index].id;
              final fecha = (data['fecha'] as Timestamp?)?.toDate();
              final fechaStr = fecha != null ? DateFormat('dd/MM/yyyy').format(fecha) : '-';
              final monto = (data['monto'] as num?) ?? 0;
              final nro = data['nroRecibo'] ?? '';

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Recibo N° $nro",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryBlue),
                          ),
                          Text(
                            "\$${monto.toStringAsFixed(2)}",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            data['clienteNombre'] ?? 'Cliente Desconocido',
                            style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Concepto: ${data['concepto'] ?? ''}",
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          Text(fechaStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          const Spacer(),
                          TextButton.icon(
                            icon: const Icon(Icons.print, size: 18),
                            label: const Text("Imprimir"),
                            style: TextButton.styleFrom(foregroundColor: AppTheme.primaryBlue),
                            onPressed: () => _generarPDFRecibo(context, data),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: () => _deleteRecibo(docId),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
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