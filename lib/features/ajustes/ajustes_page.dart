import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app/app_info.dart';
import '../../app/preferencias.dart';
import '../../app/sesion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/feedback.dart';
import '../../data/funciones.dart';
import '../../data/models/negocio.dart';
import '../../data/models/rubro.dart';
import '../planes/planes_page.dart';
import '../equipo/equipo_seccion.dart';
import '../planes/pro.dart';
import '../facturacion/config_arca_page.dart';

class AjustesPage extends StatelessWidget {
  const AjustesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final sesion = Sesion.of(context);
    final puedeEditar = sesion.rol.puedeAdministrar;
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(Espacio.l),
        children: [
          ContenidoCentrado(
            anchoMaximo: 760,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Seccion('Tu negocio', padding: EdgeInsets.only(bottom: Espacio.m)),
                _DatosNegocio(negocio: sesion.negocio, habilitado: puedeEditar),
                const Seccion('Mensajes de WhatsApp'),
                _Plantillas(negocio: sesion.negocio, habilitado: puedeEditar),
                if (sesion.puede(Permiso.gestionarEquipo)) ...[
                  const Seccion('Equipo'),
                  const EquipoSeccion(),
                ],
                if (AppInfo.facturacionDisponible && sesion.puede(Permiso.editarNegocio)) ...[
                  const Seccion('Facturación electrónica'),
                  AppCard(
                    onTap: () {
                      Funciones.despertar();
                      abrirPagina(context, const ConfigArcaPage());
                    },
                    child: Row(children: [
                      const IconoTile(Icons.receipt_long_outlined),
                      const SizedBox(width: Espacio.m),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('ARCA (ex AFIP)', style: context.textos.titleSmall),
                          Text('Datos fiscales y conexión para emitir facturas', style: context.textos.bodySmall),
                        ]),
                      ),
                      if (!sesion.negocio.permite(FuncionPro.facturacion)) const DistintivoPro(),
                      const Icon(Icons.chevron_right_rounded),
                    ]),
                  ),
                ],
                const Seccion('Apariencia'),
                const AppCard(child: Align(alignment: Alignment.centerLeft, child: SelectorTema())),
                const Seccion('Plan'),
                AppCard(
                  onTap: () => abrirPagina(context, const PlanesPage()),
                  child: Row(children: [
                    IconoTile(Icons.workspace_premium_rounded, color: context.colores.pro, fondo: context.colores.proSuave),
                    const SizedBox(width: Espacio.m),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(etiquetaPlan(sesion.negocio), style: context.textos.titleSmall),
                        Text(
                          sesion.negocio.esPro ? 'Tenés todas las funciones habilitadas' : 'Conocé lo que incluye cada plan',
                          style: context.textos.bodySmall,
                        ),
                      ]),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ]),
                ),
                const Seccion('Cuenta'),
                _Cuenta(sesion: sesion),
                const SizedBox(height: Espacio.xl),
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, s) => Text(
                    s.hasData ? '${AppInfo.nombre} · versión ${s.data!.version}' : AppInfo.nombre,
                    textAlign: TextAlign.center,
                    style: context.textos.bodySmall?.copyWith(color: context.esquema.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DatosNegocio extends StatefulWidget {
  const _DatosNegocio({required this.negocio, required this.habilitado});
  final Negocio negocio;
  final bool habilitado;

  @override
  State<_DatosNegocio> createState() => _DatosNegocioState();
}

class _DatosNegocioState extends State<_DatosNegocio> {
  final _form = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.negocio.nombre);
  late final _telefono = TextEditingController(text: widget.negocio.telefono);
  late final _direccion = TextEditingController(text: widget.negocio.direccion);
  late final _email = TextEditingController(text: widget.negocio.email);
  late final _cuit = TextEditingController(text: widget.negocio.cuit);
  late String _rubro = widget.negocio.rubroId;
  Future<Uint8List?>? _logo;
  bool _guardando = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _logo ??= Sesion.of(context).negocioRepo.logo();
  }

  @override
  void dispose() {
    for (final c in [_nombre, _telefono, _direccion, _email, _cuit]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _guardando = true);
    final sesion = Sesion.of(context);
    await ejecutar(
      context,
      () => sesion.negocioRepo.guardar(sesion.negocio.copyWith(
        nombre: _nombre.text.trim(),
        telefono: _telefono.text.trim(),
        direccion: _direccion.text.trim(),
        email: _email.text.trim(),
        cuit: _cuit.text.trim(),
        rubroId: _rubro,
      )),
      exito: 'Datos guardados',
    );
    if (mounted) setState(() => _guardando = false);
  }

  Future<void> _elegirLogo() async {
    final repo = Sesion.of(context).negocioRepo;
    final archivo = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 400, maxHeight: 400, imageQuality: 85);
    if (archivo == null || !mounted) return;
    final bytes = await archivo.readAsBytes();
    if (bytes.length > 500 * 1024) {
      if (mounted) mostrarMensaje(context, 'La imagen es muy pesada. Probá con una más chica.', error: true);
      return;
    }
    if (!mounted) return;
    final ok = await ejecutar(context, () => repo.guardarLogo(bytes), exito: 'Logo actualizado');
    if (ok && mounted) setState(() => _logo = Future.value(bytes));
  }

  Future<void> _quitarLogo() async {
    final repo = Sesion.of(context).negocioRepo;
    final ok = await ejecutar(context, () => repo.guardarLogo(null), exito: 'Logo eliminado');
    if (ok && mounted) setState(() => _logo = Future.value(null));
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.habilitado;
    return AppCard(
      padding: const EdgeInsets.all(Espacio.xl),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              FutureBuilder<Uint8List?>(
                future: _logo,
                builder: (context, s) => Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: context.colores.fondoSutil,
                    border: Border.all(color: context.colores.borde),
                    borderRadius: BorderRadius.circular(Radios.m),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: s.data != null
                      ? Image.memory(s.data!, fit: BoxFit.contain)
                      : Icon(Icons.add_photo_alternate_outlined, color: context.esquema.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: Espacio.l),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Logo', style: context.textos.titleSmall),
                  Text('Aparece en órdenes, presupuestos y recibos.', style: context.textos.bodySmall),
                  const SizedBox(height: Espacio.s),
                  Wrap(spacing: Espacio.s, children: [
                    OutlinedButton(onPressed: h ? _elegirLogo : null, child: const Text('Elegir imagen')),
                    if (widget.negocio.tieneLogo) TextButton(onPressed: h ? _quitarLogo : null, child: const Text('Quitar')),
                  ]),
                ]),
              ),
            ]),
            const SizedBox(height: Espacio.xl),
            TextFormField(
              controller: _nombre,
              enabled: h,
              decoration: const InputDecoration(labelText: 'Nombre del negocio'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
            ),
            const SizedBox(height: Espacio.l),
            DropdownButtonFormField<String>(
              value: _rubro,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Rubro', helperText: 'Adapta los nombres y campos del sistema'),
              items: [
                for (final r in Rubro.todos)
                  DropdownMenuItem(value: r.id, child: Row(children: [Icon(r.icono, size: 20), const SizedBox(width: 10), Text(r.nombre)])),
              ],
              onChanged: h ? (v) => setState(() => _rubro = v ?? _rubro) : null,
            ),
            const SizedBox(height: Espacio.l),
            TextFormField(controller: _telefono, enabled: h, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Teléfono')),
            const SizedBox(height: Espacio.l),
            TextFormField(controller: _direccion, enabled: h, decoration: const InputDecoration(labelText: 'Dirección')),
            const SizedBox(height: Espacio.l),
            TextFormField(controller: _email, enabled: h, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email de contacto')),
            const SizedBox(height: Espacio.l),
            TextFormField(controller: _cuit, enabled: h, decoration: const InputDecoration(labelText: 'CUIT (opcional)')),
            const SizedBox(height: Espacio.xl),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: (!h || _guardando) ? null : _guardar,
                child: _guardando
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : const Text('Guardar cambios'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Plantillas extends StatefulWidget {
  const _Plantillas({required this.negocio, required this.habilitado});
  final Negocio negocio;
  final bool habilitado;

  @override
  State<_Plantillas> createState() => _PlantillasState();
}

class _PlantillasState extends State<_Plantillas> {
  late final Map<String, TextEditingController> _ctrls = {
    for (final k in PlantillasMensaje.etiquetas.keys) k: TextEditingController(text: widget.negocio.plantilla(k)),
  };
  bool _guardando = false;

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    final sesion = Sesion.of(context);
    final plantillas = {for (final e in _ctrls.entries) e.key: e.value.text.trim()};
    await ejecutar(context, () => sesion.negocioRepo.guardar(sesion.negocio.copyWith(plantillas: plantillas)), exito: 'Mensajes guardados');
    if (mounted) setState(() => _guardando = false);
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(Espacio.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Variables disponibles: ${PlantillasMensaje.variables.keys.join('  ')}',
            style: context.textos.bodySmall?.copyWith(color: context.esquema.onSurfaceVariant),
          ),
          for (final e in PlantillasMensaje.etiquetas.entries) ...[
            const SizedBox(height: Espacio.l),
            TextField(
              controller: _ctrls[e.key],
              enabled: widget.habilitado,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: e.value,
                alignLabelWithHint: true,
                suffixIcon: IconButton(
                  tooltip: 'Restaurar texto original',
                  icon: const Icon(Icons.restart_alt_rounded),
                  onPressed: widget.habilitado ? () => _ctrls[e.key]!.text = PlantillasMensaje.porDefecto[e.key]! : null,
                ),
              ),
            ),
          ],
          const SizedBox(height: Espacio.l),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonal(
              onPressed: (!widget.habilitado || _guardando) ? null : _guardar,
              child: const Text('Guardar mensajes'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Cuenta extends StatelessWidget {
  const _Cuenta({required this.sesion});
  final Sesion sesion;

  @override
  Widget build(BuildContext context) {
    final email = sesion.usuario.email ?? '';
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: Espacio.s),
      child: Column(children: [
        ListTile(
          leading: const Icon(Icons.account_circle_outlined),
          title: Text(email),
          subtitle: Text(sesion.rol.etiqueta),
        ),
        ListTile(
          leading: const Icon(Icons.lock_reset_rounded),
          title: const Text('Cambiar contraseña'),
          subtitle: const Text('Te enviamos un email para elegir una nueva'),
          onTap: () => ejecutar(
            context,
            () => FirebaseAuth.instance.sendPasswordResetEmail(email: email),
            exito: 'Te enviamos un email a $email',
          ),
        ),
        if (sesion.rol != RolMiembro.duenio)
          ListTile(
            leading: const Icon(Icons.exit_to_app_rounded),
            title: Text('Salir de ${sesion.negocio.nombre}'),
            subtitle: const Text('Dejás de tener acceso a este negocio'),
            onTap: () async {
              final ok = await confirmar(
                context,
                titulo: 'Salir del negocio',
                mensaje: 'Vas a dejar de tener acceso a ${sesion.negocio.nombre}. Para volver, te tienen que invitar de nuevo.',
                confirmar: 'Salir',
                peligroso: true,
              );
              if (ok && context.mounted) await ejecutar(context, () => sesion.equipo.salir(sesion.usuario.uid));
            },
          ),
        ListTile(
          leading: Icon(Icons.logout_rounded, color: context.colores.peligro),
          title: Text('Cerrar sesión', style: TextStyle(color: context.colores.peligro)),
          onTap: () => cerrarSesion(context),
        ),
      ]),
    );
  }
}

Future<void> cerrarSesion(BuildContext context) async {
  final ok = await confirmar(context, titulo: 'Cerrar sesión', mensaje: '¿Querés salir de tu cuenta?', confirmar: 'Salir');
  if (!ok) return;
  if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  await FirebaseAuth.instance.signOut();
}
