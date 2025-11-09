import 'dart:html' as html; // Para descarga en web
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'historial_reparaciones_cliente.dart';

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
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(labelText: "Nombre"),
                validator: (value) => (value == null || value.isEmpty) ? 'Obligatorio' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _telefonoController,
                decoration: const InputDecoration(labelText: "Teléfono"),
                keyboardType: TextInputType.phone,
                validator: (value) => (value == null || value.isEmpty) ? 'Obligatorio' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton.icon(
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
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(labelText: "Nombre"),
                validator: (value) => (value == null || value.isEmpty) ? 'Obligatorio' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _telefonoController,
                decoration: const InputDecoration(labelText: "Teléfono"),
                validator: (value) => (value == null || value.isEmpty) ? 'Obligatorio' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton.icon(
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Clientes"),
      ),
      floatingActionButton: FloatingActionButton(
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
                child: ListTile(
                  title: Text(
                    data['nombre'] ?? 'Sin nombre',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Text(
                    "${data['telefono'] ?? ''}\nRegistrado: $fechaStr",
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, color: colorScheme.primary),
                        onPressed: () => _editClient(context, docs[index].id, data),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: colorScheme.error),
                        onPressed: () => _deleteClient(docs[index].id),
                      ),
                      IconButton(
                        icon: Icon(Icons.history, color: colorScheme.secondary),
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