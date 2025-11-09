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
    _tabController = TabController(length: 3, vsync: this);
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.teal,
        elevation: 3,
        title: const Text(
          'Taller de Reparaciones',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Exportar Todo a Excel',
            onPressed: () async {
              try {
                await exportarTodoExcel(user.uid);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Exportación completada')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error al exportar: $e')),
                );
              }
            },
            icon: const Icon(Icons.download, color: Colors.white),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () async => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout, color: Colors.white),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.white.withOpacity(0.2),
          ),
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Clientes'),
            Tab(icon: Icon(Icons.build), text: 'Reparaciones'),
            Tab(icon: Icon(Icons.request_quote), text: 'Presupuestos'),
          ],
        ),
      ),

      // Drawer lateral
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.teal),
              child: Text(
                'Menú',
                style: TextStyle(color: Colors.white, fontSize: 22),
              ),
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
              leading: Icon(Icons.build),
              title: Text('Perfil del Taller'),
              onTap: () {
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
