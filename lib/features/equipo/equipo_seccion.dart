import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_info.dart';
import '../../app/sesion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formato.dart';
import '../../core/utils/whatsapp.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/feedback.dart';
import '../../data/models/equipo.dart';
import '../../data/models/negocio.dart';
import '../planes/pro.dart';

/// Sección "Equipo" de Ajustes: miembros, roles e invitaciones.
class EquipoSeccion extends StatelessWidget {
  const EquipoSeccion({super.key});

  @override
  Widget build(BuildContext context) {
    final sesion = Sesion.of(context);
    return StreamBuilder<List<Miembro>>(
      stream: sesion.equipo.miembros(),
      builder: (context, sm) {
        if (sm.hasError) return EstadoError(error: sm.error);
        if (!sm.hasData) return const SizedBox(height: 120, child: Cargando());
        final miembros = sm.data!;
        return StreamBuilder<List<Invitacion>>(
          stream: sesion.equipo.invitaciones(),
          builder: (context, si) {
            final invitaciones = si.data ?? const <Invitacion>[];
            return AppCard(
              padding: const EdgeInsets.symmetric(vertical: Espacio.m),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Espacio.l),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        '${miembros.length} ${miembros.length == 1 ? 'persona' : 'personas'} con acceso',
                        style: context.textos.bodyMedium?.copyWith(color: context.esquema.onSurfaceVariant),
                      ),
                    ),
                    if (!sesion.negocio.permite(FuncionPro.equipo)) const DistintivoPro(),
                    const SizedBox(width: Espacio.s),
                    FilledButton.tonalIcon(
                      onPressed: () => _invitar(context, miembros, invitaciones),
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text('Invitar'),
                    ),
                  ]),
                ),
                const SizedBox(height: Espacio.s),
                for (final m in miembros) _FilaMiembro(miembro: m),
                if (invitaciones.isNotEmpty) ...[
                  const Divider(height: Espacio.xl),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Espacio.l),
                    child: Text('Invitaciones pendientes', style: context.textos.titleSmall),
                  ),
                  for (final i in invitaciones) _FilaInvitacion(invitacion: i),
                ],
              ]),
            );
          },
        );
      },
    );
  }

  Future<void> _invitar(BuildContext context, List<Miembro> miembros, List<Invitacion> pendientes) async {
    if (!await exigirPro(context, FuncionPro.equipo) || !context.mounted) return;
    final sesion = Sesion.of(context);
    final datos = await showDialog<(String, RolMiembro)>(
      context: context,
      builder: (_) => _DialogoInvitar(puedeInvitarAdmins: sesion.puede(Permiso.invitarAdministradores)),
    );
    if (datos == null || !context.mounted) return;
    Invitacion? invitacion;
    final ok = await ejecutar(context, () async {
      invitacion = await sesion.equipo.invitar(
        email: datos.$1,
        rol: datos.$2,
        negocio: sesion.negocio,
        invitadoPor: sesion.usuario.uid,
        pendientes: pendientes,
        miembros: miembros,
      );
    });
    if (ok && context.mounted) await compartirInvitacion(context, invitacion!);
  }
}

String _mensajeInvitacion(Invitacion i) {
  final url = kIsWeb ? Uri.base.origin : AppInfo.urlWeb;
  return 'Hola! Te invité a sumarte a "${i.negocioNombre}" en ${AppInfo.nombre} como ${i.rol.etiqueta.toLowerCase()}. '
      '${url.isEmpty ? 'Ingresá a la app' : 'Entrá a $url'}, creá tu cuenta con este email (${i.email}), '
      'verificalo y aceptá la invitación. Vence el ${Formato.fecha(i.vence)}.';
}

/// Muestra el mensaje para enviarle al invitado (WhatsApp o copiar).
Future<void> compartirInvitacion(BuildContext context, Invitacion i) {
  final mensaje = _mensajeInvitacion(i);
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: IconoTile(Icons.mark_email_read_outlined, tamanio: 56, color: context.colores.exito, fondo: context.colores.exitoSuave),
      title: const Text('Invitación creada'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Mandale este mensaje a ${i.email}:'),
        const SizedBox(height: Espacio.m),
        Container(
          padding: const EdgeInsets.all(Espacio.m),
          decoration: BoxDecoration(
            color: context.colores.fondoSutil,
            borderRadius: BorderRadius.circular(Radios.m),
            border: Border.all(color: context.colores.borde),
          ),
          child: SelectableText(mensaje),
        ),
      ]),
      actions: [
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: mensaje));
            if (context.mounted) mostrarMensaje(context, 'Mensaje copiado');
          },
          icon: const Icon(Icons.copy_rounded),
          label: const Text('Copiar'),
        ),
        FilledButton.icon(
          onPressed: () => WhatsApp.compartir(mensaje),
          icon: const Icon(Icons.chat_outlined),
          label: const Text('WhatsApp'),
        ),
      ],
    ),
  );
}

class _DialogoInvitar extends StatefulWidget {
  const _DialogoInvitar({required this.puedeInvitarAdmins});
  final bool puedeInvitarAdmins;

