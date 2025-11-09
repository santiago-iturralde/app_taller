import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// import 'package:intl/date_symbol_data_local.dart'; // No se usa en este archivo

class EgresosScreen extends StatelessWidget {
  final String uid;
  const EgresosScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    final egresosRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('egresos')
        .orderBy('fecha', descending: true);

    // Obtenemos el esquema de colores del tema
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Egresos"),
        // backgroundColor: Colors.teal, // <- ELIMINADO (usa el tema)
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: egresosRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Error cargando egresos"));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final egresos = snapshot.data!.docs;

          if (egresos.isEmpty) {
            return const Center(child: Text("No hay egresos registrados"));
          }

          return ListView.builder(
            itemCount: egresos.length,
            itemBuilder: (context, index) {
              final doc = egresos[index];
              final egreso = doc.data() as Map<String, dynamic>;
              final fecha = (egreso['fecha'] as Timestamp?)?.toDate();
              final fechaStr = fecha != null
                  ? DateFormat('dd/MM/yyyy').format(fecha)
                  : '-';

              return Card(
                // shape, elevation y margin vienen del cardTheme
                child: ListTile(
                  title: Text(egreso['descripcion'] ?? ''),
                  subtitle: Text("${egreso['categoria'] ?? ''} • $fechaStr"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "\$${egreso['monto'] ?? 0}",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.error), // <- MODIFICADO
                      ),
                      IconButton(
                        icon: Icon(Icons.edit, color: colorScheme.primary), // <- MODIFICADO
                        onPressed: () => _mostrarDialogoEditar(context, uid, doc.id, egreso),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: colorScheme.error), // <- MODIFICADO
                        onPressed: () => _eliminarEgreso(uid, doc.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarDialogoAgregar(context, uid),
        // backgroundColor: Colors.teal, // <- ELIMINADO (usa el tema)
        child: const Icon(Icons.add),
      ),
    );
  }

  // --- MÉTODOS DE LÓGICA (SIN CAMBIOS) ---
  // Estos métodos no necesitan cambios porque los widgets
  // internos (TextField, ElevatedButton, etc.)
  // adoptarán el tema automáticamente.

  Future<void> _eliminarEgreso(String uid, String docId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('egresos')
        .doc(docId)
        .delete();
  }

  Future<void> _mostrarDialogoAgregar(BuildContext context, String uid) async {
    final descripcionCtrl = TextEditingController();
    final montoCtrl = TextEditingController();
    String categoria = "Otros";

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Nuevo Egreso"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: descripcionCtrl,
              decoration: const InputDecoration(labelText: "Descripción"),
            ),
            TextField(
              controller: montoCtrl,
              decoration: const InputDecoration(labelText: "Monto"),
              keyboardType: TextInputType.number,
            ),
            DropdownButtonFormField<String>(
              value: categoria,
              items: const [
                DropdownMenuItem(value: "Repuestos", child: Text("Repuestos")),
                DropdownMenuItem(value: "Servicios", child: Text("Servicios")),
                DropdownMenuItem(value: "Otros", child: Text("Otros")),
              ],
              onChanged: (value) {
                if (value != null) categoria = value;
              },
              decoration: const InputDecoration(labelText: "Categoría"),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text("Cancelar"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text("Guardar"),
            onPressed: () async {
              final monto = double.tryParse(montoCtrl.text) ?? 0;
              if (descripcionCtrl.text.isNotEmpty && monto > 0) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .collection('egresos')
                    .add({
                  'descripcion': descripcionCtrl.text,
                  'monto': monto,
                  'categoria': categoria,
                  'fecha': DateTime.now(),
                });
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarDialogoEditar(BuildContext context, String uid, String docId, Map<String, dynamic> egreso) async {
    final descripcionCtrl = TextEditingController(text: egreso['descripcion'] ?? '');
    final montoCtrl = TextEditingController(text: (egreso['monto'] ?? 0).toString());
    String categoria = egreso['categoria'] ?? "Otros";

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Editar Egreso"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: descripcionCtrl,
              decoration: const InputDecoration(labelText: "Descripción"),
            ),
            TextField(
              controller: montoCtrl,
              decoration: const InputDecoration(labelText: "Monto"),
              keyboardType: TextInputType.number,
            ),
            DropdownButtonFormField<String>(
              value: categoria,
              items: const [
                DropdownMenuItem(value: "Repuestos", child: Text("Repuestos")),
                DropdownMenuItem(value: "Servicios", child: Text("Servicios")),
                DropdownMenuItem(value: "Otros", child: Text("Otros")),
              ],
              onChanged: (value) {
                if (value != null) categoria = value;
              },
              decoration: const InputDecoration(labelText: "Categoría"),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text("Cancelar"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text("Guardar"),
            onPressed: () async {
              final monto = double.tryParse(montoCtrl.text) ?? 0;
              if (descripcionCtrl.text.isNotEmpty && monto > 0) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .collection('egresos')
                    .doc(docId)
                    .update({
                  'descripcion': descripcionCtrl.text,
                  'monto': monto,
                  'categoria': categoria,
                  'fecha': DateTime.now(), // Considera si quieres actualizar la fecha o mantener la original
                });
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }
}