import 'package:flutter/material.dart';

import '../../app/sesion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/editor_items.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/formulario.dart';
import '../../data/models/caja.dart';
import '../../data/models/cliente.dart';
import '../../data/models/comunes.dart';
import '../productos/productos_page.dart';
import 'cobro_form.dart';
import 'widgets_caja.dart';

/// Venta de mostrador: productos o servicios que se cobran en el momento,
/// sin abrir un trabajo. Descuenta stock y genera recibo.
class VentaForm extends StatefulWidget {
  const VentaForm({super.key});

  @override
  State<VentaForm> createState() => _VentaFormState();
}

class _VentaFormState extends State<VentaForm> {
  final _form = GlobalKey<FormState>();
  List<ItemLinea> _items = const [];
  MedioPago _medio = MedioPago.efectivo;
  Cliente? _cliente;
  bool _guardando = false;

  double get _total => ItemLinea.total(_items.where((i) => i.descripcion.isNotEmpty));

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    final items = _items.where((i) => i.descripcion.isNotEmpty).toList();
    if (items.isEmpty || _total <= 0) {
      mostrarMensaje(context, 'Agregá al menos un ítem con precio', error: true);
      return;
    }
    setState(() => _guardando = true);
    final caja = Sesion.of(context).caja;
    Pago? pago;
    final ok = await ejecutar(context, () async {
      pago = await caja.registrarVenta(
        items: items,
        medio: _medio,
        fecha: DateTime.now(),
        clienteId: _cliente?.id,
        clienteNombre: _cliente?.nombre ?? '',
      );
    });
    if (!mounted) return;
    setState(() => _guardando = false);
    if (!ok) return;
    final hecho = pago!;
    final navegador = Navigator.of(context);
    mostrarMensaje(
      context,
      'Venta registrada · Recibo N° ${Formato.numeroComprobante(hecho.numero)}',
      accion: SnackBarAction(label: 'Imprimir', onPressed: () => imprimirRecibo(navegador.context, hecho)),
    );
    navegador.pop(hecho);
  }

  @override
  Widget build(BuildContext context) {
    final rubro = Sesion.of(context).negocio.rubro;
    return FormularioScaffold(
      titulo: 'Venta de mostrador',
      formKey: _form,
      guardando: _guardando,
      onGuardar: _guardar,
      textoGuardar: _total > 0 ? 'Cobrar ${Formato.moneda(_total)}' : 'Cobrar',
      children: [
        const GrupoFormulario('Qué se vende', primero: true),
        EditorItems(
          inicial: const [],
          sugerencias: rubro.sugerenciasItems,
          elegirDelCatalogo: () => elegirDelCatalogo(context),
          onCambio: (i) => setState(() => _items = i),
        ),
        const GrupoFormulario('Forma de pago'),
        Wrap(
          spacing: Espacio.s,
          runSpacing: Espacio.s,
          children: [
            for (final m in MedioPago.values)
              ChoiceChip(
                label: Text(m.etiqueta),
                avatar: Icon(m.icono, size: 18),
                selected: _medio == m,
                showCheckmark: false,
                onSelected: (_) => setState(() => _medio = m),
              ),
          ],
        ),
        const GrupoFormulario('Cliente'),
        CampoClienteOpcional(onCambio: (c) => setState(() => _cliente = c)),
      ],
    );
  }
}

/// Pregunta qué tipo de ingreso registrar: venta con ítems o cobro suelto.
Future<void> nuevoIngreso(BuildContext context) async {
  final opcion = await showModalBottomSheet<String>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.shopping_bag_outlined),
          title: const Text('Venta de mostrador'),
          subtitle: const Text('Productos o servicios del catálogo. Descuenta stock.'),
          onTap: () => Navigator.pop(sheet, 'venta'),
        ),
        ListTile(
          leading: const Icon(Icons.add_card_rounded),
          title: const Text('Cobro suelto'),
          subtitle: const Text('Un importe con su concepto, sin detalle de ítems.'),
          onTap: () => Navigator.pop(sheet, 'cobro'),
        ),
        const SizedBox(height: Espacio.s),
      ]),
    ),
  );
  if (!context.mounted || opcion == null) return;
  await abrirFormulario<Pago>(context, opcion == 'venta' ? const VentaForm() : const CobroForm());
}
