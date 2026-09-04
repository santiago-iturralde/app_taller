import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Agregado para personalizar la barra del celular
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:intl/date_symbol_data_local.dart'; // Agregá este import
import 'pages/home_page.dart'; // Asegúrate que la ruta sea correcta
import 'pages/auth_page.dart'; // Asegúrate que la ruta sea correcta
import 'theme.dart'; // Importamos nuestro tema premium

Future<void> _enableOfflinePersistence() async {
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED, // Mejora para almacenar más datos offline
    );
  } catch (_) {
    // Ignorar si no está disponible en la plataforma/versión.
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Opcional pero recomendado: Forzamos la orientación vertical para evitar desajustes en el diseño
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Configuramos el color de la barra de estado del celular para que combine con la App
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // Transparente para que tome el color del AppBar
      statusBarIconBrightness: Brightness.light, // Iconos blancos (batería, hora)
    ),
  );

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _enableOfflinePersistence();

  await initializeDateFormatting('es_AR', null);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Taller Pro Manager',

      // Aplicamos nuestro tema centralizado
      theme: AppTheme.lightTheme,

      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Pantalla de carga Premium mientras Firebase decide si hay sesión
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              backgroundColor: AppTheme.primaryBlue,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.settings_suggest, size: 80, color: Colors.white),
                    SizedBox(height: 24),
                    CircularProgressIndicator(color: AppTheme.accentGold),
                  ],
                ),
              ),
            );
          }

          // Lógica de ruteo original intacta
          if (snapshot.hasData) {
            return const HomePage();
          }
          return const AuthPage();
        },
      ),
    );
  }
}