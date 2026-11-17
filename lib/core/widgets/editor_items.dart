import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/comunes.dart';
import '../theme/app_theme.dart';
import '../utils/formato.dart';

/// Editor de líneas (descripción × cantidad × precio) con total en vivo.
class EditorItems extends StatefulWidget {
  const EditorItems({
    super.key,
    required this.inicial,
    required this.onCambio,
    this.sugerencias = const [],
    this.elegirDelCatalogo,
  });

  final List<ItemLinea> inicial;
  final ValueChanged<List<ItemLinea>> onCambio;

  /// Abre el buscador del catálogo y devuelve el ítem elegido.
  final Future<ItemLinea?> Function()? elegirDelCatalogo;

  /// Descripciones frecuentes que se ofrecen como atajo.
  final List<String> sugerencias;

  @override
  State<EditorItems> createState() => _EditorItemsState();
}

class _Fila {
  _Fila(ItemLinea item)
      : origen = item,
        descripcion = TextEditingController(text: item.descripcion),
        cantidad = TextEditingController(text: item.cantidad == 1 ? '1' : Formato.cantidad(item.cantidad)),
        precio = TextEditingController(text: Formato.montoEditable(item.precioUnitario)),
        clave = UniqueKey();

  /// Ítem original: conserva el vínculo con el catálogo y el costo.
  final ItemLinea origen;
  final TextEditingController descripcion;
  final TextEditingController cantidad;
  final TextEditingController precio;
  final Key clave;

  ItemLinea get item => ItemLinea(
        descripcion: descripcion.text.trim(),
        cantidad: Formato.parseMonto(cantidad.text) ?? 1,
        precioUnitario: Formato.parseMonto(precio.text) ?? 0,
        productoId: origen.productoId,
        costoUnitario: origen.costoUnitario,
      );

  void dispose() {
    descripcion.dispose();
    cantidad.dispose();
    precio.dispose();
  }
}

class _EditorItemsState extends State<EditorItems> {
  late final List<_Fila> _filas = widget.inicial.map(_Fila.new).toList();

  @override
  void dispose() {
    for (final f in _filas) {
      f.dispose();
    }
    super.dispose();
  }

  List<ItemLinea> get _items => _filas.map((f) => f.item).toList();

  void _notificar() {
    setState(() {});
    widget.onCambio(_items);
  }

  void _agregar([String descripcion = '']) {
    _filas.add(_Fila(ItemLinea(descripcion: descripcion)));
    _notificar();
  }

  Future<void> _agregarDelCatalogo() async {
    final item = await widget.elegirDelCatalogo!();
    if (item == null || !mounted) return;
    // Si ya está en la lista, suma una unidad en lugar de duplicar la línea.
    final existente = _filas.where((f) => f.origen.productoId != null && f.origen.productoId == item.productoId).firstOrNull;
    if (existente != null) {
      final actual = Formato.parseMonto(existente.cantidad.text) ?? 1;
      existente.cantidad.text = Formato.cantidad(actual + 1);
    } else {
      _filas.add(_Fila(item));
    }
    _notificar();
  }

  void _quitar(int i) {
    _filas.removeAt(i).dispose();
    _notificar();
  }

  @override
  Widget build(BuildContext context) {
    final total = ItemLinea.total(_items);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _filas.length; i++) ...[
          _FilaItem(key: _filas[i].clave, fila: _filas[i], onCambio: _notificar, onQuitar: () => _quitar(i)),
          const SizedBox(height: Espacio.m),
        ],
        Wrap(
          spacing: Espacio.s,
          runSpacing: Espacio.s,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (widget.elegirDelCatalogo != null)
              FilledButton.tonalIcon(
                onPressed: _agregarDelCatalogo,
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Del catálogo'),
              ),
            OutlinedButton.icon(
              onPressed: _agregar,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ítem libre'),
            ),
            for (final s in widget.sugerencias)
              ActionChip(label: Text(s), avatar: const Icon(Icons.add_rounded, size: 16), onPressed: () => _agregar(s)),
          ],
        ),
        const SizedBox(height: Espacio.l),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: Espacio.l, vertical: Espacio.m),
          decoration: BoxDecoration(
            color: context.colores.fondoSutil,
            borderRadius: BorderRadius.circular(Radios.m),
            border: Border.all(color: context.colores.borde),
          ),
          child: Row(
            children: [
              Text('Total', style: context.textos.titleMedium),
              const Spacer(),
              Text(Formato.moneda(total), style: context.textos.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilaItem extends StatelessWidget {
  const _FilaItem({super.key, required this.fila, required this.onCambio, required this.onQuitar});

  final _Fila fila;
  final VoidCallback onCambio;
  final VoidCallback onQuitar;

  @override
  Widget build(BuildContext context) {
    final descripcion = TextFormField(
      controller: fila.descripcion,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: 'Descripción',
        isDense: true,
        prefixIcon: fila.origen.delCatalogo
            ? Tooltip(message: 'Del catálogo: descuenta stock', child: Icon(Icons.inventory_2_outlined, size: 18, color: context.esquema.primary))
            : null,
      ),
      onChanged: (_) => onCambio(),
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Completá la descripción' : null,
    );
    final cantidad = TextFormField(
      controller: fila.cantidad,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
      decoration: const InputDecoration(labelText: 'Cant.', isDense: true),
      onChanged: (_) => onCambio(),
      validator: (v) {
        final n = Formato.parseMonto(v ?? '');
        return (n == null || n <= 0) ? 'Inválida' : null;
      },
    );
    final precio = TextFormField(
      controller: fila.precio,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
      decoration: const InputDecoration(labelText: 'Precio unit.', prefixText: r'$ ', isDense: true),
      onChanged: (_) => onCambio(),
      validator: (v) => (v != null && v.trim().isNotEmpty && Formato.parseMonto(v) == null) ? 'Inválido' : null,
    );
    final subtotal = Text(
      Formato.moneda(fila.item.subtotal),
      style: context.textos.titleSmall,
      textAlign: TextAlign.right,
    );
    final quitar = IconButton(
      tooltip: 'Quitar ítem',
      onPressed: onQuitar,
      icon: Icon(Icons.delete_outline_rounded, color: context.colores.peligro),
    );

    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= 560) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: descripcion),
            const SizedBox(width: Espacio.s),
            SizedBox(width: 72, child: cantidad),
            const SizedBox(width: Espacio.s),
            SizedBox(width: 140, child: precio),
            SizedBox(width: 100, child: Padding(padding: const EdgeInsets.only(top: 14), child: subtotal)),
            quitar,
          ],
        );
      }
      return Container(
        padding: const EdgeInsets.all(Espacio.m),
        decoration: BoxDecoration(
          border: Border.all(color: context.colores.borde),
          borderRadius: BorderRadius.circular(Radios.m),
        ),
        child: Column(
          children: [
            Row(children: [Expanded(child: descripcion), quitar]),
            const SizedBox(height: Espacio.s),
            Row(
              children: [
                SizedBox(width: 72, child: cantidad),
                const SizedBox(width: Espacio.s),
                Expanded(child: precio),
                const SizedBox(width: Espacio.m),
                subtotal,
              ],
            ),
          ],
        ),
      );
    });
  }
}
