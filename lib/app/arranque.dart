import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;

import '../core/widgets/componentes.dart';
import '../data/db.dart';
import '../data/migracion_legacy.dart';
import '../data/models/negocio.dart';
import '../features/auth/auth_page.dart';
import '../features/onboarding/migracion_page.dart';
import '../features/onboarding/onboarding_page.dart';
import 'app_info.dart';
import 'sesion.dart';
import 'shell.dart';

/// Decide qué mostrar según el estado de la cuenta:
/// sin sesión → login; sin negocio → alta o migración; listo → app.
class Arranque extends StatelessWidget {
  const Arranque({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, s) {
        if (s.connectionState == ConnectionState.waiting) return const _Splash();
        final usuario = s.data;
        if (usuario == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => SesionScope.controller(context).cerrar());
          return const AuthPage();
        }
        return _ResolverNegocio(key: ValueKey(usuario.uid), usuario: usuario);
      },
    );
  }
}

enum _Paso { cargando, alta, migracion, listo, sinAcceso, error }

class _ResolverNegocio extends StatefulWidget {
  const _ResolverNegocio({super.key, required this.usuario});
  final User usuario;

  @override
  State<_ResolverNegocio> createState() => _ResolverNegocioState();
}

class _ResolverNegocioState extends State<_ResolverNegocio> {
  _Paso _paso = _Paso.cargando;
  StreamSubscription<DocumentSnapshot<Json>>? _version;
  bool _avisoMostrado = false;

  @override
  void initState() {
    super.initState();
    _resolver();
    _vigilarVersion();
  }

  @override
  void dispose() {
    _version?.cancel();
    super.dispose();
  }

  Future<void> _resolver() async {
    setState(() => _paso = _Paso.cargando);
    final fs = FirebaseFirestore.instance;
    final uid = widget.usuario.uid;
    try {
      final perfil = (await fs.collection('users').doc(uid).get()).data() ?? const {};
      final negocioId = perfil['negocioId'] as String?;

      if (negocioId == null) {
        final hayDatosViejos = await MigracionLegacy().hayDatos(uid);
        if (mounted) setState(() => _paso = hayDatosViejos ? _Paso.migracion : _Paso.alta);
        return;
      }

      final db = Db(negocioId);
      final miembro = await db.miembros.doc(uid).get();
      if (!miembro.exists) {
        if (mounted) setState(() => _paso = _Paso.sinAcceso);
        return;
      }
      final negocioDoc = await db.negocio.get();
      final negocio = Negocio.fromMap(negocioDoc.id, negocioDoc.data() ?? const {});
      if (!mounted) return;
      SesionScope.controller(context).iniciar(Sesion.crear(
        usuario: widget.usuario,
        negocio: negocio,
        rol: RolMiembro.desde(miembro.data()?['rol'] as String?),
      ));
      setState(() => _paso = _Paso.listo);
    } catch (e, st) {
      debugPrint('Arranque: $e\n$st');
      if (mounted) setState(() => _paso = _Paso.error);
    }
  }

  /// En la web, si se publicó una versión nueva incompatible, pide recargar
  /// para que nadie siga operando con código viejo.
  void _vigilarVersion() {
    _version = FirebaseFirestore.instance.collection('configuracion').doc('app_info').snapshots().listen((s) {
      final version = (s.data()?['version'] as num?)?.toInt() ?? 0;
      if (version > AppInfo.versionDatos && !_avisoMostrado && mounted) {
        _avisoMostrado = true;
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => PopScope(
            canPop: false,
            child: AlertDialog(
              icon: const Icon(Icons.system_update_alt_rounded, size: 40),
              title: const Text('Hay una nueva versión'),
              content: const Text('Actualizá para seguir trabajando con las últimas mejoras.'),
              actions: [
                if (kIsWeb) FilledButton(onPressed: () => html.window.location.reload(), child: const Text('Actualizar ahora')),
              ],
            ),
          ),
        );
      }
    }, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    return switch (_paso) {
      _Paso.cargando => const _Splash(),
      _Paso.alta => OnboardingPage(usuario: widget.usuario, onListo: _resolver),
      _Paso.migracion => MigracionPage(usuario: widget.usuario, onListo: _resolver),
      _Paso.listo => const Shell(),
      _Paso.sinAcceso => _Mensaje(
          titulo: 'Sin acceso al negocio',
          mensaje: 'Tu usuario ya no es miembro del negocio. Pedile al dueño que te vuelva a invitar.',
          onReintentar: _resolver,
        ),
      _Paso.error => _Mensaje(
          titulo: 'No pudimos conectarnos',
          mensaje: 'Revisá tu conexión a internet e intentá de nuevo.',
          onReintentar: _resolver,
        ),
    };
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Cargando());
}

class _Mensaje extends StatelessWidget {
  const _Mensaje({required this.titulo, required this.mensaje, required this.onReintentar});
  final String titulo;
  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: EstadoVacio(
          icono: Icons.cloud_off_rounded,
          titulo: titulo,
          mensaje: mensaje,
          accion: Wrap(spacing: 8, children: [
            FilledButton(onPressed: onReintentar, child: const Text('Reintentar')),
            TextButton(onPressed: () => FirebaseAuth.instance.signOut(), child: const Text('Salir')),
          ]),
        ),
      );
}
