import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:taller_reparaciones/pages/chat_agente_screen.dar.dart';
import 'package:universal_html/html.dart' as html;
import 'package:flutter/foundation.dart'; // Para detectar si estamos en la web

// Rutas de tu app
import 'chat_agente_screen.dar.dart'; //
import 'Clientes.dart';
import 'Reparaciones.dart';
import 'Presupuestos.dart';
import 'Egresos.dart';
import 'Reportes.dart';
import 'export_excel.dart';
import 'PerfilTaller.dart';
import 'Recibos.dart';
import 'planes_screen.dart';
import '../theme.dart'; // Tu tema premium

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

  // Esta es la versión de tu código actual
  final int versionApp = 3;
  @override
  void initState() {
    super.initState();
    _escucharNuevaVersion(); // Arrancamos el espía apenas abre la app
    _tabController = TabController(length: 3, vsync: this);
    _checkPremiumStatus();
  }

  void _escucharNuevaVersion() {
    // Escucha en tiempo real el documento que creaste en Firebase
    FirebaseFirestore.instance
        .collection('configuracion')
        .doc('app_info')
        .snapshots()
        .listen((snap) {
      if (snap.exists) {
        final versionServidor = snap.data()?['version'] ?? 1;

        // Si el número en Firebase es mayor al número en tu código, salta el aviso
        if (versionServidor > versionApp) {
          _mostrarAlertaActualizacion();
        }
      }
    });
  }

  void _mostrarAlertaActualizacion() {
    showDialog(
        context: context,
        barrierDismissible: false, // Evita que cierren el cartel tocando afuera
        builder: (context) {
          return PopScope(
            canPop: false, // Evita que cierren el cartel con el botón "Atrás" del celular
            child: AlertDialog(
              title: const Text("¡Nueva Actualización! 🚀"),
              content: const Text(
                  "Hay una nueva versión del sistema disponible con mejoras. Por favor, actualizá la página para continuar trabajando."),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    if (kIsWeb) {
                      // Esto fuerza a Chrome a recargar la página y traer el código nuevo
                      html.window.location.reload();
                    }
                  },
                  child: const Text("Actualizar ahora"),
                )
              ],
            ),
          );
        }
    );
  }

  /// Consulta a Firebase el estado del plan (SOLO LECTURA)
  Future<void> _checkPremiumStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (doc.exists && mounted) {
        setState(() {
          _isPremium = doc.data()?['isPremium'] ?? false;
          _isLoadingPremium = false;
        });
      }
    } catch (e) {
      debugPrint("Error al verificar premium: $e");
      if (mounted) setState(() => _isLoadingPremium = false);
    }
  }

  /// Muestra el cartel de bloqueo Premium rediseñado
  void _mostrarBloqueoPremium(BuildContext context, String funcion) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 10,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.workspace_premium, size: 48, color: Colors.amber),
              ),
              const SizedBox(height: 20),
              Text(
                "Función PRO",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
              ),
              const SizedBox(height: 8),
              Text(
                "La función '$funcion' es exclusiva del Plan Premium.",
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text(
                "Actualizá tu cuenta para generar recibos profesionales, acceder a reportes avanzados, copias de seguridad y mucho más.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                      child: Text("Quizás luego", style: TextStyle(color: Colors.grey.shade600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade600,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const PlanesScreen()));
                      },
                      child: const Text("Ver Planes", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Taller Manager', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          // --- BOTÓN DEL AGENTE DE IA ---
          IconButton(
            tooltip: 'Consultar Asistente IA',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ChatAgenteScreen()),
              );
            },
            icon: const Icon(Icons.smart_toy_outlined),
          ),
          // ------------------------------
          IconButton(
            tooltip: 'Exportar Todo a Excel',
            onPressed: () async {
              try {
                // Pequeño feedback visual
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Generando archivo Excel...'), duration: Duration(seconds: 1)),
                );
                await exportarTodoExcel(user.uid);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Exportación completada con éxito'), backgroundColor: Colors.green),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error al exportar: $e'), backgroundColor: Colors.redAccent),
                );
              }
            },
            icon: const Icon(Icons.download_rounded),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.1),
                borderRadius: BorderRadius.circular(25),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(25),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
                    ]
                ),
                labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                labelColor: AppTheme.primaryBlue,
                unselectedLabelColor: Colors.white.withOpacity(0.8),
                tabs: const [
                  Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.people_alt_outlined, size: 18), SizedBox(width: 6), Text('Clientes')])),
                  Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.build_outlined, size: 18), SizedBox(width: 6), Text('Taller')])),
                  Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.request_quote_outlined, size: 18), SizedBox(width: 6), Text('Presup.')])),
                ],
              ),
            ),
          ),
        ),
      ),

      // --- MENÚ LATERAL (DRAWER) ---
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  DrawerHeader(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.primaryBlue, AppTheme.primaryBlue.withOpacity(0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                              child: const Icon(Icons.storefront, color: Colors.white, size: 36),
                            ),
                            if (!_isLoadingPremium)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _isPremium ? Colors.amber : Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _isPremium ? "PRO" : "FREE",
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isPremium ? Colors.black : Colors.white),
                                ),
                              ),
                          ],
                        ),
                        const Spacer(),
                        const Text(
                          'Mi Taller',
                          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          user.email ?? '',
                          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                        ),
                      ],
                    ),
                  ),

                  // --- BOTÓN OBTENER PREMIUM (Solo visible si es FREE) ---
                  if (!_isPremium && !_isLoadingPremium)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const PlanesScreen()));
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [Colors.amber.shade100, Colors.amber.shade50]),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.workspace_premium, color: Colors.amber, size: 30),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Desbloqueá todo", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
                                    const Text("Pasate a Premium hoy", style: TextStyle(fontSize: 12, color: Colors.black87)),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios, size: 14, color: Colors.amber.shade700)
                            ],
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 8),

                  _buildDrawerItem(
                    icon: Icons.money_off_rounded,
                    title: "Control de Egresos",
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => EgresosScreen(uid: user.uid)));
                    },
                  ),

                  _buildDrawerItem(
                    icon: Icons.receipt_long_rounded,
                    title: "Recibos (Talonarios)",
                    isLocked: !_isPremium,
                    onTap: () {
                      Navigator.pop(context);
                      if (_isPremium) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => RecibosTab(uid: user.uid)));
                      } else {
                        _mostrarBloqueoPremium(context, "Talonarios de Recibos");
                      }
                    },
                  ),

                  _buildDrawerItem(
                    icon: Icons.bar_chart_rounded,
                    title: "Reportes y Estadísticas",
                    isLocked: !_isPremium,
                    onTap: () {
                      Navigator.pop(context);
                      if (_isPremium) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => ReportesScreen(uid: user.uid)));
                      } else {
                        _mostrarBloqueoPremium(context, "Estadísticas y Reportes");
                      }
                    },
                  ),

                  const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Divider(height: 30)),

                  _buildDrawerItem(
                    icon: Icons.settings_outlined,
                    title: "Configuración del Taller",
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => PerfilTallerScreen(uid: user.uid)));
                    },
                  ),
                ],
              ),
            ),

            // Footer del Drawer
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  OutlinedButton.icon(
                    onPressed: () async => FirebaseAuth.instance.signOut(),
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text("Cerrar Sesión"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      minimumSize: const Size(double.infinity, 45),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snapshot) {
                      String versionInfo = "Cargando versión...";
                      if (snapshot.hasData) {
                        versionInfo = "Versión ${snapshot.data!.version} (${snapshot.data!.buildNumber})";
                      }
                      return Text(
                        versionInfo,
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                      );
                    },
                  ),
                ],
              ),
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

  // Widget auxiliar para mantener el código limpio
  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isLocked = false,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
      leading: Icon(icon, color: isLocked ? Colors.grey.shade400 : Colors.grey.shade700),
      title: Text(
        title,
        style: TextStyle(
          color: isLocked ? Colors.grey.shade500 : Colors.grey.shade800,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: isLocked ? const Icon(Icons.lock_outline, size: 18, color: Colors.amber) : null,
      onTap: onTap,
    );
  }
}