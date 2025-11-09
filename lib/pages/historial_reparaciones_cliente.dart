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

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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

              final bool isPagado = (data['estadoPago'] ?? 'pendiente') == 'pagado';
              final String estadoPago = data['estadoPago'] ?? 'pendiente';

              return Card(
                child: ListTile(
                  title: Text(
                    data['maquina'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: RichText(
                    text: TextSpan(
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black87, height: 1.4),
                      children: [
                        TextSpan(text: "Problema: ${data['problema'] ?? ''}\n"),
                        TextSpan(text: "Estado de reparación: ${data['estado'] ?? ''}\n"),
                        TextSpan(
                          text: "Estado de pago: $estadoPago\n",
                          style: TextStyle(
                            color: isPagado
                                ? Colors.green.shade700
                                : colorScheme.error,
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