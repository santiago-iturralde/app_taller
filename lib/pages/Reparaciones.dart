import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final Color primaryColor = Colors.indigo;
final Color accentColor = Colors.indigoAccent;

class ReparacionesTab extends StatefulWidget {
  final String uid;
  const ReparacionesTab({super.key, required this.uid});

  @override
  State<ReparacionesTab> createState() => _ReparacionesTabState();
}

class _ReparacionesTabState extends State<ReparacionesTab> {
  late CollectionReference<Map<String, dynamic>> reparacionesCol;
  late CollectionReference<Map<String, dynamic>> clientesCol;

  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    reparacionesCol = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .collection('reparaciones');

    clientesCol = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .collection('clientes');
  }

  void _openForm(BuildContext context,
      {String? docId, Map<String, dynamic>? currentData}) {
    final _maquinaController =
    TextEditingController(text: currentData != null ? currentData['maquina'] : '');
    final _problemaController =
    TextEditingController(text: currentData != null ? currentData['problema'] : '');
    final _precioController = TextEditingController(
        text: currentData != null ? currentData['precio']?.toString() : '');
    String? selectedClientId = currentData != null ? currentData['clienteId'] : null;
    String selectedEstado = currentData != null ? currentData['estado'] ?? 'pendiente' : 'pendiente';
    String selectedPago =
    currentData != null ? currentData['estadoPago'] ?? 'pendiente' : 'pendiente';
    final _formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          docId != null ? "Editar reparación" : "Nueva reparación",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
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
                      decoration: const InputDecoration(labelText: "Cliente"),
                      items: clientes.map((doc) {
                        final data = doc.data();
                        return DropdownMenuItem(
                          value: doc.id,
                          child: Text(data['nombre'] ?? ''),
                        );
                      }).toList(),
                      onChanged: (val) => selectedClientId = val,
                      validator: (val) => val == null ? 'Seleccione un cliente' : null,
                    );
                  },
                ),
                const SizedBox(height: 10),
                _styledTextField(_maquinaController, "Máquina"),
                const SizedBox(height: 10),
                _styledTextField(_problemaController, "Problema"),
                const SizedBox(height: 10),
                _styledTextField(_precioController, "Precio",
                    keyboardType: TextInputType.number),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedEstado,
                  decoration: const InputDecoration(labelText: "Estado reparación"),
                  items: const [
                    DropdownMenuItem(value: 'pendiente', child: Text('Pendiente')),
                    DropdownMenuItem(value: 'completada', child: Text('Completada')),
                  ],
                  onChanged: (val) {
                    if (val != null) selectedEstado = val;
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedPago,
                  decoration: const InputDecoration(labelText: "Estado de pago"),
                  items: const [
                    DropdownMenuItem(value: 'pendiente', child: Text('Pendiente')),
                    DropdownMenuItem(value: 'pagado', child: Text('Pagado')),
                  ],
                  onChanged: (val) {
                    if (val != null) selectedPago = val;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.black,
              backgroundColor: Colors.greenAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.save),
            label: const Text("Guardar"),
            onPressed: () {
              if (!_formKey.currentState!.validate()) return;

              final data = {
                'clienteId': selectedClientId,
                'maquina': _maquinaController.text.trim(),
                'problema': _problemaController.text.trim(),
                'precio': double.tryParse(_precioController.text.trim()) ?? 0.0,
                'estado': selectedEstado,
                'estadoPago': selectedPago,
              };

              if (docId != null) {
                reparacionesCol.doc(docId).update(data);
              } else {
                data['fechaIngreso'] = Timestamp.now();
                reparacionesCol.add(data);
              }
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMonthYearSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        DropdownButton<int>(
          value: selectedMonth,
          items: List.generate(12, (i) => i + 1)
              .map((m) => DropdownMenuItem(value: m, child: Text(m.toString())))
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => selectedMonth = value);
          },
        ),
        const SizedBox(width: 16),
        DropdownButton<int>(
          value: selectedYear,
          items: List.generate(5, (i) => DateTime.now().year - i)
              .map((y) => DropdownMenuItem(value: y, child: Text(y.toString())))
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => selectedYear = value);
          },
        ),
      ],
    );
  }

  void _deleteReparacion(String docId) async {
    await reparacionesCol.doc(docId).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        foregroundColor: Colors.black,
        backgroundColor: Colors.teal,
        onPressed: () => _openForm(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: reparacionesCol.orderBy('fechaIngreso', descending: true).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;

          return Column(
            children: [
              const SizedBox(height: 10),
              _buildMonthYearSelector(),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final fecha = (data['fechaIngreso'] as Timestamp?)?.toDate();
                    final fechaStr =
                    fecha != null ? DateFormat("dd/MM/yyyy").format(fecha) : "-";

                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        subtitle: RichText(
                          text: TextSpan(
                            style: const TextStyle(color: Colors.black),
                            children: [
                              TextSpan(text: "Maquina: ${data['maquina'] ?? ''}\n"),
                              TextSpan(text: "Problema: ${data['problema'] ?? ''}\n"),
                              TextSpan(text: "Estado de reparación: ${data['estado'] ?? ''}\n"),
                              TextSpan(
                                text:
                                "Estado de pago: ${data['estadoPago'] ?? 'pendiente'}\n",
                                style: TextStyle(
                                  color: (data['estadoPago'] ?? 'pendiente') == 'pagado'
                                      ? Colors.green
                                      : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(text: "Precio: \$${data['precio']}\n"),
                              TextSpan(text: "Ingreso: $fechaStr"),
                            ],
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: accentColor),
                              onPressed: () => _openForm(
                                  context, docId: docs[index].id, currentData: data),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () => _deleteReparacion(docs[index].id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

Widget _styledTextField(TextEditingController controller, String label,
    {TextInputType keyboardType = TextInputType.text}) {
  return TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    validator: (value) => (value == null || value.isEmpty) ? 'Obligatorio' : null,
    decoration: InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.green, width: 2),
      ),
    ),
  );
}
