import 'package:flutter/material.dart';

import '../../app/sesion.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/formulario.dart';
import '../../data/models/cliente.dart';

/// Alta y edición de clientes. Devuelve el [Cliente] guardado.
class ClienteForm extends StatefulWidget {
  const ClienteForm({super.key, this.cliente, this.nombreInicial = ''});

  final Cliente? cliente;
  final String nombreInicial;

  @override
  State<ClienteForm> createState() => _ClienteFormState();
}

class _ClienteFormState extends State<ClienteForm> {
  final _form = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.cliente?.nombre ?? _capitalizar(widget.nombreInicial));
  late final _telefono = TextEditingController(text: widget.cliente?.telefono);
  late final _documento = TextEditingController(text: widget.cliente?.documento);
  late final _email = TextEditingController(text: widget.cliente?.email);
  late final _direccion = TextEditingController(text: widget.cliente?.direccion);
  late final _notas = TextEditingController(text: widget.cliente?.notas);
  bool _guardando = false;

  static String _capitalizar(String s) =>
      s.split(' ').map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1)).join(' ');

  @override
  void dispose() {
    for (final c in [_nombre, _telefono, _documento, _email, _direccion, _notas]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _guardando = true);
    final repo = Sesion.of(context).clientes;
    final datos = Cliente(
      id: widget.cliente?.id ?? '',
      nombre: _nombre.text.trim(),
      telefono: _telefono.text.trim(),
      documento: _documento.text.trim(),
      email: _email.text.trim(),
      direccion: _direccion.text.trim(),
      notas: _notas.text.trim(),
      fechaAlta: widget.cliente?.fechaAlta,
    );
    Cliente? resultado;
    final ok = await ejecutar(context, () async {
      if (widget.cliente == null) {
        resultado = await repo.crear(datos);
      } else {
        await repo.actualizar(datos);
        resultado = datos;
      }
    }, exito: widget.cliente == null ? 'Cliente creado' : 'Cambios guardados');
    if (!mounted) return;
    setState(() => _guardando = false);
    if (ok) Navigator.pop(context, resultado);
  }

  @override
  Widget build(BuildContext context) {
    return FormularioScaffold(
      titulo: widget.cliente == null ? 'Nuevo cliente' : 'Editar cliente',
      formKey: _form,
      guardando: _guardando,
      onGuardar: _guardar,
      children: [
        TextFormField(
          controller: _nombre,
          autofocus: widget.cliente == null,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Nombre y apellido / Razón social', prefixIcon: Icon(Icons.person_outline)),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'El nombre es obligatorio' : null,
        ),
        espacioCampos,
        FilaCampos(children: [
          TextFormField(
            controller: _telefono,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Teléfono / WhatsApp',
              prefixIcon: Icon(Icons.phone_outlined),
              helperText: 'Con característica, ej: 11 5544 3322',
            ),
          ),
          TextFormField(
            controller: _documento,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'DNI / CUIT', prefixIcon: Icon(Icons.badge_outlined)),
          ),
        ]),
        espacioCampos,
        FilaCampos(children: [
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.alternate_email_rounded)),
            validator: (v) {
              final t = v?.trim() ?? '';
              return t.isEmpty || RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t) ? null : 'Email inválido';
            },
          ),
          TextFormField(
            controller: _direccion,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Dirección', prefixIcon: Icon(Icons.place_outlined)),
          ),
        ]),
        espacioCampos,
        TextFormField(
          controller: _notas,
          maxLines: 3,
          minLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Notas internas', alignLabelWithHint: true),
        ),
      ],
    );
  }
}
