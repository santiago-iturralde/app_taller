import 'package:flutter/material.dart';

import '../../app/sesion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/campos.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/formulario.dart';
import '../../data/models/caja.dart';
import '../../data/models/cliente.dart';
import '../../data/models/orden.dart';
import '../clientes/selector_cliente.dart';
import 'widgets_caja.dart';

/// Registra un cobro, asociado a un trabajo o suelto (venta de mostrador,
/// seña, etc.). Devuelve el [Pago] creado.
class CobroForm extends StatefulWidget {
  const CobroForm({super.key, this.orden});
  final Orden? orden;

  @override
  State<CobroForm> createState() => _CobroFormState();
}

class _CobroFormState extends State<CobroForm> {
  final _form = GlobalKey<FormState>();
  late final _monto = TextEditingController(
    text: widget.orden == null ? '' : Formato.montoEditable(widget.orden!.saldo),
  );
  final _concepto = TextEditingController();
  MedioPago _medio = MedioPago.efectivo;
  DateTime _fecha = DateTime.now();
  Cliente? _cliente;
  bool _guardando = false;

  @override
  void dispose() {
    _monto.dispose();
    _concepto.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    final monto = Formato.parseMonto(_monto.text)!;
    final orden = widget.orden;
    if (orden != null && !orden.sinPresupuestar && monto > orden.saldo + 0.01) {
      final seguir = await confirmar(
        context,
        titulo: 'El cobro supera el saldo',
        mensaje: 'El saldo del trabajo es ${Formato.moneda(orden.saldo)} y vas a cobrar ${Formato.moneda(monto)}. ¿Continuar?',
        confirmar: 'Cobrar igual',
      );
      if (!seguir || !mounted) return;
    }
    setState(() => _guardando = true);
    final caja = Sesion.of(context).caja;
    final ahora = DateTime.now();
    final fecha = DateTime(_fecha.year, _fecha.month, _fecha.day, ahora.hour, ahora.minute, ahora.second);
    Pago? pago;
    final ok = await ejecutar(context, () async {
      pago = await caja.registrarPago(
        monto: monto,
        medio: _medio,
        fecha: fecha,
        concepto: _concepto.text.trim(),
        clienteId: _cliente?.id,
        clienteNombre: _cliente?.nombre ?? '',
        ordenId: orden?.id,
      );
    });
    if (!mounted) return;
    setState(() => _guardando = false);
    if (!ok) return;
    final hecho = pago!;
    final navegador = Navigator.of(context);
    mostrarMensaje(
      context,
      '${orden == null ? 'Recibo guardado' : 'Cobro registrado'} · N° ${Formato.numeroComprobante(hecho.numero)}',
      accion: SnackBarAction(label: 'Imprimir', onPressed: () => imprimirRecibo(navegador.context, hecho)),
    );
    navegador.pop(hecho);
  }

  @override
  Widget build(BuildContext context) {
    final orden = widget.orden;
    return FormularioScaffold(
      titulo: orden == null ? 'Nuevo recibo' : 'Registrar cobro',
      formKey: _form,
      guardando: _guardando,
      onGuardar: _guardar,
      textoGuardar: orden == null ? 'Guardar recibo' : 'Registrar cobro',
      children: [
        if (orden != null) ...[
          AppCard(
            color: context.colores.fondoSutil,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Trabajo N° ${Formato.numeroComprobante(orden.numero)} · ${orden.clienteNombre}', style: context.textos.titleSmall),
                Text(orden.equipo.descripcion, style: context.textos.bodySmall),
                const SizedBox(height: Espacio.s),
                FilaDato('Total', orden.sinPresupuestar ? 'Sin importe' : Formato.moneda(orden.total)),
                FilaDato('Ya cobrado', Formato.moneda(orden.pagado)),
                FilaDato('Saldo', Formato.moneda(orden.saldo), destacado: true),
              ],
            ),
          ),
          const SizedBox(height: Espacio.xl),
        ] else ...[
          CampoClienteOpcional(onCambio: (c) => setState(() => _cliente = c)),
          espacioCampos,
        ],
        CampoMonto(controller: _monto, etiqueta: orden == null ? 'La suma de' : 'Monto cobrado', autofocus: true),
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
        const GrupoFormulario('Detalle'),
        CampoFecha(
          etiqueta: 'Fecha',
          valor: _fecha,
          ultima: DateTime.now(),
          onCambio: (f) => setState(() => _fecha = f ?? _fecha),
        ),
        espacioCampos,
        TextFormField(
          controller: _concepto,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: orden == null ? 'En concepto de' : 'Concepto',
            hintText: orden != null ? 'Se completa automáticamente' : 'Ej: Reparación de amoladora',
          ),
          validator: (v) => (orden == null && (v == null || v.trim().isEmpty)) ? 'Indicá el concepto' : null,
        ),
      ],
    );
  }
}

/// Selector de cliente que se puede dejar vacío (consumidor final).
class CampoClienteOpcional extends StatefulWidget {
  const CampoClienteOpcional({super.key, required this.onCambio});
  final ValueChanged<Cliente?> onCambio;

  @override
  State<CampoClienteOpcional> createState() => _CampoClienteOpcionalState();
}

class _CampoClienteOpcionalState extends State<CampoClienteOpcional> {
  Cliente? _cliente;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(Radios.m),
      onTap: () async {
        final c = await elegirCliente(context);
        if (c != null) {
          setState(() => _cliente = c);
          widget.onCambio(c);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Cliente (opcional)',
          prefixIcon: const Icon(Icons.person_outline),
          suffixIcon: _cliente == null
              ? const Icon(Icons.unfold_more_rounded)
              : IconButton(
                  tooltip: 'Quitar',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    setState(() => _cliente = null);
                    widget.onCambio(null);
                  },
                ),
        ),
        child: Text(_cliente?.nombre ?? 'Consumidor final'),
      ),
    );
  }
}
