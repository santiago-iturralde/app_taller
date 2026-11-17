import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app/app_info.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/feedback.dart';

enum _Modo { ingresar, registrarse, recuperar }

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _clave = TextEditingController();
  final _clave2 = TextEditingController();
  _Modo _modo = _Modo.ingresar;
  bool _ocultar = true;
  bool _cargando = false;

  @override
  void dispose() {
    _email.dispose();
    _clave.dispose();
    _clave2.dispose();
    super.dispose();
  }

  static String _mensaje(String codigo) => switch (codigo) {
        'invalid-credential' || 'user-not-found' || 'wrong-password' => 'Email o contraseña incorrectos.',
        'email-already-in-use' => 'Ese email ya tiene una cuenta. Ingresá con tu contraseña.',
        'weak-password' => 'La contraseña es muy débil. Usá al menos 8 caracteres.',
        'invalid-email' => 'El email no es válido.',
        'too-many-requests' => 'Demasiados intentos. Esperá unos minutos y probá de nuevo.',
        'network-request-failed' => 'Sin conexión. Revisá tu internet.',
        'user-disabled' => 'Esta cuenta está deshabilitada.',
        _ => 'No pudimos completar la operación ($codigo).',
      };

  Future<void> _enviar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _cargando = true);
    final auth = FirebaseAuth.instance;
    final email = _email.text.trim();
    try {
      switch (_modo) {
        case _Modo.ingresar:
          await auth.signInWithEmailAndPassword(email: email, password: _clave.text);
        case _Modo.registrarse:
          final cred = await auth.createUserWithEmailAndPassword(email: email, password: _clave.text);
          await cred.user?.sendEmailVerification();
        case _Modo.recuperar:
          await auth.sendPasswordResetEmail(email: email);
          if (!mounted) return;
          mostrarMensaje(context, 'Si el email está registrado, te llega un enlace para crear una nueva contraseña.');
          setState(() => _modo = _Modo.ingresar);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) mostrarMensaje(context, _mensaje(e.code), error: true);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _cambiarModo(_Modo m) {
    _form.currentState?.reset();
    setState(() => _modo = m);
  }

  @override
  Widget build(BuildContext context) {
    final formulario = _formulario(context);
    if (!context.esEscritorio) {
      return Scaffold(
        backgroundColor: context.esquema.surface,
        body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(Espacio.xl), child: formulario))),
      );
    }
    return Scaffold(
      backgroundColor: context.esquema.surface,
      body: Row(
        children: [
          const Expanded(child: _PanelMarca()),
          Expanded(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(Espacio.xxl), child: formulario))),
        ],
      ),
    );
  }

  Widget _formulario(BuildContext context) {
    final titulo = switch (_modo) {
      _Modo.ingresar => 'Ingresá a tu cuenta',
      _Modo.registrarse => 'Creá tu cuenta gratis',
      _Modo.recuperar => 'Recuperar contraseña',
    };
    final subtitulo = switch (_modo) {
      _Modo.ingresar => 'Qué bueno verte de nuevo.',
      _Modo.registrarse => 'En dos minutos tenés tu negocio organizado.',
      _Modo.recuperar => 'Te enviamos un enlace para crear una nueva.',
    };
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: AutofillGroup(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!context.esEscritorio) ...[
                const _Logo(),
                const SizedBox(height: Espacio.xxl),
              ],
              Text(titulo, style: context.textos.headlineSmall),
              const SizedBox(height: Espacio.xs),
              Text(subtitulo, style: TextStyle(color: context.esquema.onSurfaceVariant)),
              const SizedBox(height: Espacio.xl),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: _modo == _Modo.recuperar ? TextInputAction.done : TextInputAction.next,
                onFieldSubmitted: _modo == _Modo.recuperar ? (_) => _enviar() : null,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.alternate_email_rounded)),
                validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v?.trim() ?? '') ? null : 'Ingresá un email válido',
              ),
              if (_modo != _Modo.recuperar) ...[
                const SizedBox(height: Espacio.l),
                TextFormField(
                  controller: _clave,
                  obscureText: _ocultar,
                  autofillHints: [_modo == _Modo.registrarse ? AutofillHints.newPassword : AutofillHints.password],
                  textInputAction: _modo == _Modo.ingresar ? TextInputAction.done : TextInputAction.next,
                  onFieldSubmitted: _modo == _Modo.ingresar ? (_) => _enviar() : null,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      tooltip: _ocultar ? 'Mostrar' : 'Ocultar',
                      icon: Icon(_ocultar ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _ocultar = !_ocultar),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Ingresá tu contraseña';
                    if (_modo == _Modo.registrarse && v.length < 8) return 'Mínimo 8 caracteres';
                    return null;
                  },
                ),
              ],
              if (_modo == _Modo.registrarse) ...[
                const SizedBox(height: Espacio.l),
                TextFormField(
                  controller: _clave2,
                  obscureText: _ocultar,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _enviar(),
                  decoration: const InputDecoration(labelText: 'Repetí la contraseña', prefixIcon: Icon(Icons.lock_outline_rounded)),
                  validator: (v) => v == _clave.text ? null : 'Las contraseñas no coinciden',
                ),
              ],
              if (_modo == _Modo.ingresar)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(onPressed: () => _cambiarModo(_Modo.recuperar), child: const Text('¿Olvidaste tu contraseña?')),
                )
              else
                const SizedBox(height: Espacio.l),
              const SizedBox(height: Espacio.s),
              FilledButton(
                onPressed: _cargando ? null : _enviar,
                child: _cargando
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : Text(switch (_modo) {
                        _Modo.ingresar => 'Ingresar',
                        _Modo.registrarse => 'Crear cuenta',
                        _Modo.recuperar => 'Enviar enlace',
                      }),
              ),
              const SizedBox(height: Espacio.l),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_modo == _Modo.ingresar ? '¿No tenés cuenta?' : '¿Ya tenés cuenta?'),
                  TextButton(
                    onPressed: _cargando ? null : () => _cambiarModo(_modo == _Modo.ingresar ? _Modo.registrarse : _Modo.ingresar),
                    child: Text(_modo == _Modo.ingresar ? 'Registrate gratis' : 'Ingresá'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({this.claro = false});
  final bool claro;

  @override
  Widget build(BuildContext context) {
    final color = claro ? Colors.white : context.esquema.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: claro ? Colors.white.withValues(alpha: 0.15) : color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(Radios.m),
          ),
          child: Icon(Icons.handyman_rounded, color: color),
        ),
        const SizedBox(width: Espacio.m),
        Text(
          AppInfo.nombre,
          style: context.textos.titleLarge?.copyWith(color: claro ? Colors.white : null, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _PanelMarca extends StatelessWidget {
  const _PanelMarca();

  @override
  Widget build(BuildContext context) {
    const beneficios = [
      (Icons.dashboard_outlined, 'Todo tu negocio de un vistazo'),
      (Icons.chat_outlined, 'Avisos a clientes por WhatsApp'),
      (Icons.picture_as_pdf_outlined, 'Órdenes, presupuestos y recibos en PDF'),
      (Icons.insights_rounded, 'Cobros, gastos y ganancia del mes'),
    ];
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Paleta.navy950, Paleta.navy800, Color(0xFF1A3A8F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Logo(claro: true),
          const Spacer(),
          Text(
            AppInfo.eslogan,
            style: context.textos.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, height: 1.2),
          ),
          const SizedBox(height: Espacio.xxl),
          for (final b in beneficios)
            Padding(
              padding: const EdgeInsets.only(bottom: Espacio.l),
              child: Row(children: [
                Icon(b.$1, color: Colors.white70),
                const SizedBox(width: Espacio.m),
                Text(b.$2, style: const TextStyle(color: Colors.white, fontSize: 16)),
              ]),
            ),
          const Spacer(),
        ],
      ),
    );
  }
}
