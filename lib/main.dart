import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app/app_info.dart';
import 'app/arranque.dart';
import 'app/sesion.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

/// Conecta a los emuladores locales de Firebase en lugar del proyecto real.
const _usarEmuladores = bool.fromEnvironment('EMULADORES');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (_usarEmuladores) {
    // flutter run -d chrome --dart-define=EMULADORES=true
    // (antes: firebase emulators:start --only auth,firestore)
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  } else {
    // Caché local: la app sigue funcionando con mala conexión.
    FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);
  }

  Intl.defaultLocale = 'es_AR';
  await initializeDateFormatting('es_AR');

  runApp(App(controller: SesionController()));
}

class App extends StatelessWidget {
  const App({super.key, required this.controller});
  final SesionController controller;

  @override
  Widget build(BuildContext context) {
    return SesionScope(
      controller: controller,
      child: MaterialApp(
        title: AppInfo.nombre,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.claro,
        darkTheme: AppTheme.oscuro,
        themeMode: ThemeMode.system,
        locale: const Locale('es', 'AR'),
        supportedLocales: const [Locale('es', 'AR'), Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const Arranque(),
      ),
    );
  }
}
