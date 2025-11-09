import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HistorialReparacionesClienteScreen extends StatelessWidget {
  final String uid;
  final String clienteId;
  final String clienteNombre;

  const HistorialReparacionesClienteScreen({
    super.key,
    required this.uid,
    required this.clienteId,
    required this.clienteNombre,
  });

  @override
  Widget build(BuildContext context) {
    final reparacionesCol = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('reparaciones');

    return Scaffold(
      appBar: AppBar(
        title: Text("Historial de $clienteNombre"),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: reparacionesCol
            .where('clienteId', isEqualTo: clienteId)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text("No hay reparaciones registradas."));
          }

          // Ordenar por fechaIngreso descendente (más recientes primero)
          docs.sort((a, b) {
            final fa = (a['fechaIngreso'] as Timestamp?)?.toDate() ?? DateTime(2000);
            final fb = (b['fechaIngreso'] as Timestamp?)?.toDate() ?? DateTime(2000);
            return fb.compareTo(fa);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final fecha = (data['fechaIngreso'] as Timestamp?)?.toDate();
              final fechaStr = fecha != null
                  ? DateFormat("dd/MM/yyyy").format(fecha)
                  : "-";

              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  title: Text(
                    data['maquina'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.black), // color base
                      children: [
                        TextSpan(text: "Problema: ${data['problema'] ?? ''}\n"),
                        TextSpan(text: "Estado de reparación: ${data['estado'] ?? ''}\n"),
                        TextSpan(
                          text: "Estado de pago: ${data['estadoPago'] ?? 'pendiente'}\n",
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

                ),
              );
            },
          );
        },
      ),
    );
  }
}
