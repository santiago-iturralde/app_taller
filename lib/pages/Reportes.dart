import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../theme.dart'; // Importamos tu tema premium

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

  // --- TU LÓGICA INTACTA ---
  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);

    final inicioMes = DateTime(_mesSeleccionado.year, _mesSeleccionado.month, 1);
    final finMes = DateTime(_mesSeleccionado.year, _mesSeleccionado.month + 1, 0);

    // INGRESOS
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

    // EGRESOS
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
  // -------------------------

  // Helper para capitalizar la primera letra del mes
  String _capitalizar(String texto) {
    if (texto.isEmpty) return texto;
    return texto[0].toUpperCase() + texto.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final balance = _ingresos - _egresos;
    final esPositivo = balance >= 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Reportes Mensuales"),
      ),
      body: _cargando
          ? const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryBlue),
      )
          : RefreshIndicator(
        onRefresh: _cargarDatos,
        color: AppTheme.primaryBlue,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Selector de mes Premium
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, size: 30, color: AppTheme.primaryBlue),
                      onPressed: () => _cambiarMes(-1),
                    ),
                    Text(
                      _capitalizar(DateFormat('MMMM yyyy', 'es_ES').format(_mesSeleccionado)),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, size: 30, color: AppTheme.primaryBlue),
                      onPressed: () => _cambiarMes(1),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Ingresos y Egresos lado a lado
              Row(
                children: [
                  Expanded(
                    child: _buildKpiCard(
                      titulo: "Ingresos",
                      monto: _ingresos,
                      icono: Icons.arrow_downward_rounded,
                      colorBase: Colors.green.shade700,
                      colorFondo: Colors.green.shade50,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildKpiCard(
                      titulo: "Egresos",
                      monto: _egresos,
                      icono: Icons.arrow_upward_rounded,
                      colorBase: Colors.red.shade700,
                      colorFondo: Colors.red.shade50,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Tarjeta de Balance General Destacada
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: esPositivo
                        ? [AppTheme.primaryBlue, const Color(0xFF3B82F6)] // Azul si hay ganancias
                        : [Colors.orange.shade800, Colors.orange.shade500], // Naranja si hay pérdidas
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: (esPositivo ? AppTheme.primaryBlue : Colors.orange).withOpacity(0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            esPositivo ? Icons.account_balance_wallet : Icons.warning_amber_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          "Balance General",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "\$${balance.toStringAsFixed(2)}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget personalizado para las tarjetas pequeñas (Ingresos/Egresos)
  Widget _buildKpiCard({
    required String titulo,
    required double monto,
    required IconData icono,
    required Color colorBase,
    required Color colorFondo,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorFondo,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorBase.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, color: colorBase, size: 24),
              const SizedBox(width: 8),
              Text(
                titulo,
                style: TextStyle(
                  color: colorBase.withOpacity(0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            "\$${monto.toStringAsFixed(2)}",
            style: TextStyle(
              color: colorBase,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}