import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/sesion.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/editor_items.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/formulario.dart';
import '../../data/models/cliente.dart';
import '../../data/models/comunes.dart';
import '../../data/models/presupuesto.dart';
import '../clientes/selector_cliente.dart';

class PresupuestoForm extends StatefulWidget {
  const PresupuestoForm({super.key, this.presupuesto, this.clienteInicial});
  final Presupuesto? presupuesto;
  final Cliente? clienteInicial;

  @override
  State<PresupuestoForm> createState() => _PresupuestoFormState();
}

class _PresupuestoFormState extends State<PresupuestoForm> {
  final _form = GlobalKey<FormState>();
  Presupuesto? get _p => widget.presupuesto;

  late final _equipo = TextEditingController(text: _p?.equipo);
  late final _notas = TextEditingController(text: _p?.notas);
  late final _validez = TextEditingController(text: '${_p?.validezDias ?? 15}');
  late Cliente? _cliente = widget.clienteInicial ??
      (_p == null ? null : Cliente(id: _p!.clienteId, nombre: _p!.clienteNombre, telefono: _p!.clienteTelefono));
  late List<ItemLinea> _items = _p?.items ?? const [ItemLinea(descripcion: '')];
  bool _guardando = false;

  @override
  void dispose() {
    _equipo.dispose();
    _notas.dispose();
    _validez.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    final items = _items.where((i) => i.descripcion.isNotEmpty).toList();
    if (items.isEmpty) {
      mostrarMensaje(context, 'Agregá al menos un ítem', error: true);
      return;
    }
    setState(() => _guardando = true);
    final repo = Sesion.of(context).presupuestos;
    final c = _cliente!;
    final datos = (_p ?? Presupuesto(id: '', numero: 0, clienteId: '', clienteNombre: '', fecha: DateTime.now())).copyWith(
      clienteId: c.id,
      clienteNombre: c.nombre,
      clienteTelefono: c.telefono,
      equipo: _equipo.text.trim(),
      notas: _notas.text.trim(),
      validezDias: int.tryParse(_validez.text) ?? 15,
      items: items,
    );
    Presupuesto? resultado;
    final ok = await ejecutar(context, () async {
      if (_p == null) {
        resultado = await repo.crear(datos);
      } else {
        await repo.actualizar(datos);
        resultado = datos;
      }
    }, exito: _p == null ? 'Presupuesto creado' : 'Cambios guardados');
    if (!mounted) return;
    setState(() => _guardando = false);
    if (ok) Navigator.pop(context, resultado);
  }

  @override
  Widget build(BuildContext context) {
    final rubro = Sesion.of(context).negocio.rubro;
    return FormularioScaffold(
      titulo: _p == null ? 'Nuevo presupuesto' : 'Editar presupuesto N° ${Formato.numeroComprobante(_p!.numero)}',
      formKey: _form,
      guardando: _guardando,
      onGuardar: _guardar,
      textoGuardar: _p == null ? 'Crear presupuesto' : 'Guardar cambios',
      children: [
        const GrupoFormulario('Cliente', primero: true),
        CampoCliente(initialValue: _cliente, onCambio: (c) => setState(() => _cliente = c)),
        espacioCampos,
        TextFormField(
          controller: _equipo,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: '${rubro.equipo} (opcional)', hintText: rubro.hintEquipo, prefixIcon: Icon(rubro.icono)),
        ),
        const GrupoFormulario('Detalle'),
        EditorItems(inicial: _items, sugerencias: rubro.sugerenciasItems, onCambio: (i) => _items = i),
        const GrupoFormulario('Condiciones'),
        FilaCampos(children: [
          TextFormField(
            controller: _validez,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Validez', suffixText: 'días'),
            validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0 ? 'Indicá los días' : null,
          ),
          const SizedBox.shrink(),
        ]),
        espacioCampos,
        TextFormField(
          controller: _notas,
          minLines: 2,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Observaciones (se imprimen)',
            hintText: 'Ej: Garantía de 90 días. No incluye repuestos no especificados.',
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }
}