  @override
  State<_DialogoInvitar> createState() => _DialogoInvitarState();
}

class _DialogoInvitarState extends State<_DialogoInvitar> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  RolMiembro _rol = RolMiembro.empleado;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _enviar() {
    if (_form.currentState!.validate()) Navigator.pop(context, (_email.text, _rol));
  }

  @override
  Widget build(BuildContext context) {
    final roles = [RolMiembro.empleado, if (widget.puedeInvitarAdmins) RolMiembro.admin];
    return AlertDialog(
      title: const Text('Invitar al equipo'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Form(
          key: _form,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextFormField(
              controller: _email,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email de la persona', prefixIcon: Icon(Icons.alternate_email_rounded)),
              validator: (v) => Invitacion.emailValido(v ?? '') ? null : 'Ingresá un email válido',
              onFieldSubmitted: (_) => _enviar(),
            ),
            const SizedBox(height: Espacio.l),
            for (final r in roles)
              RadioListTile<RolMiembro>(
                value: r,
                groupValue: _rol,
                contentPadding: EdgeInsets.zero,
                title: Text(r.etiqueta),
                subtitle: Text(r.descripcion),
                onChanged: (v) => setState(() => _rol = v ?? _rol),
              ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _enviar, child: const Text('Crear invitación')),
      ],
    );
  }
}

class _FilaMiembro extends StatelessWidget {
  const _FilaMiembro({required this.miembro});
  final Miembro miembro;

  @override
  Widget build(BuildContext context) {
    final sesion = Sesion.of(context);
    final m = miembro;
    final soyYo = m.uid == sesion.usuario.uid;
    final esDuenio = sesion.rol == RolMiembro.duenio;
    final puedeQuitar = !soyYo && m.rol != RolMiembro.duenio && (esDuenio || (sesion.rol == RolMiembro.admin && m.rol == RolMiembro.empleado));
    final puedeCambiarRol = esDuenio && !soyYo && m.rol != RolMiembro.duenio;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: Espacio.l),
      leading: Iniciales(m.email.isEmpty ? '?' : m.email[0].toUpperCase(), radio: 18),
      title: Text(m.email.isEmpty ? 'Usuario' : m.email, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(soyYo ? '${m.rol.etiqueta} · vos' : m.rol.etiqueta),
      trailing: (puedeQuitar || puedeCambiarRol)
          ? PopupMenuButton<String>(
              tooltip: 'Opciones',
              onSelected: (v) async {
                if (v == 'quitar') {
                  final ok = await confirmar(
                    context,
                    titulo: 'Quitar del equipo',
                    mensaje: '${m.email} va a perder el acceso al negocio de inmediato.',
                    confirmar: 'Quitar',
                    peligroso: true,
                  );
                  if (ok && context.mounted) await ejecutar(context, () => sesion.equipo.quitar(m.uid), exito: 'Acceso quitado');
                } else {
                  final nuevo = v == 'admin' ? RolMiembro.admin : RolMiembro.empleado;
                  await ejecutar(context, () => sesion.equipo.cambiarRol(m.uid, nuevo), exito: 'Ahora es ${nuevo.etiqueta.toLowerCase()}');
                }
              },
              itemBuilder: (_) => [
                if (puedeCambiarRol && m.rol != RolMiembro.admin)
                  const PopupMenuItem(value: 'admin', child: ListTile(leading: Icon(Icons.admin_panel_settings_outlined), title: Text('Hacer administrador'))),
                if (puedeCambiarRol && m.rol != RolMiembro.empleado)
                  const PopupMenuItem(value: 'empleado', child: ListTile(leading: Icon(Icons.badge_outlined), title: Text('Hacer empleado'))),
                if (puedeQuitar)
                  const PopupMenuItem(value: 'quitar', child: ListTile(leading: Icon(Icons.person_remove_outlined), title: Text('Quitar del equipo'))),
              ],
            )
          : null,
    );
  }
}

class _FilaInvitacion extends StatelessWidget {
  const _FilaInvitacion({required this.invitacion});
  final Invitacion invitacion;

  @override
  Widget build(BuildContext context) {
    final i = invitacion;
    final c = context.colores;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: Espacio.l),
      leading: IconoTile(Icons.schedule_send_outlined, tamanio: 36, color: i.vencida ? c.neutro : c.alerta, fondo: i.vencida ? c.neutroSuave : c.alertaSuave),
      title: Text(i.email, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${i.rol.etiqueta} · ${i.vencida ? 'vencida' : 'vence el ${Formato.fecha(i.vence)}'}'),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (!i.vencida)
          IconButton(
            tooltip: 'Volver a enviar el mensaje',
            icon: const Icon(Icons.share_outlined),
            onPressed: () => compartirInvitacion(context, i),
          ),
        IconButton(
          tooltip: 'Cancelar invitación',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => ejecutar(context, () => Sesion.of(context).equipo.cancelarInvitacion(i), exito: 'Invitación cancelada'),
        ),
      ]),
    );
  }
}
