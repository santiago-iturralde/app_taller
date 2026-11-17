import 'package:flutter/material.dart';

import '../../app/sesion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/campos.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/formulario.dart';
import '../../data/models/caja.dart';

class GastoForm extends StatefulWidget {
  const GastoForm({super.key, this.gasto});
  final Gasto? gasto;

  @override
  State<GastoForm> createState() => _GastoFormState();
}

class _GastoFormState extends State<GastoForm> {
  final _form = GlobalKey<FormState>();
  late final _descripcion = TextEditingController(text: widget.gasto?.descripcion);
  late final _monto = TextEditingController(text: Formato.montoEditable(widget.gasto?.monto));
  late String? _categoria = widget.gasto?.categoria;
  late MedioPago _medio = widget.gasto?.medio ?? MedioPago.efectivo;
  late DateTime _fecha = widget.gasto?.fecha ?? DateTime.now();
  bool _guardando = false;

  @override
  void dispose() {
    _descripcion.dispose();
    _monto.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _guardando = true);
    final caja = Sesion.of(context).caja;
    final gasto = Gasto(
      id: widget.gasto?.id ?? '',
      descripcion: _descripcion.text.trim(),
      monto: Formato.parseMonto(_monto.text)!,
      categoria: _categoria ?? 'Otros',
      fecha: _fecha,
      medio: _medio,
    );
    final ok = await ejecutar(context, () => caja.guardarGasto(gasto), exito: widget.gasto == null ? 'Gasto registrado' : 'Cambios guardados');
    if (!mounted) return;
    setState(() => _guardando = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final categorias = {...Sesion.of(context).negocio.rubro.categoriasGastos, if (_categoria != null) _categoria!}.toList();
    return FormularioScaffold(
      titulo: widget.gasto == null ? 'Registrar gasto' : 'Editar gasto',
      formKey: _form,
      guardando: _guardando,
      onGuardar: _guardar,
      children: [
        TextFormField(
          controller: _descripcion,
          autofocus: widget.gasto == null,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Descripción', hintText: 'Ej: Compra de rodamientos'),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Completá la descripción' : null,
        ),
        espacioCampos,
        FilaCampos(children: [
          CampoMonto(controller: _monto, etiqueta: 'Monto'),
          CampoFecha(etiqueta: 'Fecha', valor: _fecha, ultima: DateTime.now(), onCambio: (f) => setState(() => _fecha = f ?? _fecha)),
        ]),
        const GrupoFormulario('Categoría'),
        FormField<String>(
          initialValue: _categoria,
          validator: (v) => v == null ? 'Elegí una categoría' : null,
          builder: (state) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: Espacio.s,
                runSpacing: Espacio.s,
                children: [
                  for (final c in categorias)
                    ChoiceChip(
                      label: Text(c),
                      selected: _categoria == c,
                      showCheckmark: false,
                      onSelected: (_) {
                        setState(() => _categoria = c);
                        state.didChange(c);
                      },
                    ),
                ],
              ),
              if (state.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: Espacio.s),
                  child: Text(state.errorText!, style: TextStyle(color: context.esquema.error, fontSize: 12)),
                ),
            ],
          ),
        ),
        const GrupoFormulario('Forma de pago'),
        DropdownButtonFormField<MedioPago>(
          value: _medio,
          items: [for (final m in MedioPago.values) DropdownMenuItem(value: m, child: Text(m.etiqueta))],
          onChanged: (m) => setState(() => _medio = m ?? _medio),
        ),
      ],
    );
  }
}
