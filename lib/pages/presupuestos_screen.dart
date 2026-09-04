// presupuestos_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../theme.dart'; // Importamos tu tema premium

class PresupuestosScreen extends StatefulWidget {
  const PresupuestosScreen({super.key});

  @override
  State<PresupuestosScreen> createState() => _PresupuestosScreenState();
}

class _PresupuestosScreenState extends State<PresupuestosScreen> {
  final CollectionReference<Map<String, dynamic>> presupuestosCol =
  FirebaseFirestore.instance.collection('presupuestos');
  final CollectionReference<Map<String, dynamic>> clientesCol =
  FirebaseFirestore.instance.collection('clientes');

  // --- Transformado a BottomSheet Moderno ---
  void _openPresupuestoForm({Map<String, dynamic>? currentData, String? docId}) {
    final _formKey = GlobalKey<FormState>();
    String? selectedClienteId = currentData?['clienteId'];
    String? selectedClienteNombre = currentData?['clienteNombre'];
    List<Map<String, dynamic>> items = currentData != null
        ? List<Map<String, dynamic>>.from(currentData['items'])
        : [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permite que el modal sea grande
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          void _addItem() {
            setState(() {
              items.add({'descripcion': '', 'cantidad': 1, 'precio': 0.0});
            });
          }

          void _removeItem(int index) {
            setState(() {
              items.removeAt(index);
            });
          }

          double _calculateTotal() {
            return items.fold(
                0.0,
                    (prev, item) => prev + (item['cantidad'] as int) * (item['precio'] as double));
          }

          // Se usa un Container con altura máxima para poder scrollear bien los items
          return Container(
            height: MediaQuery.of(context).size.height * 0.9, // Ocupa el 90% de la pantalla
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
                  const SizedBox(height: 20),

                  // Selector de Cliente
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: clientesCol.orderBy('nombre').snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData) return const LinearProgressIndicator(color: AppTheme.primaryBlue);
                      final clientes = snap.data!.docs;
                      return DropdownButtonFormField<String>(
                        value: selectedClienteId,
                        decoration: const InputDecoration(
                          labelText: 'Cliente',
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
                          setState(() {
                            selectedClienteId = val;
                            selectedClienteNombre = clientes.firstWhere((c) => c.id == val).data()['nombre'];
                          });
                        },
                        validator: (val) => val == null ? 'Seleccione un cliente' : null,
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Lista de Ítems (Expanded para que scrollee el centro y deje los botones fijos abajo)
                  Expanded(
                    child: items.isEmpty
                        ? Center(
                      child: Text(
                        "No hay ítems agregados.\nToca '+ Agregar ítem' para comenzar.",
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
                                      initialValue: item['descripcion'],
                                      decoration: const InputDecoration(
                                        labelText: 'Descripción del ítem',
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                      onChanged: (val) => item['descripcion'] = val,
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

                  // Botón Agregar Item
                  TextButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Agregar ítem al presupuesto'),
                    style: TextButton.styleFrom(foregroundColor: AppTheme.primaryBlue),
                  ),
                  const Divider(),

                  // Fila de Total y Botón Guardar (Fija abajo)
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
                              '\$${_calculateTotal().toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: () async {
                            if (!_formKey.currentState!.validate()) return;
                            if (items.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Debes agregar al menos un ítem.")));
                              return;
                            }
                            final total = _calculateTotal();
                            final data = {
                              'clienteId': selectedClienteId,
                              'clienteNombre': selectedClienteNombre ?? '-',
                              'items': items,
                              'total': total,
                              'fecha': Timestamp.now(),
                            };
                            if (docId != null) {
                              await presupuestosCol.doc(docId).update(data);
                            } else {
                              await presupuestosCol.add(data);
                            }
                            if (mounted) Navigator.pop(context);
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

  // --- PDF con estilo mejorado ---
  Future<void> _generarPDF(Map<String, dynamic> presupuesto) async {
    final pdf = pw.Document();
    final items = List<Map<String, dynamic>>.from(presupuesto['items'] ?? []);
    final clienteNombre = presupuesto['clienteNombre'] ?? '-';
    final fecha = (presupuesto['fecha'] as Timestamp?)?.toDate() ?? DateTime.now();
    final fechaStr = DateFormat('dd/MM/yyyy').format(fecha);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Cabecera
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('PRESUPUESTO', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Fecha: $fechaStr'),
                      pw.Text('Validez: 15 días', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                    ],
                  )
                ]
            ),
            pw.Divider(thickness: 2, color: PdfColors.blue900),
            pw.SizedBox(height: 16),

            // Cliente
            pw.Text('Preparado para:', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
            pw.Text(clienteNombre, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 24),

            // Tabla de Ítems
            pw.TableHelper.fromTextArray(
              headers: ['Descripción', 'Cant.', 'Precio Unit.', 'Subtotal'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {
                1: pw.Alignment.center,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
              },
              data: items.map((item) => [
                item['descripcion'],
                item['cantidad'].toString(),
                '\$${(item['precio'] as double).toStringAsFixed(2)}',
                '\$${((item['cantidad'] as int) * (item['precio'] as double)).toStringAsFixed(2)}'
              ]).toList(),
            ),
            pw.SizedBox(height: 16),

            // Total
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey200,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      ),
                      child: pw.Row(
                          children: [
                            pw.Text('TOTAL: ', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                            pw.Text('\$${(presupuesto['total'] as double).toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                          ]
                      )
                  )
                ]
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  void _deletePresupuesto(String docId) async {
    bool confirmar = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¿Eliminar Presupuesto?"),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Presupuestos")),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openPresupuestoForm(),
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
                  const Text("No hay presupuestos generados", style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 80),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final fecha = (data['fecha'] as Timestamp?)?.toDate();
              final fechaStr = fecha != null ? DateFormat('dd/MM/yyyy').format(fecha) : '-';
              final clienteNombre = data['clienteNombre'] ?? '-';
              final cantidadItems = (data['items'] as List?)?.length ?? 0;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.person_outline, size: 18, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        clienteNombre,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryBlue),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text("$cantidadItems ítems presupuestados", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                              ],
                            ),
                          ),
                          Text(
                            '\$${(data['total'] as double?)?.toStringAsFixed(2) ?? '0.00'}',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          Text(fechaStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          const Spacer(),
                          TextButton.icon(
                            icon: const Icon(Icons.picture_as_pdf, size: 18),
                            label: const Text("PDF"),
                            style: TextButton.styleFrom(foregroundColor: AppTheme.primaryBlue),
                            onPressed: () => _generarPDF(data),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.grey),
                            tooltip: 'Editar',
                            onPressed: () => _openPresupuestoForm(currentData: data, docId: doc.id),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            tooltip: 'Eliminar',
                            onPressed: () => _deletePresupuesto(doc.id),
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