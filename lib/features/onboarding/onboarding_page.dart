import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/feedback.dart';
import '../../data/db.dart';
import '../../data/migracion_legacy.dart';
import '../../data/models/rubro.dart';

/// Primer uso: elegir el rubro y cargar los datos básicos del negocio.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.usuario, required this.onListo});
  final User usuario;
  final VoidCallback onListo;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _telefono = TextEditingController();
  final _direccion = TextEditingController();
  Rubro? _rubro;
  int _paso = 0;
  bool _guardando = false;

  @override
  void dispose() {
    _nombre.dispose();
    _telefono.dispose();
    _direccion.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _guardando = true);
    final uid = widget.usuario.uid;
    final ok = await ejecutar(context, () async {
      await crearNegocio(
        db: Db(uid),
        uid: uid,
        email: widget.usuario.email ?? '',
        nombre: _nombre.text.trim(),
        rubro: _rubro!.id,
        telefono: _telefono.text.trim(),
        direccion: _direccion.text.trim(),
      );
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({'negocioId': uid, 'email': widget.usuario.email}, SetOptions(merge: true));
    });
    if (!mounted) return;
    setState(() => _guardando = false);
    if (ok) widget.onListo();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Paso ${_paso + 1} de 2'),
        leading: _paso == 1 ? IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => setState(() => _paso = 0)) : null,
        actions: [TextButton(onPressed: () => FirebaseAuth.instance.signOut(), child: const Text('Salir'))],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Espacio.xl),
          child: ContenidoCentrado(
            anchoMaximo: 820,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _paso == 0 ? _pasoRubro() : _pasoDatos(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pasoRubro() {
    return Column(
      key: const ValueKey('rubro'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('¿A qué se dedica tu negocio?', style: context.textos.headlineSmall),
        const SizedBox(height: Espacio.xs),
        Text(
          'Adaptamos el sistema a tu rubro. Lo podés cambiar cuando quieras.',
          style: TextStyle(color: context.esquema.onSurfaceVariant),
        ),
        const SizedBox(height: Espacio.xl),
        GrillaAdaptable(anchoMinimo: 240, children: [
          for (final r in Rubro.todos)
            Card(
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Radios.l),
                side: BorderSide(
                  color: _rubro == r ? context.esquema.primary : context.colores.borde,
                  width: _rubro == r ? 2 : 1,
                ),
              ),
              child: InkWell(
                onTap: () => setState(() {
                  _rubro = r;
                  _paso = 1;
                }),
                child: Padding(
                  padding: const EdgeInsets.all(Espacio.l),
                  child: Row(children: [
                    IconoTile(r.icono, tamanio: 44),
                    const SizedBox(width: Espacio.m),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.nombre, style: context.textos.titleSmall),
                        Text(r.descripcion, style: context.textos.bodySmall, maxLines: 2),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
        ]),
      ],
    );
  }

  Widget _pasoDatos() {
    return Form(
      key: _form,
      child: Column(
        key: const ValueKey('datos'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            IconoTile(_rubro!.icono, tamanio: 48),
            const SizedBox(width: Espacio.m),
            Expanded(child: Text('Contanos de tu negocio', style: context.textos.headlineSmall)),
          ]),
          const SizedBox(height: Espacio.xs),
          Text('Estos datos aparecen en las órdenes, presupuestos y recibos.', style: TextStyle(color: context.esquema.onSurfaceVariant)),
          const SizedBox(height: Espacio.xl),
          TextFormField(
            controller: _nombre,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nombre del negocio', prefixIcon: Icon(Icons.storefront_outlined)),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Contanos cómo se llama' : null,
          ),
          const SizedBox(height: Espacio.l),
          TextFormField(
            controller: _telefono,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Teléfono / WhatsApp (opcional)', prefixIcon: Icon(Icons.phone_outlined)),
          ),
          const SizedBox(height: Espacio.l),
          TextFormField(
            controller: _direccion,
            decoration: const InputDecoration(labelText: 'Dirección (opcional)', prefixIcon: Icon(Icons.place_outlined)),
            onFieldSubmitted: (_) => _crear(),
          ),
          const SizedBox(height: Espacio.xxl),
          FilledButton(
            onPressed: _guardando ? null : _crear,
            child: _guardando
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                : const Text('Empezar a usar el sistema'),
          ),
        ],
      ),
    );
  }
}
