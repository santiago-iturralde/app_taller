import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme.dart'; // Importamos tu tema premium

class EgresosScreen extends StatelessWidget {
  final String uid;
  const EgresosScreen({super.key, required this.uid});

  // Función para asignar íconos y colores según la categoría
  Map<String, dynamic> _getCategoryStyle(String category) {
    switch (category.toLowerCase()) {
      case 'repuestos':
        return {'icon': Icons.build_circle, 'color': Colors.orange.shade600, 'bg': Colors.orange.shade50};
      case 'servicios':
        return {'icon': Icons.electric_bolt_rounded, 'color': AppTheme.primaryBlue, 'bg': Colors.blue.shade50};
      default:
        return {'icon': Icons.receipt_long_rounded, 'color': Colors.grey.shade600, 'bg': Colors.grey.shade100};
    }
  }

  @override
  Widget build(BuildContext context) {
    final egresosRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('egresos')
        .orderBy('fecha', descending: true);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Control de Egresos", style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        titleTextStyle: const TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: egresosRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Error cargando los egresos"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue));
          }

          final egresos = snapshot.data?.docs ?? [];

          // Empty State Premium
          if (egresos.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                      child: Icon(Icons.money_off_rounded, size: 64, color: Colors.red.shade300),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "Sin egresos registrados",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Tus gastos en repuestos, servicios y otros aparecerán aquí.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, height: 1.5),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: egresos.length,
            itemBuilder: (context, index) {
              final doc = egresos[index];
              final egreso = doc.data() as Map<String, dynamic>;

              final fecha = (egreso['fecha'] as Timestamp?)?.toDate();
              final fechaStr = fecha != null ? DateFormat('dd MMM yyyy').format(fecha) : '-';

              final categoria = egreso['categoria'] ?? 'Otros';
              final style = _getCategoryStyle(categoria);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: style['bg'], shape: BoxShape.circle),
                    child: Icon(style['icon'], color: style['color'], size: 24),
                  ),
                  title: Text(
                    egreso['descripcion'] ?? 'Sin descripción',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Text(categoria, style: TextStyle(color: style['color'], fontSize: 12, fontWeight: FontWeight.w600)),
                        const Text(" • ", style: TextStyle(color: Colors.grey)),
                        Text(fechaStr, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "-\$${egreso['monto'] ?? 0}",
                        style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.redAccent, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () => _mostrarDialogoEditar(context, uid, doc.id, egreso),
                            child: const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
                          ),
                          const SizedBox(width: 12),
                          InkWell(
                            onTap: () => _confirmarEliminacion(context, uid, doc.id),
                            child: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarDialogoAgregar(context, uid),
        backgroundColor: Colors.redAccent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Nuevo Gasto", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // --- MÉTODOS DE LÓGICA CON UI PREMIUM ---

  Future<void> _confirmarEliminacion(BuildContext context, String uid, String docId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text("Eliminar egreso"),
          ],
        ),
        content: const Text("¿Estás seguro de que querés eliminar este registro? Esta acción no se puede deshacer."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('users').doc(uid).collection('egresos').doc(docId).delete();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarDialogoAgregar(BuildContext context, String uid) async {
    final descripcionCtrl = TextEditingController();
    final montoCtrl = TextEditingController();
    String categoria = "Otros";

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Registrar Gasto", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: descripcionCtrl,
              decoration: InputDecoration(
                labelText: "Descripción",
                prefixIcon: const Icon(Icons.edit_note),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: montoCtrl,
              decoration: InputDecoration(
                labelText: "Monto",
                prefixIcon: const Icon(Icons.attach_money),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: categoria,
              decoration: InputDecoration(
                labelText: "Categoría",
                prefixIcon: const Icon(Icons.category_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: const [
                DropdownMenuItem(value: "Repuestos", child: Text("Repuestos")),
                DropdownMenuItem(value: "Servicios", child: Text("Servicios")),
                DropdownMenuItem(value: "Otros", child: Text("Otros")),
              ],
              onChanged: (value) {
                if (value != null) categoria = value;
              },
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Guardar"),
            onPressed: () async {
              final monto = double.tryParse(montoCtrl.text) ?? 0;
              if (descripcionCtrl.text.isNotEmpty && monto > 0) {
                await FirebaseFirestore.instance.collection('users').doc(uid).collection('egresos').add({
                  'descripcion': descripcionCtrl.text,
                  'monto': monto,
                  'categoria': categoria,
                  'fecha': DateTime.now(),
                });
                if (context.mounted) Navigator.pop(context);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Editar Gasto", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: descripcionCtrl,
              decoration: InputDecoration(
                labelText: "Descripción",
                prefixIcon: const Icon(Icons.edit_note),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: montoCtrl,
              decoration: InputDecoration(
                labelText: "Monto",
                prefixIcon: const Icon(Icons.attach_money),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: categoria,
              decoration: InputDecoration(
                labelText: "Categoría",
                prefixIcon: const Icon(Icons.category_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: const [
                DropdownMenuItem(value: "Repuestos", child: Text("Repuestos")),
                DropdownMenuItem(value: "Servicios", child: Text("Servicios")),
                DropdownMenuItem(value: "Otros", child: Text("Otros")),
              ],
              onChanged: (value) {
                if (value != null) categoria = value;
              },
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Actualizar"),
            onPressed: () async {
              final monto = double.tryParse(montoCtrl.text) ?? 0;
              if (descripcionCtrl.text.isNotEmpty && monto > 0) {
                await FirebaseFirestore.instance.collection('users').doc(uid).collection('egresos').doc(docId).update({
                  'descripcion': descripcionCtrl.text,
                  'monto': monto,
                  'categoria': categoria,
                  // NOTA: Removí el 'fecha': DateTime.now() para que NO sobrescriba la fecha original del gasto al editar un error de tipeo.
                });
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }
}