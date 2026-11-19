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
import '../data/repositories/equipo_repository.dart';
import '../features/onboarding/bienvenida_page.dart';
import '../features/onboarding/migracion_page.dart';
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

  /// Administrador de la plataforma (custom claim asignado con el script
  /// tools/admin/superadmin.js).
  bool _esSuperadmin = false;
  StreamSubscription<DocumentSnapshot<Json>>? _version;
  bool _avisoMostrado = false;
  SesionController? _controller;

  @override
  void initState() {
    super.initState();
    _resolver();
    _vigilarVersion();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller = SesionScope.controller(context)..addListener(_alCambiarSesion);
    });
  }

  @override
  void dispose() {
    _controller?.removeListener(_alCambiarSesion);
    _version?.cancel();
    super.dispose();
  }

  /// Si al usuario lo quitan del equipo mientras usa la app, se le avisa
  /// en lugar de dejarlo en pantallas sin permisos.
  void _alCambiarSesion() {
    if ((_controller?.accesoPerdido ?? false) && _paso == _Paso.listo && mounted) {
      Navigator.of(context).popUntil((r) => r.isFirst);
      setState(() => _paso = _Paso.sinAcceso);
    }
  }

  Future<void> _desvincular() async {
    await MisInvitaciones().olvidarNegocio(widget.usuario.uid);
    _resolver();
  }

  Future<void> _resolver() async {
    setState(() => _paso = _Paso.cargando);
    final fs = FirebaseFirestore.instance;
    final uid = widget.usuario.uid;
    try {
      final token = await widget.usuario.getIdTokenResult();
      _esSuperadmin = token.claims?['superadmin'] == true;
      final perfil = (await fs.collection('users').doc(uid).get()).data() ?? const {};
      final negocioId = perfil['negocioId'] as String?;

      if (negocioId == null) {
        final hayDatosViejos = await MigracionLegacy().hayDatos(uid);
        if (mounted) setState(() => _paso = hayDatosViejos ? _Paso.migracion : _Paso.alta);
        return;
      }

      final db = Db(negocioId);
      DocumentSnapshot<Json> miembro;
      try {
        miembro = await db.miembros.doc(uid).get();
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied') rethrow;
        if (mounted) setState(() => _paso = _Paso.sinAcceso);
        return;
      }
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
        esSuperadmin: _esSuperadmin,
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
      _Paso.alta => BienvenidaPage(usuario: widget.usuario, onListo: _resolver, esSuperadmin: _esSuperadmin),
      _Paso.migracion => MigracionPage(usuario: widget.usuario, onListo: _resolver),
      _Paso.listo => const Shell(),
      _Paso.sinAcceso => _Mensaje(
          titulo: 'Ya no tenés acceso a este negocio',
          mensaje: 'Tu usuario dejó de ser parte del equipo. Podés aceptar otra invitación o crear tu propio negocio.',
          textoAccion: 'Continuar',
          onReintentar: _desvincular,
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
  const _Mensaje({required this.titulo, required this.mensaje, required this.onReintentar, this.textoAccion = 'Reintentar'});
  final String titulo;
  final String mensaje;
  final VoidCallback onReintentar;
  final String textoAccion;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: EstadoVacio(
          icono: Icons.cloud_off_rounded,
          titulo: titulo,
          mensaje: mensaje,
          accion: Wrap(spacing: 8, children: [
            FilledButton(onPressed: onReintentar, child: Text(textoAccion)),
            TextButton(onPressed: () => FirebaseAuth.instance.signOut(), child: const Text('Salir')),
          ]),
        ),
      );
}
