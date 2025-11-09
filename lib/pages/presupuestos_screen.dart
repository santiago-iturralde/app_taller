// presupuestos_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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

  void _openPresupuestoForm({Map<String, dynamic>? currentData, String? docId}) {
    final _formKey = GlobalKey<FormState>();
    String? selectedClienteId = currentData?['clienteId'];
    String? selectedClienteNombre = currentData?['clienteNombre'];
    List<Map<String, dynamic>> items = currentData != null
        ? List<Map<String, dynamic>>.from(currentData['items'])
        : [];

    showDialog(
      context: context,
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
                    (prev, item) =>
                prev +
                    (item['cantidad'] as int) * (item['precio'] as double));
          }

          return AlertDialog(
            title: Text(docId != null ? 'Editar Presupuesto' : 'Nuevo Presupuesto'),
            content: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: clientesCol.orderBy('nombre').snapshots(),
                      builder: (context, snap) {
                        if (!snap.hasData) return const CircularProgressIndicator();
                        final clientes = snap.data!.docs;
                        return DropdownButtonFormField<String>(
                          value: selectedClienteId,
                          decoration: const InputDecoration(labelText: 'Cliente'),
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
                              selectedClienteNombre = clientes
                                  .firstWhere((c) => c.id == val)
                                  .data()['nombre'];
                            });
                          },
                          validator: (val) => val == null ? 'Seleccione un cliente' : null,
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              children: [
                                TextFormField(
                                  initialValue: item['descripcion'],
                                  decoration:
                                  const InputDecoration(labelText: 'Descripción'),
                                  onChanged: (val) => item['descripcion'] = val,
                                  validator: (val) =>
                                  (val == null || val.isEmpty) ? 'Obligatorio' : null,
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: item['cantidad'].toString(),
                                        decoration:
                                        const InputDecoration(labelText: 'Cantidad'),
                                        keyboardType: TextInputType.number,
                                        onChanged: (val) =>
                                        item['cantidad'] = int.tryParse(val) ?? 1,
                                        validator: (val) => (val == null ||
                                            int.tryParse(val) == null)
                                            ? 'Número'
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: item['precio'].toString(),
                                        decoration: const InputDecoration(
                                            labelText: 'Precio unitario'),
                                        keyboardType: TextInputType.number,
                                        onChanged: (val) =>
                                        item['precio'] = double.tryParse(val) ?? 0.0,
                                        validator: (val) => (val == null ||
                                            double.tryParse(val) == null)
                                            ? 'Número'
                                            : null,
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete,
                                          color: Theme.of(context).colorScheme.error),
                                      onPressed: () => _removeItem(index),
                                    )
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _addItem,
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar ítem'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total: \$${_calculateTotal().toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;
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
                  Navigator.pop(context);
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _generarPDF(Map<String, dynamic> presupuesto) async {
    final pdf = pw.Document();
    final items = List<Map<String, dynamic>>.from(presupuesto['items'] ?? []);
    final clienteNombre = presupuesto['clienteNombre'] ?? '-';

    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Presupuesto',
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 16),
            pw.Text('Cliente: $clienteNombre'),
            pw.SizedBox(height: 16),
            pw.Table.fromTextArray(
              headers: ['Descripción', 'Cantidad', 'Precio unitario', 'Subtotal'],
              data: items
                  .map((item) => [
                item['descripcion'],
                item['cantidad'].toString(),
                '\$${(item['precio'] as double).toStringAsFixed(2)}',
                '\$${((item['cantidad'] as int) * (item['precio'] as double)).toStringAsFixed(2)}'
              ])
                  .toList(),
            ),
            pw.SizedBox(height: 16),
            pw.Text('Total: \$${(presupuesto['total'] as double).toStringAsFixed(2)}',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openPresupuestoForm(),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: presupuestosCol.orderBy('fecha', descending: true).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No hay presupuestos'));

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final fecha = (data['fecha'] as Timestamp?)?.toDate();
              final fechaStr = fecha != null ? DateFormat('dd/MM/yyyy').format(fecha) : '-';
              final clienteNombre = data['clienteNombre'] ?? '-';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cliente: $clienteNombre',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('Total: \$${(data['total'] as double?)?.toStringAsFixed(2) ?? '0.0'}'),
                      Text('Fecha: $fechaStr'),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.picture_as_pdf, color: Colors.green),
                            tooltip: 'Generar PDF',
                            onPressed: () => _generarPDF(data),
                          ),
                          IconButton(
                            icon: Icon(Icons.edit, color: theme.colorScheme.primary),
                            tooltip: 'Editar',
                            onPressed: () => _openPresupuestoForm(currentData: data, docId: doc.id),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete, color: theme.colorScheme.error),
                            tooltip: 'Eliminar',
                            onPressed: () => presupuestosCol.doc(doc.id).delete(),
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