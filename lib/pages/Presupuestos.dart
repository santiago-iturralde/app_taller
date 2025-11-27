import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'dart:convert';
import 'dart:typed_data';

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

  void _openPresupuestoForm(BuildContext context,
      {String? docId, Map<String, dynamic>? currentData}) {
    final _formKey = GlobalKey<FormState>();

    // Guardamos el ID original que viene del presupuesto
    String? selectedClientId = currentData != null ? currentData['clienteId'] : null;

    List<Map<String, dynamic>> items = currentData != null
        ? List<Map<String, dynamic>>.from(currentData['items'])
        : [];

    void _addItem() {
      final _descController = TextEditingController();
      final _cantidadController = TextEditingController();
      final _precioController = TextEditingController();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Agregar Ítem',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Descripción'),
                validator: (value) => (value == null || value.isEmpty) ? 'Obligatorio' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _cantidadController,
                decoration: const InputDecoration(labelText: 'Cantidad'),
                keyboardType: TextInputType.number,
                validator: (value) => (value == null || value.isEmpty) ? 'Obligatorio' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _precioController,
                decoration: const InputDecoration(labelText: 'Precio unitario'),
                keyboardType: TextInputType.number,
                validator: (value) => (value == null || value.isEmpty) ? 'Obligatorio' : null,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Agregar'),
              onPressed: () {
                final cantidad = int.tryParse(_cantidadController.text) ?? 1;
                final precio = double.tryParse(_precioController.text) ?? 0;
                if (_descController.text.isEmpty) return;
                items.add({
                  'desc': _descController.text,
                  'cantidad': cantidad,
                  'precio': precio
                });
                setState(() {});
                Navigator.pop(context);
              },
            ),
          ],
        ),
      );
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          scrollable: true,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
              docId != null ? 'Editar Presupuesto' : 'Nuevo Presupuesto',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: clientesCol.orderBy('nombre').snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData) return const CircularProgressIndicator();

                    final clientesDocs = snap.data!.docs;

                    // --- CORRECCIÓN DE SEGURIDAD PARA DROPDOWN ---
                    // Verificamos si el ID guardado (selectedClientId) existe en la lista actual de clientes
                    final bool existeCliente = clientesDocs.any((doc) => doc.id == selectedClientId);

                    // Si el ID guardado NO existe en la lista (fue borrado),
                    // forzamos el valor a null para que el Dropdown no explote.
                    if (selectedClientId != null && !existeCliente) {
                      selectedClientId = null;
                    }
                    // ---------------------------------------------

                    return DropdownButtonFormField<String>(
                      value: selectedClientId,
                      decoration: const InputDecoration(labelText: 'Cliente'),
                      items: clientesDocs.map((doc) {
                        final data = doc.data();
                        return DropdownMenuItem(
                          value: doc.id,
                          child: Text(data['nombre'] ?? ''),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => selectedClientId = val),
                      validator: (val) =>
                      val == null ? 'Seleccione un cliente' : null,
                    );
                  },
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar Ítem'),
                ),
                const SizedBox(height: 10),
                Column(
                  children: items
                      .asMap()
                      .entries
                      .map((entry) => Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text(entry.value['desc']),
                      subtitle: Text(
                          'Cant: ${entry.value['cantidad']} x \$${entry.value['precio']}'),
                      trailing: IconButton(
                        icon: Icon(Icons.delete,
                            color: Theme.of(context).colorScheme.error),
                        onPressed: () {
                          setState(() {
                            items.removeAt(entry.key);
                          });
                        },
                      ),
                    ),
                  ))
                      .toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Guardar'),
              onPressed: () {
                if (!_formKey.currentState!.validate()) return;
                double total = items.fold(
                    0.0, (double prev, item) => prev + item['cantidad'] * item['precio']);
                final data = {
                  'clienteId': selectedClientId,
                  'items': items,
                  'total': total,
                  'fecha': Timestamp.now(),
                };
                if (docId != null) {
                  presupuestosCol.doc(docId).update(data);
                } else {
                  presupuestosCol.add(data);
                }
                Navigator.pop(context);
              },
            ),
          ],
        );
      }),
    );
  }

  void _deletePresupuesto(String docId) async {
    await presupuestosCol.doc(docId).delete();
  }

  Future<void> _generarPDF(Map<String, dynamic> presupuesto) async {
    final pdf = pw.Document();

    final tallerDoc =
    await FirebaseFirestore.instance.collection('users').doc(widget.uid).get();
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

    // Lógica segura para obtener el nombre del cliente para el PDF
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
              // Encabezado
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
                    if (logoImage != null)
                      pw.Image(logoImage, width: 80, height: 80),
                    pw.SizedBox(width: 16),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(nombreTaller,
                            style: pw.TextStyle(
                                fontSize: 20,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.indigo)),
                        if (direccion.isNotEmpty) pw.Text(direccion),
                        if (telefono.isNotEmpty) pw.Text("Tel: $telefono"),
                        if (email.isNotEmpty) pw.Text(email),
                      ],
                    ),
                  ],
                ),
              ),
              pw.Divider(height: 32, thickness: 2, color: PdfColors.grey300),
              pw.Text('Presupuesto',
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text('Cliente: $clienteNombre'),
              pw.Text('Fecha: $fechaStr'),
              pw.SizedBox(height: 10),
              pw.Column(
                children: (presupuesto['items'] as List<dynamic>).map((item) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
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
              pw.Divider(),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text('Total: \$${(presupuesto['total'] as num).toStringAsFixed(2)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openPresupuestoForm(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: presupuestosCol.orderBy('fecha', descending: true).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text("No hay presupuestos registrados"));

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final fecha = (data['fecha'] as Timestamp?)?.toDate();
              final fechaStr = fecha != null
                  ? DateFormat('dd/MM/yyyy').format(fecha)
                  : '-';

              return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: clientesCol.doc(data['clienteId']).get(),
                builder: (context, clienteSnap) {

                  // Solución "A prueba de balas" para la vista de la lista
                  String clienteNombre = "Cargando...";

                  if (clienteSnap.connectionState == ConnectionState.done) {
                    if (clienteSnap.hasError) {
                      clienteNombre = "Error al cargar cliente";
                    } else if (clienteSnap.hasData && clienteSnap.data!.exists) {
                      clienteNombre = clienteSnap.data!.data()?['nombre'] ?? 'Sin nombre';
                    } else {
                      clienteNombre = 'Cliente eliminado';
                    }
                  } else {
                    clienteNombre = 'Buscando cliente...';
                  }

                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.symmetric(vertical: 8),
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
                                      color: (clienteNombre == 'Cliente eliminado') ? Colors.red : null
                                  ),
                                ),
                              ),
                              Text(
                                fechaStr,
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                            ],
                          ),
                          const Divider(),

                          const Text("Ítems:", style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey)),
                          const SizedBox(height: 4),
                          ...List.generate((data['items'] as List<dynamic>).length, (i) {
                            final item = (data['items'] as List<dynamic>)[i];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("• ", style: TextStyle(color: Colors.grey)),
                                  Expanded(
                                    child: Text("${item['desc']}", style: const TextStyle(fontSize: 14)),
                                  ),
                                  Text(
                                    "${item['cantidad']} x \$${item['precio']}",
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ],
                              ),
                            );
                          }),

                          const Divider(),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("TOTAL", style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  Text(
                                    "\$${(data['total'] as num).toStringAsFixed(2)}",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    tooltip: "Generar PDF",
                                    icon: const Icon(Icons.picture_as_pdf, color: Colors.green),
                                    onPressed: () => _generarPDF(data),
                                  ),
                                  IconButton(
                                    tooltip: "Editar",
                                    icon: Icon(Icons.edit, color: theme.colorScheme.primary),
                                    onPressed: () => _openPresupuestoForm(
                                        context, docId: docs[index].id, currentData: data),
                                  ),
                                  IconButton(
                                    tooltip: "Eliminar",
                                    icon: Icon(Icons.delete, color: theme.colorScheme.error),
                                    onPressed: () => _deletePresupuesto(docs[index].id),
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