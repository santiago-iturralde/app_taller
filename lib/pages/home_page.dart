import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
// Asegúrate de que estas rutas sean correctas
import 'Clientes.dart';
import 'Reparaciones.dart';
import 'Presupuestos.dart';
import 'Egresos.dart';
import 'Reportes.dart';
import 'export_excel.dart';
import 'PerfilTaller.dart';
import 'Recibos.dart';
import 'planes_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Variables para controlar el plan
  bool _isPremium = false;
  bool _isLoadingPremium = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkPremiumStatus();
  }

  /// Consulta a Firebase el estado del plan (SOLO LECTURA)
  Future<void> _checkPremiumStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (doc.exists && mounted) {
        setState(() {
          // Si el campo existe y es true, es Premium.
          // Si no existe o es false, es Free.
          // NO modificamos la base de datos aquí.
          _isPremium = doc.data()?['isPremium'] ?? false;
          _isLoadingPremium = false;
        });
      }
    } catch (e) {
      print("Error al verificar premium: $e");
      if (mounted) setState(() => _isLoadingPremium = false);
    }
  }

  /// Muestra el cartel de bloqueo
  void _mostrarBloqueoPremium(BuildContext context, String funcion) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.workspace_premium, size: 50, color: Colors.amber),
        title: Text("Función Premium: $funcion"),
        content: const Text(
          "Esta funcionalidad es exclusiva para usuarios del Plan PRO.\n\n"
              "Actualiza tu cuenta para generar Recibos profesionales, ver Estadísticas avanzadas y más.",
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cerrar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PlanesScreen()));
            },
            child: const Text("Ver Planes"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Taller de Reparaciones'),
        actions: [
          IconButton(
            tooltip: 'Exportar Todo a Excel',
            onPressed: () async {
              try {
                await exportarTodoExcel(user.uid);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Exportación completada')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error al exportar: $e')),
                );
              }
            },
            icon: const Icon(Icons.download),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () async => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: colorScheme.onPrimary.withOpacity(0.2),
          ),
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
          labelColor: colorScheme.onPrimary,
          unselectedLabelColor: colorScheme.onPrimary.withOpacity(0.7),
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Clientes'),
            Tab(icon: Icon(Icons.build), text: 'Reparaciones'),
            Tab(icon: Icon(Icons.request_quote), text: 'Presupuestos'),
          ],
        ),
      ),

      // --- MENÚ LATERAL ---
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: colorScheme.primary),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Fila con Título y Badge (PRO/FREE)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Menú',
                        style: TextStyle(color: colorScheme.onPrimary, fontSize: 22),
                      ),
                      if (!_isLoadingPremium)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _isPremium ? Colors.amber : Colors.grey[400],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _isPremium ? "PRO" : "FREE",
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                        ),
                    ],
                  ),
                  // Versión de la app
                  FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snapshot) {
                      String versionInfo = "Cargando...";
                      if (snapshot.hasData) {
                        versionInfo = "v${snapshot.data!.version}+${snapshot.data!.buildNumber}";
                      }
                      return Text(
                        versionInfo,
                        style: TextStyle(
                          color: colorScheme.onPrimary.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // --- BOTÓN OBTENER PREMIUM (Solo visible si es FREE) ---
            if (!_isPremium && !_isLoadingPremium)
              Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber),
                ),
                child: ListTile(
                  leading: const Icon(Icons.star, color: Colors.orange),
                  title: const Text(
                    "Obtener PREMIUM",
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  subtitle: const Text("Desbloquea recibos y reportes"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PlanesScreen()),
                    );
                  },
                ),
              ),

            // --- RECIBOS (BLOQUEADO) ---
            ListTile(
              leading: Icon(Icons.receipt_long, color: _isPremium ? null : Colors.grey),
              title: Row(
                children: [
                  const Text("Recibos (Talonarios)"),
                  if (!_isPremium) ...[
                    const SizedBox(width: 10),
                    const Icon(Icons.lock, size: 16, color: Colors.grey),
                  ]
                ],
              ),
              onTap: () {
                Navigator.pop(context);
                if (_isPremium) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => RecibosTab(uid: user.uid)));
                } else {
                  _mostrarBloqueoPremium(context, "Talonarios de Recibos");
                }
              },
            ),

            const Divider(),

            // --- EGRESOS (LIBRE) ---
            ListTile(
              leading: const Icon(Icons.money_off),
              title: const Text("Egresos"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => EgresosScreen(uid: user.uid)),
                );
              },
            ),

            // --- REPORTES (BLOQUEADO) ---
            ListTile(
              leading: Icon(Icons.bar_chart, color: _isPremium ? null : Colors.grey),
              title: Row(
                children: [
                  const Text("Reportes"),
                  if (!_isPremium) ...[
                    const SizedBox(width: 10),
                    const Icon(Icons.lock, size: 16, color: Colors.grey),
                  ]
                ],
              ),
              onTap: () {
                Navigator.pop(context);
                if (_isPremium) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ReportesScreen(uid: user.uid)));
                } else {
                  _mostrarBloqueoPremium(context, "Estadísticas y Reportes");
                }
              },
            ),

            ListTile(
              leading: const Icon(Icons.store),
              title: const Text('Perfil del Taller'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PerfilTallerScreen(uid: user.uid)),
                );
              },
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ClientesTab(uid: user.uid),
          ReparacionesTab(uid: user.uid),
          PresupuestosTab(uid: user.uid),
        ],
      ),
    );
  }
}