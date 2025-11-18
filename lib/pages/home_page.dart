import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'Clientes.dart';
import 'Reparaciones.dart';
import 'Presupuestos.dart';
import 'Egresos.dart';
import 'Reportes.dart';
import 'export_excel.dart';
import 'PerfilTaller.dart';
import 'package:package_info_plus/package_info_plus.dart'; // <--- Este import es correcto
import 'Recibos.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);  //aca aumento la cantidad de pestañas
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
      drawer: Drawer( //ACA ARRANCA EL MENU DESPLEGABLE
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: colorScheme.primary),

              // --- INICIO DE LA MODIFICACIÓN ---
              // Cambiamos el child por una Columna para que entren 2 textos
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween, // Para alinear
                children: [
                  // 1. Tu texto original
                  Text(
                    'Menú',
                    style: TextStyle(color: colorScheme.onPrimary, fontSize: 22),
                  ),

                  // 2. El FutureBuilder que obtiene la versión
                  FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snapshot) {
                      String versionInfo = "Cargando..."; // Texto mientras carga
                      if (snapshot.hasData) {
                        // Cuando tiene los datos, muestra la versión
                        versionInfo = "v${snapshot.data!.version}+${snapshot.data!.buildNumber}";
                      }

                      return Text(
                        versionInfo,
                        style: TextStyle(
                          color: colorScheme.onPrimary.withOpacity(0.8), // Un poco más tenue
                          fontSize: 14,
                        ),
                      );
                    },
                  ),
                ],
              ),
              // --- FIN DE LA MODIFICACIÓN ---
            ),
            ListTile(
              leading: const Icon(Icons.money_off),
              title: const Text("Egresos"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => EgresosScreen(uid: user.uid)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text("Reportes"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ReportesScreen(uid: user.uid)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.store),
              title: const Text('Perfil del Taller'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PerfilTallerScreen(uid: user.uid)),
                );
              },
            ),
            // --- OPCIÓN EN EL MENÚ: RECIBOS ---
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text("Recibos (Talonarios)"),
              onTap: () {
                // Cierra el menú primero
                Navigator.pop(context);
                // Navega a la pantalla de Recibos
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => RecibosTab(uid: user.uid)),
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