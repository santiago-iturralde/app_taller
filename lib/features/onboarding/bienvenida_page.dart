import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/feedback.dart';
import '../../data/models/equipo.dart';
import '../../data/repositories/equipo_repository.dart';
import 'onboarding_page.dart';

/// Primera pantalla de un usuario sin negocio: crear el propio o sumarse a
/// uno al que lo invitaron.
class BienvenidaPage extends StatefulWidget {
  const BienvenidaPage({super.key, required this.usuario, required this.onListo});
  final User usuario;
  final VoidCallback onListo;

  @override
  State<BienvenidaPage> createState() => _BienvenidaPageState();
}

enum _Vista { inicio, verificar, crear }

class _BienvenidaPageState extends State<BienvenidaPage> {
  final _repo = MisInvitaciones();
  _Vista _vista = _Vista.inicio;
  Future<List<Invitacion>>? _invitaciones;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() => setState(() => _invitaciones = _repo.pendientes(FirebaseAuth.instance.currentUser ?? widget.usuario));

  Future<void> _yaVerifique() async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) return;
    await usuario.reload();
    final actualizado = FirebaseAuth.instance.currentUser!;
    if (!mounted) return;
    if (!actualizado.emailVerified) {
      mostrarMensaje(context, 'Todavía no figura verificado. Revisá tu correo (y la carpeta de spam).', error: true);
      return;
    }
    await actualizado.getIdToken(true);
    setState(() => _vista = _Vista.inicio);
    _cargar();
  }

  Future<void> _aceptar(Invitacion i) async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) return;
    final ok = await ejecutar(context, () => _repo.aceptar(i, usuario), exito: '¡Bienvenido a ${i.negocioNombre}!');
    if (ok) widget.onListo();
  }

  Future<void> _rechazar(Invitacion i) async {
    final seguro = await confirmar(
      context,
      titulo: 'Rechazar invitación',
      mensaje: 'No vas a sumarte a ${i.negocioNombre}. Si cambiás de idea, tendrán que invitarte de nuevo.',
      confirmar: 'Rechazar',
      peligroso: true,
    );
    if (!seguro || !mounted) return;
    await ejecutar(context, () => _repo.rechazar(i));
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    if (_vista == _Vista.crear) {
      return OnboardingPage(usuario: widget.usuario, onListo: widget.onListo, onVolver: () => setState(() => _vista = _Vista.inicio));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bienvenido'),
        actions: [TextButton(onPressed: () => FirebaseAuth.instance.signOut(), child: const Text('Salir'))],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Espacio.xl),
          child: ContenidoCentrado(
            anchoMaximo: 640,
            child: _vista == _Vista.verificar ? _verificar() : _inicio(),
          ),
        ),
      ),
    );
  }

  Widget _inicio() {
    return FutureBuilder<List<Invitacion>>(
      future: _invitaciones,
      builder: (context, s) {
        if (s.connectionState == ConnectionState.waiting) return const SizedBox(height: 240, child: Cargando());
        final invitaciones = s.data ?? const <Invitacion>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('¿Cómo querés empezar?', style: context.textos.headlineSmall),
            const SizedBox(height: Espacio.xs),
            Text(widget.usuario.email ?? '', style: TextStyle(color: context.esquema.onSurfaceVariant)),
            const SizedBox(height: Espacio.xl),
            if (invitaciones.isNotEmpty) ...[
              Text('Te invitaron a', style: context.textos.titleSmall),
              const SizedBox(height: Espacio.s),
              for (final i in invitaciones) ...[
                AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      const IconoTile(Icons.storefront_outlined, tamanio: 44),
                      const SizedBox(width: Espacio.m),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(i.negocioNombre, style: context.textos.titleMedium),
                          Text('Como ${i.rol.etiqueta.toLowerCase()} · vence el ${Formato.fecha(i.vence)}',
                              style: context.textos.bodySmall),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: Espacio.m),
                    Text(i.rol.descripcion, style: context.textos.bodySmall?.copyWith(color: context.esquema.onSurfaceVariant)),
                    const SizedBox(height: Espacio.m),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      TextButton(onPressed: () => _rechazar(i), child: const Text('Rechazar')),
                      const SizedBox(width: Espacio.s),
                      FilledButton(onPressed: () => _aceptar(i), child: const Text('Unirme')),
                    ]),
                  ]),
                ),
                const SizedBox(height: Espacio.m),
              ],
              const SizedBox(height: Espacio.l),
              Text('O también podés', style: context.textos.titleSmall),
              const SizedBox(height: Espacio.s),
            ],
            _Opcion(
              icono: Icons.add_business_outlined,
              titulo: 'Crear mi negocio',
              descripcion: 'Empezá gratis y configurá el sistema para tu rubro.',
              onTap: () => setState(() => _vista = _Vista.crear),
            ),
            if (invitaciones.isEmpty) ...[
              const SizedBox(height: Espacio.m),
              _Opcion(
                icono: Icons.group_add_outlined,
                titulo: 'Me invitaron a un negocio',
                descripcion: 'Sumate al equipo de un negocio que ya usa el sistema.',
                onTap: () {
                  if (FirebaseAuth.instance.currentUser?.emailVerified ?? false) {
                    _cargar();
                    mostrarMensaje(context, 'No encontramos invitaciones para ${widget.usuario.email}. '
                        'Pedile al negocio que te invite con este email.');
                  } else {
                    setState(() => _vista = _Vista.verificar);
                  }
                },
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _verificar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const IconoTile(Icons.mark_email_unread_outlined, tamanio: 64),
        const SizedBox(height: Espacio.l),
        Text('Verificá tu email', style: context.textos.headlineSmall),
        const SizedBox(height: Espacio.s),
        Text(
          'Por seguridad, para ver las invitaciones tenemos que confirmar que ${widget.usuario.email} es tuyo. '
          'Te enviamos un enlace a ese correo: abrilo y después tocá "Ya lo verifiqué".',
          style: TextStyle(color: context.esquema.onSurfaceVariant, height: 1.45),
        ),
        const SizedBox(height: Espacio.xl),
        FilledButton(onPressed: _yaVerifique, child: const Text('Ya lo verifiqué')),
        const SizedBox(height: Espacio.s),
        OutlinedButton(
          onPressed: () => ejecutar(
            context,
            () => FirebaseAuth.instance.currentUser!.sendEmailVerification(),
            exito: 'Te reenviamos el enlace a ${widget.usuario.email}',
          ),
          child: const Text('Reenviar el email'),
        ),
        TextButton(onPressed: () => setState(() => _vista = _Vista.inicio), child: const Text('Volver')),
      ],
    );
  }
}

class _Opcion extends StatelessWidget {
  const _Opcion({required this.icono, required this.titulo, required this.descripcion, required this.onTap});
  final IconData icono;
  final String titulo;
  final String descripcion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(Espacio.xl),
        child: Row(children: [
          IconoTile(icono, tamanio: 48),
          const SizedBox(width: Espacio.l),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titulo, style: context.textos.titleMedium),
              const SizedBox(height: 2),
              Text(descripcion, style: context.textos.bodySmall?.copyWith(color: context.esquema.onSurfaceVariant)),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded),
        ]),
      );
}
