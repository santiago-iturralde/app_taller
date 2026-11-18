import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/sesion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/campos.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/formulario.dart';
import '../../data/models/producto.dart';

class ProductoForm extends StatefulWidget {
  const ProductoForm({super.key, this.producto, this.nombreInicial = ''});
  final Producto? producto;
  final String nombreInicial;

  @override
  State<ProductoForm> createState() => _ProductoFormState();
}

class _ProductoFormState extends State<ProductoForm> {
  final _form = GlobalKey<FormState>();
  Producto? get _p => widget.producto;

  late final _nombre = TextEditingController(text: _p?.nombre ?? widget.nombreInicial);
  late final _codigo = TextEditingController(text: _p?.codigo);
  late final _categoria = TextEditingController(text: _p?.categoria);
  late final _precio = TextEditingController(text: Formato.montoEditable(_p?.precio));
  late final _costo = TextEditingController(text: Formato.montoEditable(_p?.costo));
  final _stockInicial = TextEditingController();
  late final _stockMinimo = TextEditingController(
    text: _p == null || _p!.stockMinimo == 0 ? '' : Formato.cantidad(_p!.stockMinimo),
  );
  late TipoProducto _tipo = _p?.tipo ?? TipoProducto.producto;
  bool _guardando = false;

  @override
  void dispose() {
    for (final c in [_nombre, _codigo, _categoria, _precio, _costo, _stockInicial, _stockMinimo]) {
      c.dispose();
    }
    super.dispose();
  }

  double? get _margen {
    final precio = Formato.parseMonto(_precio.text) ?? 0;
    final costo = Formato.parseMonto(_costo.text) ?? 0;
    return (precio <= 0 || costo <= 0) ? null : (precio - costo) / precio * 100;
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _guardando = true);
    final repo = Sesion.of(context).productos;
    final datos = Producto(
      id: _p?.id ?? '',
      nombre: _nombre.text.trim(),
      codigo: _codigo.text.trim(),
      categoria: _categoria.text.trim(),
      tipo: _tipo,
      precio: Formato.parseMonto(_precio.text) ?? 0,
      costo: Formato.parseMonto(_costo.text) ?? 0,
      stock: _p?.stock ?? 0,
      stockMinimo: Formato.parseMonto(_stockMinimo.text) ?? 0,
    );
    Producto? resultado;
    final ok = await ejecutar(context, () async {
      if (_p == null) {
        resultado = await repo.crear(datos, stockInicial: Formato.parseMonto(_stockInicial.text) ?? 0);
      } else {
        await repo.actualizar(datos);
        resultado = datos;
      }
    }, exito: _p == null ? 'Producto creado' : 'Cambios guardados');
    if (!mounted) return;
    setState(() => _guardando = false);
    if (ok) Navigator.pop(context, resultado);
  }

  @override
  Widget build(BuildContext context) {
    final esProducto = _tipo == TipoProducto.producto;
    final margen = _margen;
    final numeros = [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))];
    return FormularioScaffold(
      titulo: _p == null ? 'Nuevo producto o servicio' : 'Editar ${_p!.tipo.etiqueta.toLowerCase()}',
      formKey: _form,
      guardando: _guardando,
      onGuardar: _guardar,
      children: [
        SegmentedButton<TipoProducto>(
          showSelectedIcon: false,
          segments: [
            for (final t in TipoProducto.values) ButtonSegment(value: t, label: Text(t.etiqueta), icon: Icon(t.icono)),
          ],
          selected: {_tipo},
          onSelectionChanged: _p == null ? (s) => setState(() => _tipo = s.first) : null,
        ),
        const SizedBox(height: Espacio.s),
        Text(
          esProducto
              ? 'Los productos llevan control de stock.'
              : 'Los servicios (mano de obra, diagnóstico…) no llevan stock.',
          style: context.textos.bodySmall?.copyWith(color: context.esquema.onSurfaceVariant),
        ),
        const SizedBox(height: Espacio.xl),
        TextFormField(
          controller: _nombre,
          autofocus: _p == null,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: 'Nombre',
            hintText: esProducto ? 'Ej: Aceite 10W40 semisintético 4L' : 'Ej: Cambio de aceite (mano de obra)',
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Completá el nombre' : null,
        ),
        espacioCampos,
        FilaCampos(
          children: [
            TextFormField(
              controller: _codigo,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Código (opcional)', hintText: 'SKU, código de barras…'),
            ),
            TextFormField(
              controller: _categoria,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Categoría (opcional)', hintText: 'Ej: Aceites, Filtros'),
            ),
          ],
        ),
        const GrupoFormulario('Precio'),
        FilaCampos(
          children: [
            CampoMonto(controller: _precio, etiqueta: 'Precio de venta', onChanged: (_) => setState(() {})),
            CampoMonto(
              controller: _costo,
              etiqueta: 'Costo (opcional)',
              obligatorio: false,
              permitirCero: true,
              onChanged: (_) => setState(() {}),
              helper: margen == null ? 'Para calcular tu ganancia' : 'Margen: ${margen.toStringAsFixed(0)}%',
            ),
          ],
        ),
        if (esProducto) ...[
          const GrupoFormulario('Stock'),
          FilaCampos(
            children: [
              if (_p == null)
                TextFormField(
                  controller: _stockInicial,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: numeros,
                  decoration: const InputDecoration(labelText: 'Stock inicial', hintText: '0'),
                )
              else
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Stock actual',
                    helperText: 'Se modifica desde el detalle del producto',
                  ),
                  child: Text(Formato.cantidad(_p!.stock)),
                ),
              TextFormField(
                controller: _stockMinimo,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: numeros,
                decoration: const InputDecoration(
                  labelText: 'Avisar cuando queden',
                  hintText: 'Ej: 3',
                  helperText: 'Stock mínimo',
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
