import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class ReportesScreen extends StatefulWidget {
  final String uid;
  const ReportesScreen({super.key, required this.uid});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  DateTime _mesSeleccionado = DateTime.now();
  bool _cargando = true;
  double _ingresos = 0;
  double _egresos = 0;

  @override
  void initState() {
    super.initState();
    _inicializarLocale();
  }

  Future<void> _inicializarLocale() async {
    await initializeDateFormatting('es_ES', null);
    await _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);

    final inicioMes = DateTime(_mesSeleccionado.year, _mesSeleccionado.month, 1);
    final finMes = DateTime(_mesSeleccionado.year, _mesSeleccionado.month + 1, 0);

    // INGRESOS (reparaciones pagadas en el mes)
    final reparacionesSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .collection('reparaciones')
        .where('estadoPago', isEqualTo: 'pagado')
        .get();

    double ingresos = 0;
    for (var doc in reparacionesSnap.docs) {
      final data = doc.data();
      final fecha = (data['fechaIngreso'] as Timestamp?)?.toDate();
      if (fecha != null &&
          !fecha.isBefore(inicioMes) &&
          !fecha.isAfter(finMes)) {
        ingresos += (data['precio'] ?? 0).toDouble();
      }
    }

    // EGRESOS (egresos del mes)
    final egresosSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .collection('egresos')
        .get();

    double egresos = 0;
    for (var doc in egresosSnap.docs) {
      final data = doc.data();
      final fecha = (data['fecha'] as Timestamp?)?.toDate();
      if (fecha != null &&
          !fecha.isBefore(inicioMes) &&
          !fecha.isAfter(finMes)) {
        egresos += (data['monto'] ?? 0).toDouble();
      }
    }

    setState(() {
      _ingresos = ingresos;
      _egresos = egresos;
      _cargando = false;
    });
  }

  void _cambiarMes(int diff) {
    setState(() {
      _mesSeleccionado = DateTime(
        _mesSeleccionado.year,
        _mesSeleccionado.month + diff,
        1,
      );
    });
    _cargarDatos();
  }

  @override
  Widget build(BuildContext context) {
    final balance = _ingresos - _egresos;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Reportes"),
        backgroundColor: Colors.teal,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Selector de mes
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_left),
                  onPressed: () => _cambiarMes(-1),
                ),
                Text(
                  DateFormat('MMMM yyyy', 'es_ES').format(_mesSeleccionado),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_right),
                  onPressed: () => _cambiarMes(1),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Ingresos
            Card(
              color: Colors.green[100],
              child: ListTile(
                leading: const Icon(Icons.arrow_downward, color: Colors.green),
                title: const Text("Ingresos"),
                trailing: Text(
                  "\$${_ingresos.toStringAsFixed(2)}",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Egresos
            Card(
              color: Colors.red[100],
              child: ListTile(
                leading: const Icon(Icons.arrow_upward, color: Colors.red),
                title: const Text("Egresos"),
                trailing: Text(
                  "\$${_egresos.toStringAsFixed(2)}",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.red),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Balance
            Card(
              color: balance >= 0 ? Colors.blue[100] : Colors.orange[100],
              child: ListTile(
                leading: Icon(
                  balance >= 0 ? Icons.check_circle : Icons.warning,
                  color: balance >= 0 ? Colors.blue : Colors.orange,
                ),
                title: const Text("Balance"),
                trailing: Text(
                  "\$${balance.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: balance >= 0 ? Colors.blue : Colors.orange,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
