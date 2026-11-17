import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Estructura común de todos los formularios: título, contenido con scroll
/// y botón principal fijo abajo. Funciona igual como página o diálogo.
class FormularioScaffold extends StatelessWidget {
  const FormularioScaffold({
    super.key,
    required this.titulo,
    required this.formKey,
    required this.children,
    required this.onGuardar,
    this.guardando = false,
    this.textoGuardar = 'Guardar',
    this.acciones = const [],
  });

  final String titulo;
  final GlobalKey<FormState> formKey;
  final List<Widget> children;
  final VoidCallback onGuardar;
  final bool guardando;
  final String textoGuardar;
  final List<Widget> acciones;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.esquema.surface,
      appBar: AppBar(
        title: Text(titulo),
        leading: IconButton(
          tooltip: 'Cerrar',
          icon: const Icon(Icons.close_rounded),
          onPressed: guardando ? null : () => Navigator.maybePop(context),
        ),
        actions: acciones,
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Espacio.xl, Espacio.xl, Espacio.xl, Espacio.xxl),
          children: children,
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(Espacio.xl, Espacio.m, Espacio.xl, Espacio.m),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: context.colores.borde))),
          child: FilledButton(
            onPressed: guardando ? null : onGuardar,
            child: guardando
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                : Text(textoGuardar),
          ),
        ),
      ),
    );
  }
}

/// Título de grupo dentro de un formulario.
class GrupoFormulario extends StatelessWidget {
  const GrupoFormulario(this.titulo, {super.key, this.primero = false});
  final String titulo;
  final bool primero;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: primero ? 0 : Espacio.xl, bottom: Espacio.m),
        child: Text(
          titulo.toUpperCase(),
          style: context.textos.labelMedium?.copyWith(
            color: context.esquema.onSurfaceVariant,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

/// Dos campos lado a lado en pantallas anchas, apilados en celular.
class FilaCampos extends StatelessWidget {
  const FilaCampos({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 480) {
        return Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: Espacio.l),
              children[i],
            ],
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: Espacio.m),
            Expanded(child: children[i]),
          ],
        ],
      );
    });
  }
}

const espacioCampos = SizedBox(height: Espacio.l);
