import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../theme.dart'; // Importamos tu tema premium

class PresupuestosTab extends StatefulWidget {
  final String uid;
  const PresupuestosTab({super.key, required this.uid});

  @override
  State<PresupuestosTab> createState() => _PresupuestosTabState();
}

class _PresupuestosTabState extends State<PresupuestosTab> {
  late CollectionReference<Map<String, dynamic>> presupuestosCol;
  late CollectionReference<Map<String, dynamic>> clientesCol;

  @override
  void initState() {
    super.initState();
    presupuestosCol = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .collection('presupuestos');
    clientesCol = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .collection('clientes');
  }

  // Transformado a BottomSheet Moderno con ítems integrados
  void _openPresupuestoForm(BuildContext context, {String? docId, Map<String, dynamic>? currentData}) {
    final _formKey = GlobalKey<FormState>();

    String? selectedClientId = currentData != null ? currentData['clienteId'] : null;
    List<Map<String, dynamic>> items = currentData != null
        ? List<Map<String, dynamic>>.from(currentData['items'])
        : [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {

          void _addItem() {
            setState(() {
              items.add({'desc': '', 'cantidad': 1, 'precio': 0.0});
            });
          }

          void _removeItem(int index) {
            setState(() {
              items.removeAt(index);
            });
          }

          double _calcularTotal() {
            return items.fold(0.0, (double prev, item) => prev + (item['cantidad'] * item['precio']));
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 24,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    docId != null ? 'Editar Presupuesto' : 'Nuevo Presupuesto',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: clientesCol.orderBy('nombre').snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData) return const LinearProgressIndicator(color: AppTheme.primaryBlue);

                      final clientesDocs = snap.data!.docs;
                      final bool existeCliente = clientesDocs.any((doc) => doc.id == selectedClientId);

                      if (selectedClientId != null && !existeCliente) {
                        selectedClientId = null;
                      }

                      return DropdownButtonFormField<String>(
                        value: selectedClientId,
                        decoration: const InputDecoration(labelText: 'Cliente', prefixIcon: Icon(Icons.person_outline)),
                        items: clientesDocs.map((doc) {
                          final data = doc.data();
                          return DropdownMenuItem(
                            value: doc.id,
                            child: Text(data['nombre'] ?? ''),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => selectedClientId = val),
                        validator: (val) => val == null ? 'Seleccione un cliente' : null,
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  Expanded(
                    child: items.isEmpty
                        ? Center(
                      child: Text(
                        "No hay ítems agregados.\nToca '+ Agregar Ítem' para comenzar.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    )
                        : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: item['desc'],
                                      decoration: const InputDecoration(
                                        labelText: 'Descripción',
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                      onChanged: (val) => item['desc'] = val,
                                      validator: (val) => (val == null || val.isEmpty) ? 'Obligatorio' : null,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                    onPressed: () => _removeItem(index),
                                  )
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      initialValue: item['cantidad'].toString(),
                                      decoration: const InputDecoration(
                                        labelText: 'Cant.',
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                      keyboardType: TextInputType.number,
                                      onChanged: (val) => item['cantidad'] = int.tryParse(val) ?? 1,
                                      validator: (val) => (val == null || int.tryParse(val) == null) ? 'Número' : null,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 3,
                                    child: TextFormField(
                                      initialValue: item['precio'].toString(),
                                      decoration: const InputDecoration(
                                        labelText: 'Precio Unit.',
                                        prefixText: '\$ ',
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                      keyboardType: TextInputType.number,
                                      onChanged: (val) => item['precio'] = double.tryParse(val) ?? 0.0,
                                      validator: (val) => (val == null || double.tryParse(val) == null) ? 'Número' : null,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  TextButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Agregar Ítem'),
                    style: TextButton.styleFrom(foregroundColor: AppTheme.primaryBlue),
                  ),
                  const Divider(),

                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Total Presupuesto:", style: TextStyle(fontSize: 12, color: Colors.grey)),
                            Text(
                              '\$${_calcularTotal().toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            if (!_formKey.currentState!.validate()) return;
                            if (items.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Agrega al menos un ítem.")));
                              return;
                            }

                            final data = {
                              'clienteId': selectedClientId,
                              'items': items,
                              'total': _calcularTotal(),
                              'fecha': Timestamp.now(),
                            };

                            if (docId != null) {
                              presupuestosCol.doc(docId).update(data);
                            } else {
                              presupuestosCol.add(data);
                            }
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.save),
                          label: const Text('Guardar'),
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _deletePresupuesto(String docId) async {
    bool confirmar = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¿Eliminar?"),
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
      await presupuestosCol.doc(docId).delete();
    }
  }

  // --- TU LÓGICA DE PDF INTACTA ---
  Future<void> _generarPDF(Map<String, dynamic> presupuesto) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue)),
    );

    try {
      final pdf = pw.Document();

      final tallerDoc = await FirebaseFirestore.instance.collection('users').doc(widget.uid).get();
      final taller = tallerDoc.data() ?? {};
      final nombreTaller = taller['nombreTaller'] ?? '';
      final direccion = taller['direccion'] ?? '';
      final telefono = taller['telefono'] ?? '';
      final email = taller['email'] ?? '';

      pw.MemoryImage? logoImage;
      if (taller['logoBase64'] != null && taller['logoBase64'].isNotEmpty) {
        try {
          final bytes = base64Decode(taller['logoBase64']);
          logoImage = pw.MemoryImage(bytes);
        } catch (_) {}
      }

      String clienteNombre = '-';
      try {
        if (presupuesto['clienteId'] != null) {
          final clienteSnap = await clientesCol.doc(presupuesto['clienteId']).get();
          if (clienteSnap.exists) {
            clienteNombre = clienteSnap.data()?['nombre'] ?? '-';
          }
        }
      } catch (_) {}

      final fecha = (presupuesto['fecha'] as Timestamp).toDate();
      final fechaStr = DateFormat('dd/MM/yyyy').format(fecha);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: const pw.BoxDecoration(
                    gradient: pw.LinearGradient(
                      colors: [PdfColors.cyan50, PdfColors.cyan100],
                      begin: pw.Alignment.topLeft,
                      end: pw.Alignment.bottomRight,
                    ),
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(12)),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      if (logoImage != null) pw.Image(logoImage, width: 80, height: 80),
                      if (logoImage != null) pw.SizedBox(width: 16),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(nombreTaller, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo)),
                          if (direccion.isNotEmpty) pw.Text(direccion),
                          if (telefono.isNotEmpty) pw.Text("Tel: $telefono"),
                          if (email.isNotEmpty) pw.Text(email),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.Divider(height: 32, thickness: 2, color: PdfColors.grey300),
                pw.Text('Presupuesto', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Text('Cliente: $clienteNombre'),
                pw.Text('Fecha: $fechaStr'),
                pw.SizedBox(height: 20),
                pw.Column(
                  children: (presupuesto['items'] as List<dynamic>).map((item) {
                    return pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 4),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Expanded(child: pw.Text('${item['desc']}')),
                          pw.Text('${item['cantidad']} x \$${item['precio']}'),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                pw.Divider(height: 24),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text('Total: \$${(presupuesto['total'] as num).toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
                ),
              ],
            );
          },
        ),
      );

      Navigator.pop(context); // Cierra loading
      // Formateamos el nombre del archivo para que no tenga espacios raros
      final String nombreArchivo = 'Presupuesto_${clienteNombre.replaceAll(' ', '_')}.pdf';

      // Abrimos el menú de compartir del celular
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: nombreArchivo,
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al generar PDF: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openPresupuestoForm(context),
        icon: const Icon(Icons.add),
        label: const Text("Nuevo Presupuesto"),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: presupuestosCol.orderBy('fecha', descending: true).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue));

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.request_quote_outlined, size: 80, color: AppTheme.primaryBlue.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  const Text("No hay presupuestos registrados", style: TextStyle(color: Colors.grey, fontSize: 16)),
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

              return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: clientesCol.doc(data['clienteId']).get(),
                builder: (context, clienteSnap) {
                  String clienteNombre = "Cargando...";

                  if (clienteSnap.connectionState == ConnectionState.done) {
                    if (clienteSnap.hasError) {
                      clienteNombre = "Error al cargar cliente";
                    } else if (clienteSnap.hasData && clienteSnap.data!.exists) {
                      clienteNombre = clienteSnap.data!.data()?['nombre'] ?? 'Sin nombre';
                    } else {
                      clienteNombre = 'Cliente eliminado';
                    }
                  }

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  clienteNombre,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: (clienteNombre == 'Cliente eliminado') ? Colors.red : AppTheme.primaryBlue,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(fechaStr, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                            ],
                          ),
                          const Divider(height: 24),

                          const Text("Ítems Presupuestados:", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 8),
                          ...List.generate((data['items'] as List<dynamic>).length, (i) {
                            final item = (data['items'] as List<dynamic>)[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("• ", style: TextStyle(color: AppTheme.primaryBlue)),
                                  Expanded(child: Text("${item['desc']}", style: TextStyle(color: Colors.grey.shade800))),
                                  Text(
                                    "${item['cantidad']} x \$${item['precio']}",
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const Divider(height: 24),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("TOTAL", style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  Text(
                                    "\$${(data['total'] as num).toStringAsFixed(2)}",
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.green),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    tooltip: "Generar PDF",
                                    icon: const Icon(Icons.picture_as_pdf, color: AppTheme.primaryBlue),
                                    onPressed: () => _generarPDF(data),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  const SizedBox(width: 16),
                                  IconButton(
                                    tooltip: "Editar",
                                    icon: const Icon(Icons.edit, color: Colors.grey),
                                    onPressed: () => _openPresupuestoForm(context, docId: docId, currentData: data),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  const SizedBox(width: 16),
                                  IconButton(
                                    tooltip: "Eliminar",
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                    onPressed: () => _deletePresupuesto(docId),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
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
          );
        },
      ),
    );
  }
}