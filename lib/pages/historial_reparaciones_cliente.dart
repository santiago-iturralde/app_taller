import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme.dart'; // Asegurate de importar tu tema premium

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

  // Funciones auxiliares para darle color a las etiquetas (badges)
  Color _getColorForEstadoPago(String estado) {
    if (estado.toLowerCase() == 'pagado') return Colors.green.shade600;
    return Colors.redAccent.shade400; // Pendiente u otros
  }

  Color _getColorForEstadoReparacion(String estado) {
    final est = estado.toLowerCase();
    if (est.contains('entregado') || est.contains('terminado')) return AppTheme.primaryBlue;
    if (est.contains('proceso') || est.contains('revisión')) return Colors.orange.shade600;
    if (est.contains('espera') || est.contains('repuesto')) return Colors.amber.shade700;
    return Colors.grey.shade600;
  }

  @override
  Widget build(BuildContext context) {
    final reparacionesCol = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('reparaciones');

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Historial de Cliente', style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: Colors.grey)),
            Text(clienteNombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: reparacionesCol
            .where('clienteId', isEqualTo: clienteId)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue));
          }

          if (snap.hasError) {
            return const Center(child: Text('Error al cargar el historial.'));
          }

          final docs = snap.data?.docs ?? [];

          // Estado Vacío (Empty State)
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
                      child: Icon(Icons.build_circle_outlined, size: 64, color: AppTheme.primaryBlue.withOpacity(0.7)),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "Sin historial",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Este cliente aún no tiene reparaciones registradas en el sistema.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, height: 1.5),
                    ),
                  ],
                ),
              ),
            );
          }

          // Ordenamos localmente por fecha
          docs.sort((a, b) {
            final fa = (a.data()['fechaIngreso'] as Timestamp?)?.toDate() ?? DateTime(2000);
            final fb = (b.data()['fechaIngreso'] as Timestamp?)?.toDate() ?? DateTime(2000);
            return fb.compareTo(fa);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();

              final fecha = (data['fechaIngreso'] as Timestamp?)?.toDate();
              final fechaStr = fecha != null ? DateFormat("dd MMM yyyy").format(fecha) : "-";

              final maquina = data['maquina']?.toString() ?? 'Equipo sin nombre';
              final problema = data['problema']?.toString() ?? 'Sin descripción';
              final precio = data['precio']?.toString() ?? '0';

              final estadoPago = data['estadoPago']?.toString() ?? 'pendiente';
              final estadoReparacion = data['estado']?.toString() ?? 'Recibido';

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cabecera de la tarjeta: Máquina y Fecha
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              maquina,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Row(
                            children: [
                              Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Text(
                                fechaStr,
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1),
                      ),

                      // Problema
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 18, color: Colors.grey.shade400),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              problema,
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 14, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Footer de la tarjeta: Estados y Precio
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Badges (Etiquetas)
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildBadge(
                                  text: estadoReparacion.toUpperCase(),
                                  color: _getColorForEstadoReparacion(estadoReparacion),
                                  icon: Icons.build_outlined,
                                ),
                                _buildBadge(
                                  text: estadoPago.toUpperCase(),
                                  color: _getColorForEstadoPago(estadoPago),
                                  icon: estadoPago.toLowerCase() == 'pagado' ? Icons.check_circle_outline : Icons.access_time,
                                ),
                              ],
                            ),
                          ),

                          // Precio
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text("Total", style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                              Text(
                                "\$$precio",
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.primaryBlue),
                              ),
                            ],
                          )
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

  // Widget auxiliar para crear las "píldoras" de estado
  Widget _buildBadge({required String text, required Color color, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}