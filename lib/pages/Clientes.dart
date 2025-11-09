import 'dart:html' as html; // Para descarga en web
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'historial_reparaciones_cliente.dart';

final Color primaryColor = Colors.indigo;
final Color accentColor = Colors.indigoAccent;

class ClientesTab extends StatelessWidget {
  final String uid;
  const ClientesTab({super.key, required this.uid});

  CollectionReference<Map<String, dynamic>> get col =>
      FirebaseFirestore.instance.collection('users').doc(uid).collection('clientes');

  void _openForm(BuildContext context) {
    final _nombreController = TextEditingController();
    final _telefonoController = TextEditingController();
    final _formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Nuevo Cliente", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _styledTextField(_nombreController, "Nombre"),
              const SizedBox(height: 10),
              _styledTextField(_telefonoController, "Teléfono", keyboardType: TextInputType.phone),
            ],
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
            onPressed: () async {
              if (!_formKey.currentState!.validate()) return;
              await col.add({
                'nombre': _nombreController.text.trim(),
                'telefono': _telefonoController.text.trim(),
                'fechaRegistro': Timestamp.now(),
              });
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _editClient(BuildContext context, String docId, Map<String, dynamic> currentData) {
    final _nombreController = TextEditingController(text: currentData['nombre']);
    final _telefonoController = TextEditingController(text: currentData['telefono']);
    final _formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Editar Cliente", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _styledTextField(_nombreController, "Nombre"),
              const SizedBox(height: 10),
              _styledTextField(_telefonoController, "Teléfono"),
            ],
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
            onPressed: () async {
              if (!_formKey.currentState!.validate()) return;
              await col.doc(docId).update({
                'nombre': _nombreController.text.trim(),
                'telefono': _telefonoController.text.trim(),
              });
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _deleteClient(String docId) async {
    await col.doc(docId).delete();
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Clientes"),
      ),
      floatingActionButton: FloatingActionButton(
        foregroundColor: Colors.black,
        backgroundColor: Colors.teal,
        onPressed: () => _openForm(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: col.orderBy('fechaRegistro', descending: true).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text("No hay clientes registrados"));

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final fecha = (data['fechaRegistro'] as Timestamp?)?.toDate();
              final fechaStr = fecha != null ? DateFormat("dd/MM/yyyy").format(fecha) : "-";

              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  title: Text(
                    data['nombre'] ?? 'Sin nombre',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Text(
                    "${data['telefono'] ?? ''}\nRegistrado: $fechaStr",
                    style: const TextStyle(color: Colors.black54),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, color: accentColor),
                        onPressed: () => _editClient(context, docs[index].id, data),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () => _deleteClient(docs[index].id),
                      ),
                      IconButton(
                        icon: const Icon(Icons.history, color: Colors.blueAccent),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => HistorialReparacionesClienteScreen(
                                uid: uid,
                                clienteId: docs[index].id,
                                clienteNombre: data['nombre'] ?? 'Sin nombre',
                              ),
                            ),
                          );
                        },
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
