import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

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

  Future<void> _enviarWhatsApp({
    required String clienteId,
    required String maquina,
    required String precio,
  }) async {
    try {
      final docCliente = await clientesCol.doc(clienteId).get();
      if (!docCliente.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encontró la información del cliente.')),
        );
        return;
      }

      final clienteData = docCliente.data();
      final String nombreCliente = clienteData?['nombre'] ?? 'Cliente';
      final String numeroTelefono = clienteData?['telefono'] ?? clienteData?['numero'] ?? '';

      if (numeroTelefono.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El cliente no tiene teléfono registrado.')),
        );
        return;
      }

      final url = Uri.parse('https://puente-whatsapp-taller.onrender.com/enviar');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'cliente': nombreCliente,
          'numero': numeroTelefono,
          'maquina': maquina,
          'precio': precio,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ ¡Aviso enviado por WhatsApp!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final bodyData = jsonDecode(response.body);
        final errorMsg = bodyData['error'] ?? 'Estado HTTP ${response.statusCode}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ $errorMsg'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error de conexión: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // Transformamos el AlertDialog en un BottomSheet súper moderno
  void _openForm(BuildContext context, {String? docId, Map<String, dynamic>? currentData}) {
    final _maquinaController = TextEditingController(text: currentData != null ? currentData['maquina'] : '');
    final _problemaController = TextEditingController(text: currentData != null ? currentData['problema'] : '');
    final _precioController = TextEditingController(text: currentData != null ? currentData['precio']?.toString() : '');

    String? selectedClientId = currentData != null ? currentData['clienteId'] : null;
    String selectedEstado = currentData != null ? currentData['estado'] ?? 'pendiente' : 'pendiente';
    String selectedPago = currentData != null ? currentData['estadoPago'] ?? 'pendiente' : 'pendiente';
    final _formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 24,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  docId != null ? "Editar Reparación" : "Nueva Reparación",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: clientesCol.orderBy('nombre').snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData) return const LinearProgressIndicator(color: AppTheme.primaryBlue);
                    final clientes = snap.data!.docs;
                    return DropdownButtonFormField<String>(
                      value: selectedClientId,
                      decoration: const InputDecoration(labelText: "Cliente", prefixIcon: Icon(Icons.person)),
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
                const SizedBox(height: 16),
                TextFormField(
                  controller: _maquinaController,
                  decoration: const InputDecoration(labelText: "Máquina", prefixIcon: Icon(Icons.computer)),
                  validator: (value) => (value == null || value.isEmpty) ? 'Obligatorio' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _problemaController,
                  decoration: const InputDecoration(labelText: "Problema", prefixIcon: Icon(Icons.build)),
                  maxLines: 2,
                  validator: (value) => (value == null || value.isEmpty) ? 'Obligatorio' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _precioController,
                  decoration: const InputDecoration(labelText: "Precio", prefixIcon: Icon(Icons.attach_money)),
                  keyboardType: TextInputType.number,
                  validator: (value) => (value == null || value.isEmpty) ? 'Obligatorio' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedEstado,
                        decoration: const InputDecoration(labelText: "Estado"),
                        items: const [
                          DropdownMenuItem(value: 'pendiente', child: Text('Pendiente')),
                          DropdownMenuItem(value: 'completada', child: Text('Completada')),
                        ],
                        onChanged: (val) {
                          if (val != null) selectedEstado = val;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedPago,
                        decoration: const InputDecoration(labelText: "Pago"),
                        items: const [
                          DropdownMenuItem(value: 'pendiente', child: Text('Pendiente')),
                          DropdownMenuItem(value: 'pagado', child: Text('Pagado')),
                        ],
                        onChanged: (val) {
                          if (val != null) selectedPago = val;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text("Guardar Reparación"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
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
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMonthYearSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.calendar_month, color: AppTheme.primaryBlue),
          const SizedBox(width: 16),
          DropdownButton<int>(
            value: selectedMonth,
            underline: const SizedBox(),
            icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.primaryBlue),
            items: List.generate(12, (i) => i + 1)
                .map((m) => DropdownMenuItem(value: m, child: Text(DateFormat('MMMM', 'es_ES').format(DateTime(2000, m)).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold))))
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => selectedMonth = value);
            },
          ),
          const SizedBox(width: 16),
          DropdownButton<int>(
            value: selectedYear,
            underline: const SizedBox(),
            icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.primaryBlue),
            items: List.generate(5, (i) => DateTime.now().year - i)
                .map((y) => DropdownMenuItem(value: y, child: Text(y.toString(), style: const TextStyle(fontWeight: FontWeight.bold))))
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => selectedYear = value);
            },
          ),
        ],
      ),
    );
  }

  void _deleteReparacion(String docId) async {
    bool confirmar = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¿Eliminar?"),
        content: const Text("Esta acción no se puede deshacer."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Eliminar"),
          ),
        ],
      ),
    ) ?? false;

    if (confirmar) {
      await reparacionesCol.doc(docId).delete();
    }
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: const Text("Nueva Reparación"),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: reparacionesCol.orderBy('fechaIngreso', descending: true).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue));

          final todosLosDocs = snap.data!.docs;
          final docsFiltrados = todosLosDocs.where((doc) {
            final fecha = (doc.data()['fechaIngreso'] as Timestamp?)?.toDate();
            if (fecha == null) return true;
            return fecha.month == selectedMonth && fecha.year == selectedYear;
          }).toList();

          return Column(
            children: [
              _buildMonthYearSelector(),
              Expanded(
                child: docsFiltrados.isEmpty
                    ? const Center(
                    child: Text("No hay reparaciones en este mes.", style: TextStyle(color: Colors.grey, fontSize: 16))
                )
                    : ListView.builder(
                  padding: const EdgeInsets.only(left: 12, right: 12, bottom: 80, top: 8),
                  itemCount: docsFiltrados.length,
                  itemBuilder: (context, index) {
                    final data = docsFiltrados[index].data();
                    final docId = docsFiltrados[index].id;
                    final fecha = (data['fechaIngreso'] as Timestamp?)?.toDate();
                    final fechaStr = fecha != null ? DateFormat("dd/MM/yyyy").format(fecha) : "-";

                    final bool estaCompletada = (data['estado'] ?? 'pendiente') == 'completada';
                    final bool estaPagado = (data['estadoPago'] ?? 'pendiente') == 'pagado';

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    data['maquina'] ?? 'Sin nombre',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  "\$${data['precio']}",
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Problema: ${data['problema'] ?? ''}",
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                            const Divider(height: 24),
                            Row(
                              children: [
                                _buildChip(data['estado'] ?? 'pendiente', estaCompletada ? Colors.green : Colors.orange),
                                const SizedBox(width: 8),
                                _buildChip(data['estadoPago'] ?? 'pendiente', estaPagado ? Colors.blue : Colors.red),
                                const Spacer(),

                                // --- BOTÓN DE WHATSAPP ---
                                IconButton(
                                  icon: const Icon(Icons.send_rounded, color: Colors.green),
                                  tooltip: 'Notificar por WhatsApp',
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                  onPressed: () {
                                    final String? clienteId = data['clienteId'];
                                    if (clienteId == null || clienteId.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Esta reparación no tiene un cliente asignado.')),
                                      );
                                      return;
                                    }
                                    _enviarWhatsApp(
                                      clienteId: clienteId,
                                      maquina: data['maquina'] ?? 'Máquina',
                                      precio: (data['precio'] ?? 0).toString(),
                                    );
                                  },
                                ),
                                const SizedBox(width: 16),

                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.grey),
                                  onPressed: () => _openForm(context, docId: docId, currentData: data),
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                ),
                                const SizedBox(width: 16),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                  onPressed: () => _deleteReparacion(docId),
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text("Ingreso: $fechaStr", style: const TextStyle(fontSize: 12, color: Colors.grey)),
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