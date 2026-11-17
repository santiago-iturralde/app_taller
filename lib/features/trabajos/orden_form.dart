import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/sesion.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/campos.dart';
import '../../core/widgets/editor_items.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/formulario.dart';
import '../../data/models/cliente.dart';
import '../../data/models/comunes.dart';
import '../../data/models/orden.dart';
import '../clientes/selector_cliente.dart';

/// Alta y edición de trabajos. Devuelve la [Orden] guardada.
class OrdenForm extends StatefulWidget {
  const OrdenForm({super.key, this.orden, this.clienteInicial});

  final Orden? orden;
  final Cliente? clienteInicial;

  @override
  State<OrdenForm> createState() => _OrdenFormState();
}

class _OrdenFormState extends State<OrdenForm> {
  final _form = GlobalKey<FormState>();
  late final Orden? _o = widget.orden;

  late final _equipo = TextEditingController(text: _o?.equipo.descripcion);
  late final _identificador = TextEditingController(text: _o?.equipo.identificador);
  late final _km = TextEditingController(
    text: _o?.equipo.kilometraje == null ? '' : Formato.cantidad(_o!.equipo.kilometraje!),
  );
  late final _problema = TextEditingController(text: _o?.problema);
  late final _notas = TextEditingController(text: _o?.notas);

  late Cliente? _cliente = widget.clienteInicial ??
      (_o == null
          ? null
          : Cliente(id: _o.clienteId, nombre: _o.clienteNombre, telefono: _o.clienteTelefono));
  late List<ItemLinea> _items = _o?.items ?? const [];
  late DateTime? _fechaEstimada = _o?.fechaEstimada;
  late EstadoOrden _estado = _o?.estado ?? EstadoOrden.recibido;
  bool _guardando = false;

  @override
  void dispose() {
    for (final c in [_equipo, _identificador, _km, _problema, _notas]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _guardando = true);
    final repo = Sesion.of(context).ordenes;
    final cliente = _cliente!;
    final km = int.tryParse(_km.text.replaceAll(RegExp(r'\D'), ''));
    final datos = (_o ??
            Orden(id: '', numero: 0, clienteId: '', clienteNombre: '', fechaIngreso: DateTime.now()))
        .copyWith(
      clienteId: cliente.id,
      clienteNombre: cliente.nombre,
      clienteTelefono: cliente.telefono,
      equipo: Equipo(descripcion: _equipo.text.trim(), identificador: _identificador.text.trim(), kilometraje: km),
      problema: _problema.text.trim(),
      notas: _notas.text.trim(),
      items: _items.where((i) => i.descripcion.isNotEmpty).toList(),
      estado: _estado,
      fechaEstimada: _fechaEstimada,
      limpiarFechaEstimada: _fechaEstimada == null,
    );

    Orden? resultado;
    final ok = await ejecutar(context, () async {
      if (_o == null) {
        resultado = await repo.crear(datos);
      } else {
        await repo.actualizar(datos);
        resultado = datos;
      }
    }, exito: _o == null ? 'Trabajo registrado' : 'Cambios guardados');
    if (!mounted) return;
    setState(() => _guardando = false);
    if (ok) Navigator.pop(context, resultado);
  }

  @override
  Widget build(BuildContext context) {
    final rubro = Sesion.of(context).negocio.rubro;
    return FormularioScaffold(
      titulo: _o == null ? 'Nuevo trabajo' : 'Editar trabajo N° ${Formato.numeroComprobante(_o.numero)}',
      formKey: _form,
      guardando: _guardando,
      onGuardar: _guardar,
      textoGuardar: _o == null ? 'Registrar trabajo' : 'Guardar cambios',
      children: [
        const GrupoFormulario('Cliente', primero: true),
        CampoCliente(initialValue: _cliente, onCambio: (c) => setState(() => _cliente = c)),
        GrupoFormulario(rubro.equipo),
        TextFormField(
          controller: _equipo,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(labelText: rubro.equipo, hintText: rubro.hintEquipo, prefixIcon: Icon(rubro.icono)),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Indicá qué ${rubro.equipo.toLowerCase()} es' : null,
        ),
        espacioCampos,
        FilaCampos(children: [
          TextFormField(
            controller: _identificador,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(labelText: rubro.identificador, hintText: rubro.hintIdentificador),
          ),
          if (rubro.usaKilometraje)
            TextFormField(
              controller: _km,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
              decoration: const InputDecoration(labelText: 'Kilometraje', suffixText: 'km'),
            ),
        ]),
        const GrupoFormulario('Trabajo'),
        TextFormField(
          controller: _problema,
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: 'Qué hay que hacer / falla reportada',
            hintText: rubro.hintProblema,
            alignLabelWithHint: true,
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Describí el trabajo' : null,
        ),
        espacioCampos,
        FilaCampos(children: [
          CampoFecha(
            etiqueta: 'Entrega estimada',
            valor: _fechaEstimada,
            permitirVacio: true,
            primera: DateTime.now().subtract(const Duration(days: 365)),
            onCambio: (f) => setState(() => _fechaEstimada = f),
          ),
          if (_o != null)
            DropdownButtonFormField<EstadoOrden>(
              value: _estado,
              decoration: const InputDecoration(labelText: 'Estado'),
              items: [
                for (final e in EstadoOrden.values) DropdownMenuItem(value: e, child: Text(e.etiqueta)),
              ],
              onChanged: (e) => setState(() => _estado = e ?? _estado),
            ),
        ]),
        espacioCampos,
        TextFormField(
          controller: _notas,
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Notas internas (diagnóstico, observaciones)',
            helperText: 'No se imprimen en la orden',
            alignLabelWithHint: true,
          ),
        ),
        const GrupoFormulario('Importe'),
        Text(
          'Podés dejarlo vacío y completarlo cuando tengas el diagnóstico.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        EditorItems(
          inicial: _items,
          sugerencias: rubro.sugerenciasItems,
          onCambio: (items) => _items = items,
        ),
      ],
    );
  }
}
