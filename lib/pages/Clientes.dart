import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'historial_reparaciones_cliente.dart';
import '../theme.dart'; // Importamos tu tema premium

class ClientesTab extends StatelessWidget {
  final String uid;
  const ClientesTab({super.key, required this.uid});

  CollectionReference<Map<String, dynamic>> get col =>
      FirebaseFirestore.instance.collection('users').doc(uid).collection('clientes');

  // Un solo metodo para CREAR y EDITAR clientes, optimizando código
  void _showClientDialog(BuildContext context, {String? docId, Map<String, dynamic>? currentData}) {
    final isEditing = docId != null;
    // Corregido con paréntesis para evitar conflictos de sintaxis
    final nombreController = TextEditingController(text: isEditing ? (currentData?['nombre'] ?? '') : '');
    final telefonoController = TextEditingController(text: isEditing ? (currentData?['telefono'] ?? '') : '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(isEditing ? Icons.edit : Icons.person_add, color: AppTheme.primaryBlue),
            const SizedBox(width: 8),
            Text(isEditing ? "Editar Cliente" : "Nuevo Cliente", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nombreController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: "Nombre completo",
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'El nombre es obligatorio' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: telefonoController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: "Teléfono / WhatsApp",
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'El teléfono es obligatorio' : null,
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar", style: TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              if (isEditing) {
                // Actualizar
                await col.doc(docId).update({
                  'nombre': nombreController.text.trim(),
                  'telefono': telefonoController.text.trim(),
                });
              } else {
                // Crear nuevo
                await col.add({
                  'nombre': nombreController.text.trim(),
                  'telefono': telefonoController.text.trim(),
                  'fechaRegistro': Timestamp.now(),
                });
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(isEditing ? "Actualizar" : "Guardar"),
          ),
        ],
      ),
    );
  }

  // Cuadro de diálogo para confirmar antes de borrar
  void _confirmarEliminacion(BuildContext context, String docId, String nombreCliente) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text("Eliminar Cliente"),
          ],
        ),
        content: Text("¿Estás seguro de que querés eliminar a '$nombreCliente'? Esta acción no se puede deshacer."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              await col.doc(docId).delete();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold SIN AppBar porque ya estamos dentro de un TabBarView
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showClientDialog(context),
        backgroundColor: AppTheme.primaryBlue,
        icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
        label: const Text("Nuevo Cliente", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: col.orderBy('fechaRegistro', descending: true).snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue));
          }

          if (snap.hasError) {
            return const Center(child: Text("Error al cargar los clientes."));
          }

          final docs = snap.data?.docs ?? [];

          // Empty State Premium
          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                      child: Icon(Icons.people_alt_outlined, size: 64, color: AppTheme.primaryBlue.withOpacity(0.7)),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "Tu cartera de clientes",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Registrá a tus clientes para llevar un historial organizado de sus reparaciones y presupuestos.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, height: 1.5),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16).copyWith(bottom: 80), // Margen inferior para el FAB
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final docId = docs[index].id;

              final nombre = data['nombre'] ?? 'Sin nombre';
              final telefono = data['telefono'] ?? 'Sin teléfono';

              final fecha = (data['fechaRegistro'] as Timestamp?)?.toDate();
              final fechaStr = fecha != null ? DateFormat("dd MMM yyyy").format(fecha) : "-";

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.only(left: 16, right: 8, top: 8),
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
                        foregroundColor: AppTheme.primaryBlue,
                        child: Text(nombre.isNotEmpty ? nombre[0].toUpperCase() : '?', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.phone, size: 14, color: Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Text(telefono, style: TextStyle(color: Colors.grey.shade700)),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text("Registrado: $fechaStr", style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                          ],
                        ),
                      ),
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.grey),
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showClientDialog(context, docId: docId, currentData: data);
                          } else if (value == 'delete') {
                            _confirmarEliminacion(context, docId, nombre);
                          }
                        },
                        itemBuilder: (BuildContext context) => [
                          const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 20), SizedBox(width: 8), Text("Editar")])),
                          PopupMenuItem(value: 'delete', child: Row(children: [const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent), const SizedBox(width: 8), Text("Eliminar", style: TextStyle(color: Colors.redAccent))])),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Botón Inferior para Ver Historial
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HistorialReparacionesClienteScreen(
                              uid: uid,
                              clienteId: docId,
                              clienteNombre: nombre,
                            ),
                          ),
                        );
                      },
                      borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50.withOpacity(0.5),
                          borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 18, color: AppTheme.primaryBlue),
                            const SizedBox(width: 8),
                            Text(
                              "Ver Historial de Reparaciones",
                              style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}